import std/tables
import std/math
import std/sequtils

import ./audiotypes
import ./platform/audio

export audiotypes

type
  Playback = object
    sound: Sound
    position: int
    loop: bool
    levelLeft: Level
    levelRight: Level
  Track = object
    playing: Table[uint64, Playback]
    level: Level

  Mixer* = object
    playbackCounter: uint64
    tracks: Table[string, Track]
    sounds*: Table[string, Sound]
    level: Level
    device: NativeSoundDevice


proc loadSoundResource(resourcePath: string): Sound =
  assert false, "Not implemented yet"

func applyLevel(sample: Sample, level: Level): Sample =
 (int16(float(sample[0]) * level), int16(float(sample[1]) * level))

func applyLevel(sample: Sample, levelLeft, levelRight: Level): Sample =
 (int16(float(sample[0]) * levelLeft), int16(float(sample[1]) * levelRight))

func mix(a, b: Sample): Sample =
  var
    left = int32(a[0]) + int32(b[0])
    right = int32(a[1]) + int32(b[1])
  left = max(min(int32(high(int16)), left), int32(low(int16)))
  right = max(min(int32(high(int16)), right), int32(low(int16)))
  (int16(left), int16(right))

proc initMixer*(): Mixer =
  Mixer(
    tracks: {"": Track(level: 1'f)}.toTable,
    level: 1'f,
    device: openSoundDevice(SAMPLERATE, BUFFERSIZE),
  )

proc loadSound*(mixer: var Mixer, name: string, resource: string) =
  assert not (name in mixer.sounds)
  mixer.sounds[name] = loadSoundResource(resource)

proc addSound*(mixer: var Mixer, name: string, sound: Sound) =
  assert not (name in mixer.sounds)
  mixer.sounds[name] = sound

proc addTrack*(mixer: var Mixer, name: string) =
  assert not (name in mixer.tracks)
  mixer.tracks[name] = Track(level: 1'f)

proc play*(mixer: var Mixer, soundName: string, track="", stopOtherSounds=false, loop=false, levelLeft, levelRight: Level): uint64 =
  assert track in mixer.tracks
  assert soundName in mixer.sounds
  if stopOtherSounds:
    mixer.tracks[track].playing.clear()
  mixer.tracks[track].playing[mixer.playbackCounter] = Playback(
    sound: mixer.sounds[soundName],
    position: 0,
    loop: loop,
    levelLeft: levelLeft,
    levelRight: levelRight
  )
  result = mixer.playbackCounter
  inc mixer.playbackCounter
proc play*(mixer: var Mixer, soundName: string, track="", stopOtherSounds=false, loop=false, level: Level=1'f): uint64 =
  play(mixer=mixer, soundName=soundName, track=track, stopOtherSounds=stopOtherSounds, loop=loop, levelLeft=level, levelRight=level)

proc stop*(mixer: var Mixer) =
  for track in mixer.tracks.mvalues:
    track.playing.clear()

proc getLevel*(mixer: var Mixer): Level = mixer.level
proc getLevel*(mixer: var Mixer, track: string): Level = mixer.tracks[track].level
proc getLevel*(mixer: var Mixer, playbackId : uint64): (Level, Level) =
  for track in mixer.tracks.mvalues:
    if playbackId in track.playing:
      return (track.playing[playbackId].levelLeft, track.playing[playbackId].levelRight)

proc setLevel*(mixer: var Mixer, level: Level) = mixer.level = level
proc setLevel*(mixer: var Mixer, track: string, level: Level) = mixer.tracks[track].level = level
proc setLevel*(mixer: var Mixer, playbackId: uint64, levelLeft, levelRight: Level) =
  for track in mixer.tracks.mvalues:
    if playbackId in track.playing:
      track.playing[playbackId].levelLeft = levelLeft
      track.playing[playbackId].levelRight = levelRight
proc setLevel*(mixer: var Mixer, playbackId : uint64, level: Level) =
  setLevel(mixer, playbackId, level, level)

proc stop*(mixer: var Mixer, track: string) =
  assert track in mixer.tracks
  mixer.tracks[track].playing.clear()

proc stop*(mixer: var Mixer, playbackId: uint64) =
  for track in mixer.tracks.mvalues:
    if playbackId in track.playing:
      track.playing.del(playbackId)
      break

proc nextBufferData(mixer: var Mixer, nSamples: uint64): seq[Sample] =
  result = newSeq[Sample](nSamples)
  for i in 0 ..< nSamples:
    var currentSample = (0'i16, 0'i16)
    for track in mixer.tracks.mvalues:
      var stoppedSounds: seq[uint64]
      for (id, playback) in track.playing.mpairs:
        let sample = applyLevel(
          playback.sound[][playback.position],
          mixer.level * track.level * playback.levelLeft,
          mixer.level * track.level * playback.levelRight,
        )
        currentSample = mix(currentSample, sample)
        inc playback.position
        if playback.position >= playback.sound[].len:
          if playback.loop:
            playback.position = 0
          else:
            stoppedSounds.add id
      for id in stoppedSounds:
        track.playing.del(id)
    result[i] = currentSample

proc updateSoundBuffer*(mixer: var Mixer) =
  var buffer = mixer.nextBufferData(BUFFERSIZE)
  mixer.device.updateSoundBuffer(buffer)

proc destroy*(mixer: Mixer) =
  mixer.device.closeSoundDevice()
