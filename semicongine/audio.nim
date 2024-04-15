import std/monotimes
import std/times
import std/tables
import std/locks
import std/logging except Level

when defined(windows): # used for setting audio thread priority
  import winim
when defined(linux):
  import std/posix

import ./core
import ./platform/audio
import ./resources

export audiotypes

const NBUFFERS = 4
const BUFFERSAMPLECOUNT = 2048

type
  Playback = object
    sound: Sound
    position: int
    loop: bool
    levelLeft: Level
    levelRight: Level
    paused: bool
  Track = object
    playing: Table[uint64, Playback]
    level: Level
    targetLevel: Level
    fadeTime: float
    fadeStep: float
  Mixer* = object
    playbackCounter: uint64
    tracks: Table[string, Track]
    sounds*: Table[string, Sound]
    level: Level
    device: NativeSoundDevice
    lock: Lock
    buffers: seq[SoundData]
    currentBuffer: int
    lastUpdate: MonoTime

proc initMixer*(): Mixer =
  result = Mixer(
    tracks: {"": Track(level: 1'f)}.toTable,
    level: 1'f,
  )
  result.lock.initLock()

proc setupDevice(mixer: var Mixer) =
  # call this inside audio thread
  var bufferaddresses: seq[ptr SoundData]
  for i in 0 ..< NBUFFERS:
    mixer.buffers.add newSeq[Sample](BUFFERSAMPLECOUNT)
  for i in 0 ..< mixer.buffers.len:
    bufferaddresses.add (addr mixer.buffers[i])
  mixer.device = openSoundDevice(AUDIO_SAMPLE_RATE, bufferaddresses)

proc loadSound*(mixer: var Mixer, name: string, resource: string) =
  assert not (name in mixer.sounds)
  mixer.sounds[name] = loadAudio(resource)

proc addSound*(mixer: var Mixer, name: string, sound: Sound) =
  assert not (name in mixer.sounds)
  mixer.sounds[name] = sound

proc replaceSound*(mixer: var Mixer, name: string, sound: Sound) =
  assert (name in mixer.sounds)
  mixer.sounds[name] = sound

proc addTrack*(mixer: var Mixer, name: string, level: Level = 1'f) =
  assert not (name in mixer.tracks)
  mixer.lock.withLock():
    mixer.tracks[name] = Track(level: level)

proc play*(mixer: var Mixer, soundName: string, track = "", stopOtherSounds = false, loop = false, levelLeft, levelRight: Level): uint64 =
  assert track in mixer.tracks
  assert soundName in mixer.sounds, soundName & " not loaded"
  mixer.lock.withLock():
    if stopOtherSounds:
      mixer.tracks[track].playing.clear()
    mixer.tracks[track].playing[mixer.playbackCounter] = Playback(
      sound: mixer.sounds[soundName],
      position: 0,
      loop: loop,
      levelLeft: levelLeft,
      levelRight: levelRight,
      paused: false,
    )
  result = mixer.playbackCounter
  inc mixer.playbackCounter

proc play*(mixer: var Mixer, soundName: string, track = "", stopOtherSounds = false, loop = false, level: Level = 1'f): uint64 =
  play(
    mixer = mixer,
    soundName = soundName,
    track = track,
    stopOtherSounds = stopOtherSounds,
    loop = loop,
    levelLeft = level,
    levelRight = level
  )

proc stop*(mixer: var Mixer) =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      track.playing.clear()

proc getLevel*(mixer: var Mixer): Level = mixer.level
proc getLevel*(mixer: var Mixer, track: string): Level = mixer.tracks[track].level
proc getLevel*(mixer: var Mixer, playbackId: uint64): (Level, Level) =
  for track in mixer.tracks.mvalues:
    if playbackId in track.playing:
      return (track.playing[playbackId].levelLeft, track.playing[playbackId].levelRight)

proc setLevel*(mixer: var Mixer, level: Level) = mixer.level = level
proc setLevel*(mixer: var Mixer, track: string, level: Level) =
  mixer.lock.withLock():
    mixer.tracks[track].level = level
proc setLevel*(mixer: var Mixer, playbackId: uint64, levelLeft, levelRight: Level) =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing[playbackId].levelLeft = levelLeft
        track.playing[playbackId].levelRight = levelRight
proc setLevel*(mixer: var Mixer, playbackId: uint64, level: Level) =
  setLevel(mixer, playbackId, level, level)

proc stop*(mixer: var Mixer, track: string) =
  assert track in mixer.tracks
  mixer.lock.withLock():
    mixer.tracks[track].playing.clear()

proc stop*(mixer: var Mixer, playbackId: uint64) =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing.del(playbackId)
        break

proc pause*(mixer: var Mixer, value: bool) =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      for playback in track.playing.mvalues:
        playback.paused = value

proc pause*(mixer: var Mixer, track: string, value: bool) =
  mixer.lock.withLock():
    for playback in mixer.tracks[track].playing.mvalues:
      playback.paused = value

proc pause*(mixer: var Mixer, playbackId: uint64, value: bool) =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing[playbackId].paused = value

proc pause*(mixer: var Mixer) = mixer.pause(true)
proc pause*(mixer: var Mixer, track: string) = mixer.pause(track, true)
proc pause*(mixer: var Mixer, playbackId: uint64) = mixer.pause(playbackId, true)
proc unpause*(mixer: var Mixer) = mixer.pause(false)
proc unpause*(mixer: var Mixer, track: string) = mixer.pause(track, false)
proc unpause*(mixer: var Mixer, playbackId: uint64) = mixer.pause(playbackId, false)

proc fadeTo*(mixer: var Mixer, track: string, level: Level, time: float) =
  mixer.tracks[track].targetLevel = level
  mixer.tracks[track].fadeTime = time
  mixer.tracks[track].fadeStep = level.float - mixer.tracks[track].level.float / time

proc isPlaying*(mixer: var Mixer): bool =
  mixer.lock.withLock():
    for track in mixer.tracks.mvalues:
      for playback in track.playing.values:
        if not playback.paused:
          return true
  return false

proc isPlaying*(mixer: var Mixer, track: string): bool =
  mixer.lock.withLock():
    if mixer.tracks.contains(track):
      for playback in mixer.tracks[track].playing.values:
        if not playback.paused:
          return true
    return false

func applyLevel(sample: Sample, levelLeft, levelRight: Level): Sample =
  [int16(float(sample[0]) * levelLeft), int16(float(sample[1]) * levelRight)]

func clip(value: int32): int16 =
  int16(max(min(int32(high(int16)), value), int32(low(int16))))

# used for combining sounds
func mix(a, b: Sample): Sample =
  [
    clip(int32(a[0]) + int32(b[0])),
    clip(int32(a[1]) + int32(b[1])),
  ]

proc updateSoundBuffer(mixer: var Mixer) =
  let t = getMonoTime()
  let dt = (t - mixer.lastUpdate).inNanoseconds.float64 / 1_000_000_000'f64
  mixer.lastUpdate = t

  # update fadings
  for track in mixer.tracks.mvalues:
    if track.fadeTime > 0:
      track.fadeTime -= dt
      track.level = (track.level.float64 + track.fadeStep.float64 * dt).clamp(Level.low, Level.high)
      if track.fadeTime <= 0:
        track.level = track.targetLevel
  # mix
  for i in 0 ..< mixer.buffers[mixer.currentBuffer].len:
    var mixedSample = [0'i16, 0'i16]
    mixer.lock.withLock():
      for track in mixer.tracks.mvalues:
        var stoppedSounds: seq[uint64]
        for (id, playback) in track.playing.mpairs:
          if playback.paused:
            continue
          let sample = applyLevel(
            playback.sound[][playback.position],
            mixer.level * track.level * playback.levelLeft,
            mixer.level * track.level * playback.levelRight,
          )
          mixedSample = mix(mixedSample, sample)
          inc playback.position
          if playback.position >= playback.sound[].len:
            if playback.loop:
              playback.position = 0
            else:
              stoppedSounds.add id
        for id in stoppedSounds:
          track.playing.del(id)
      mixer.buffers[mixer.currentBuffer][i] = mixedSample
  # send data to sound device
  mixer.device.writeSoundData(mixer.currentBuffer)
  mixer.currentBuffer = (mixer.currentBuffer + 1) mod mixer.buffers.len

# DSP functions

proc lowPassFilter(data: var SoundData, cutoff: int) =
  let alpha = float(cutoff) / AUDIO_SAMPLE_RATE
  var value = data[0]
  for i in 0 ..< data.len:
    value[0] += int16(alpha * float(data[i][0] - value[0]))
    value[1] += int16(alpha * float(data[i][1] - value[1]))
    data[i] = value

proc downsample(data: var SoundData, n: int) =
  let newLen = (data.len - 1) div n + 1
  for i in 0 ..< newLen:
    data[i] = data[i * n]
  data.setLen(newLen)

proc upsample(data: var SoundData, m: int) =
  data.setLen(data.len * m)
  var i = data.len - 1
  while i < 0:
    if i mod m == 0:
      data[i] = data[i div m]
    else:
      data[i] = [0, 0]
    i.dec

proc slowdown(data: var SoundData, m, n: int) =
  data.upsample(m)
  # TODO
  # data.lowPassFilter(m)
  data.downsample(n)

proc destroy*(mixer: var Mixer) =
  mixer.lock.deinitLock()
  mixer.device.closeSoundDevice()

# Threaded implementation, usually used for audio

var
  mixer* = createShared(Mixer)
  audiothread: Thread[void]

proc audioWorker() {.thread.} =
  mixer[].setupDevice()
  onThreadDestruction(proc() = mixer[].lock.withLock(mixer[].destroy()); freeShared(mixer))
  while true:
    mixer[].updateSoundBuffer()

proc startMixerThread*() =
  mixer[] = initMixer()
  audiothread.createThread(audioWorker)
  debug "Created audio thread"
  when defined(windows):
    SetThreadPriority(audiothread.handle(), THREAD_PRIORITY_TIME_CRITICAL)
  when defined(linux):
    discard pthread_setschedprio(Pthread(audiothread.handle()), cint(-20))
