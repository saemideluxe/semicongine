import std/os
import std/locks
import std/logging
import std/math
import std/monotimes
import std/strformat
import std/tables
import std/times

import ../core

const NBUFFERS = 32
# it seems that some alsa hardware has a problem with smaller buffers than 512
when defined(linux):
  const BUFFERSAMPLECOUNT = 512
else:
  const BUFFERSAMPLECOUNT = 256

when defined(windows):
  include ./platform/windows
when defined(linux):
  include ./platform/linux

proc initMixer*(): Mixer =
  result = Mixer(tracks: initTable[string, Track](), level: 1'f)
  result.tracks[""] = Track(level: 1)
  result.lock.initLock()

# TODO: this should probably be in the load-code-stuff
# proc LoadSound*(mixer: var Mixer, name: string, resource: string) =
# assert not (name in mixer.sounds)
# mixer.sounds[name] = LoadAudio(resource)

proc addSound*(name: string, sound: SoundData) =
  if name in engine().mixer.sounds:
    warn "sound with name '", name, "' was already loaded, overwriting"
  engine().mixer.sounds[name] = sound

proc addTrack*(name: string, level: AudioLevel = 1'f) =
  if name in engine().mixer.tracks:
    warn "track with name '", name, "' was already loaded, overwriting"
  engine().mixer.lock.withLock:
    engine().mixer.tracks[name] = Track(level: level)

proc play*(
    soundName: string,
    track = "",
    stopOtherSounds = false,
    loop = false,
    levelLeft, levelRight: AudioLevel,
): uint64 =
  assert track in engine().mixer.tracks, &"Track '{track}' does not exists"
  assert soundName in engine().mixer.sounds, soundName & " not loaded"
  engine().mixer.lock.withLock:
    if stopOtherSounds:
      engine().mixer.tracks[track].playing.clear()
    engine().mixer.tracks[track].playing[engine().mixer.playbackCounter] = Playback(
      sound: engine().mixer.sounds[soundName],
      position: 0,
      loop: loop,
      levelLeft: levelLeft,
      levelRight: levelRight,
      paused: false,
    )
  result = engine().mixer.playbackCounter
  inc engine().mixer.playbackCounter

proc play*(
    soundName: string,
    track = "",
    stopOtherSounds = false,
    loop = false,
    level: AudioLevel = 1'f,
): uint64 =
  play(
    soundName = soundName,
    track = track,
    stopOtherSounds = stopOtherSounds,
    loop = loop,
    levelLeft = level,
    levelRight = level,
  )

proc stop*() =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      track.playing.clear()

proc getLevel*(): AudioLevel =
  engine().mixer.level

proc getLevel*(track: string): AudioLevel =
  engine().mixer.tracks[track].level

proc getLevel*(playbackId: uint64): (AudioLevel, AudioLevel) =
  for track in engine().mixer.tracks.mvalues:
    if playbackId in track.playing:
      return (track.playing[playbackId].levelLeft, track.playing[playbackId].levelRight)

proc setLevel*(level: AudioLevel) =
  engine().mixer.level = level

proc setLevel*(track: string, level: AudioLevel) =
  engine().mixer.lock.withLock:
    engine().mixer.tracks[track].level = level

proc setLevel*(playbackId: uint64, levelLeft, levelRight: AudioLevel) =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing[playbackId].levelLeft = levelLeft
        track.playing[playbackId].levelRight = levelRight

proc setLevel*(playbackId: uint64, level: AudioLevel) =
  setLevel(playbackId, level, level)

proc stop*(track: string) =
  assert track in engine().mixer.tracks
  engine().mixer.lock.withLock:
    engine().mixer.tracks[track].playing.clear()

proc stop*(playbackId: uint64) =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing.del(playbackId)
        break

proc pause*(value: bool) =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      for playback in track.playing.mvalues:
        playback.paused = value

proc pause*(track: string, value: bool) =
  engine().mixer.lock.withLock:
    for playback in engine().mixer.tracks[track].playing.mvalues:
      playback.paused = value

proc pause*(playbackId: uint64, value: bool) =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      if playbackId in track.playing:
        track.playing[playbackId].paused = value

proc pause*() =
  pause(true)

proc pause*(track: string) =
  pause(track, true)

proc pause*(playbackId: uint64) =
  pause(playbackId, true)

proc unpause*() =
  pause(false)

proc unpause*(track: string) =
  pause(track, false)

proc unpause*(playbackId: uint64) =
  pause(playbackId, false)

proc fadeTo*(track: string, level: AudioLevel, time: float) =
  engine().mixer.tracks[track].targetLevel = level
  engine().mixer.tracks[track].fadeTime = time
  engine().mixer.tracks[track].fadeStep =
    level.float - engine().mixer.tracks[track].level.float / time

proc isPlaying*(): bool =
  engine().mixer.lock.withLock:
    for track in engine().mixer.tracks.mvalues:
      for playback in track.playing.values:
        if not playback.paused:
          return true
  return false

proc isPlaying*(track: string): bool =
  engine().mixer.lock.withLock:
    if engine().mixer.tracks.contains(track):
      for playback in engine().mixer.tracks[track].playing.values:
        if not playback.paused:
          return true
    return false

func applyLevel(sample: Sample, levelLeft, levelRight: AudioLevel): Sample =
  [int16(float(sample[0]) * levelLeft), int16(float(sample[1]) * levelRight)]

func clip(value: int32): int16 =
  int16(max(min(int32(high(int16)), value), int32(low(int16))))

# used for combining sounds
func mix(a, b: Sample): Sample =
  [clip(int32(a[0]) + int32(b[0])), clip(int32(a[1]) + int32(b[1]))]

proc updateSoundBuffer*(mixer: var Mixer) =
  let t = getMonoTime()

  let dt = (t - mixer.lastUpdate).inNanoseconds.float64 / 1_000_000_000'f64
  mixer.lastUpdate = t

  # update fadings
  for track in mixer.tracks.mvalues:
    if track.fadeTime > 0:
      track.fadeTime -= dt
      track.level = (track.level.float64 + track.fadeStep.float64 * dt).clamp(
        AudioLevel.low, AudioLevel.high
      )
      if track.fadeTime <= 0:
        track.level = track.targetLevel
  # mix
  var hasData = false
  for i in 0 ..< mixer.buffers[mixer.currentBuffer].len:
    var mixedSample = [0'i16, 0'i16]
    mixer.lock.withLock:
      for track in mixer.tracks.mvalues:
        var stoppedSounds: seq[uint64]
        for (id, playback) in track.playing.mpairs:
          if playback.paused:
            continue
          let sample = applyLevel(
            playback.sound[playback.position],
            mixer.level * track.level * playback.levelLeft,
            mixer.level * track.level * playback.levelRight,
          )
          mixedSample = mix(mixedSample, sample)
          hasData = true
          inc playback.position
          if playback.position >= playback.sound.len:
            if playback.loop:
              playback.position = 0
            else:
              stoppedSounds.add id
        for id in stoppedSounds:
          track.playing.del(id)
      mixer.buffers[mixer.currentBuffer][i] = mixedSample
  # send data to sound device
  if hasData:
    mixer.device.WriteSoundData(mixer.currentBuffer)
    mixer.currentBuffer = (mixer.currentBuffer + 1) mod mixer.buffers.len

# DSP functions
# TODO: finish implementation, one day

#[
#
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

    ]#

proc setupDevice(mixer: var Mixer) =
  # call this inside audio thread
  var bufferaddresses: seq[ptr SoundData]
  for i in 0 ..< NBUFFERS:
    mixer.buffers.add newSeq[Sample](BUFFERSAMPLECOUNT)
  for i in 0 ..< mixer.buffers.len:
    bufferaddresses.add (addr mixer.buffers[i])
  mixer.device = OpenSoundDevice(AUDIO_SAMPLE_RATE, bufferaddresses)

proc destroy(mixer: var Mixer) =
  mixer.lock.deinitLock()
  mixer.device.CloseSoundDevice()

proc audioWorker*(mixer: ptr Mixer) {.thread.} =
  mixer[].setupDevice()
  onThreadDestruction(
    proc() =
      mixer[].lock.withLock(mixer[].destroy())
      freeShared(mixer)
  )
  while true:
    mixer[].updateSoundBuffer()
