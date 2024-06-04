import std/os
import std/sequtils
import std/times

import semicongine


proc test1() =
  mixer[].AddSound("test1", NewSound(SineSoundData(1000, 2, 44100)))
  mixer[].AddSound("test2", NewSound(SineSoundData(500, 2, 44100)))


  let s1 = mixer[].Play("test1", loop = true)
  let s2 = mixer[].Play("test2", loop = true)

  let t0 = now()
  mixer[].SetLevel(0.5)
  while true:
    let runtime = (now() - t0).inMilliseconds()
    if runtime > 1500:
      mixer[].SetLevel(0.2)
    if runtime > 3000:
      mixer[].Stop(s2)
    if runtime > 6000:
      mixer[].Stop("")
    if runtime > 8000:
      break

proc test2() =
  let
    # notes
    c = SineSoundData(261.6256, 0.5, 44100)
    d = SineSoundData(293.6648, 0.5, 44100)
    e = SineSoundData(329.6276, 0.5, 44100)
    f = SineSoundData(349.2282, 0.5, 44100)
    g = SineSoundData(391.9954, 0.5, 44100)
    a = SineSoundData(440.0000, 0.5, 44100)
    b = SineSoundData(493.8833, 0.5, 44100)
    bb = SineSoundData(466.1638, 0.5, 44100)
    c2 = SineSoundData(523.2511, 0.5, 44100)
    d2 = SineSoundData(587.3295, 0.5, 44100)
    bbShort = SineSoundData(466.1638, 0.25, 44100)
    c2Short = SineSoundData(523.2511, 0.25, 44100)
    d2Short = SineSoundData(587.3295, 0.25, 44100)

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

  mixer[].AddSound("frerejaques", NewSound(frerejaquesData))
  discard mixer[].Play("frerejaques")

  while mixer[].IsPlaying():
    sleep(1)

proc test3() =
  mixer[].AddSound("toccata et fugue", loadAudio("toccata_et_fugue.ogg"))
  mixer[].AddSound("ping", NewSound(SineSoundData(500, 0.05, 44100)))
  mixer[].AddTrack("effects")
  discard mixer[].Play("toccata et fugue")


when isMainModule:
  StartMixerThread()
  test1()
  mixer[].Stop()
  test2()
  mixer[].Stop()
  test3()

  while mixer[].IsPlaying():
    discard mixer[].Play("ping", track = "effects", stopOtherSounds = true, level = 0.5)
    # on windows we re-open stdin and this will not work
    when defined(linux):
      echo "Press q and enter to exit"
      if stdin.readLine() == "q":
        mixer[].Stop()
    elif defined(windows):
      sleep(5)
      mixer[].Stop()
