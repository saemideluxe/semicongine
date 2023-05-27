import std/os
import std/sequtils
import std/times

import semicongine


proc test1() =
  mixer[].addSound("test1", newSound(sineSoundData(1000, 2, 44100)))
  mixer[].addSound("test2", newSound(sineSoundData(500, 2, 44100)))


  let s1 = mixer[].play("test1", loop=true)
  let s2 = mixer[].play("test2", loop=true)

  let t0 = now()
  while true:
    let runtime = (now() - t0).inMilliseconds()
    if runtime > 1500:
      mixer[].setLevel(0.1)
    if runtime > 3000:
      mixer[].stop(s2)
    if runtime > 6000:
      mixer[].stop("")
    if runtime > 8000:
      break

proc test2() =
  let
    # notes
    c = sineSoundData(261.6256, 0.5, 44100)
    d = sineSoundData(293.6648, 0.5, 44100)
    e = sineSoundData(329.6276, 0.5, 44100)
    f = sineSoundData(349.2282, 0.5, 44100)
    g = sineSoundData(391.9954, 0.5, 44100)
    a = sineSoundData(440.0000, 0.5, 44100)
    b = sineSoundData(493.8833, 0.5, 44100)
    bb = sineSoundData(466.1638, 0.5, 44100)
    c2 = sineSoundData(523.2511, 0.5, 44100)
    d2 = sineSoundData(587.3295, 0.5, 44100)
    bbShort = sineSoundData(466.1638, 0.25, 44100)
    c2Short = sineSoundData(523.2511, 0.25, 44100)
    d2Short = sineSoundData(587.3295, 0.25, 44100)

    # song
    frerejaquesData = concat(
      f, g, a, f,
      f, g, a, f,
      a, bb, c2, c2,
      a, bb, c2, c2,
      c2Short, d2Short, c2Short, bbShort, a, f,
      c2Short, d2Short, c2Short, bbShort, a, f,
      f, c, f, f,
      f, c, f, f,
    )

  mixer[].addSound("frerejaques", newSound(frerejaquesData))
  discard mixer[].play("frerejaques")

  while mixer[].isPlaying():
    sleep(1)

proc test3() =
  mixer[].addSound("pianosong", loadAudio("test.ogg"))
  mixer[].addSound("ping", newSound(sineSoundData(500, 0.05, 44100)))
  mixer[].addTrack("effects")
  discard mixer[].play("pianosong")

  while mixer[].isPlaying():
    discard mixer[].play("ping", track="effects", stopOtherSounds=true, level=0.5)
    discard stdin.readLine()

when isMainModule:
  startMixerThread()
  test1()
  mixer[].stop()
  test2()
  mixer[].stop()
  test3()
  mixer[].stop()
