import std/sequtils
import std/times

import semicongine

proc test1() =
  var mixer = initMixer()
  mixer.addSound("test1", newSound(sineSoundData(1000, 2)))
  mixer.addSound("test2", newSound(sineSoundData(500, 2)))


  let s1 = mixer.play("test1", loop=true)
  let s2 = mixer.play("test2", loop=true)

  let t0 = now()
  while true:
    mixer.updateSoundBuffer()
    let runtime = (now() - t0).inMilliseconds()
    if runtime > 1500:
      mixer.setLevel(0.1)
    if runtime > 3000:
      mixer.stop(s2)
    if runtime > 6000:
      mixer.stop("")
    if runtime > 8000:
      mixer.stop()
      break
  mixer.destroy()

proc test2() =
  let
    # notes
    c = sineSoundData(261.6256, 0.5)
    d = sineSoundData(293.6648, 0.5)
    e = sineSoundData(329.6276, 0.5)
    f = sineSoundData(349.2282, 0.5)
    g = sineSoundData(391.9954, 0.5)
    a = sineSoundData(440.0000, 0.5)
    b = sineSoundData(493.8833, 0.5)
    bb = sineSoundData(466.1638, 0.5)
    c2 = sineSoundData(523.2511, 0.5)
    d2 = sineSoundData(587.3295, 0.5)
    bbShort = sineSoundData(466.1638, 0.25)
    c2Short = sineSoundData(523.2511, 0.25)
    d2Short = sineSoundData(587.3295, 0.25)

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

  var mixer = initMixer()
  mixer.addSound("frerejaques", newSound(frerejaquesData))
  discard mixer.play("frerejaques", loop=true)

  let t0 = now()
  while true:
    mixer.updateSoundBuffer()
    if (now() - t0).inMilliseconds() > 20000:
      break
  mixer.destroy()

proc test3() =

  var song: SoundData
  var f = open("tests/audiotest.PCM.s16le.48000.2")
  var readLen = 999
  while readLen > 0:
    var sample: Sample
    readLen = f.readBuffer(addr sample, sizeof(Sample))
    song.add sample

  var mixer = initMixer()
  mixer.addSound("pianosong", newSound(song))
  discard mixer.play("pianosong", loop=true)

  let t0 = now()
  while true:
    mixer.updateSoundBuffer()
    if (now() - t0).inMilliseconds() > 190_000:
      break
  mixer.destroy()

when isMainModule:
  test1()
  test2()
  test3()
