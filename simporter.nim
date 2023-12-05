import std/os
import std/paths
import std/dirs
import std/osproc
import std/cmdline
import std/strutils
import std/strformat

import ./semicongine/core/audiotypes

proc import_meshes*(files: seq[(string, string)]) =
  let converter_script = currentSourcePath.parentDir().joinPath("scripts/blender_gltf_converter.py")

  var args = @["--background", "--python", converter_script, "--"]
  for (input, output) in files:
    args.add input
    args.add output

  let p = startProcess("blender", args=args, options={poStdErrToStdOut, poUsePath})
  let exitCode = p.waitForExit()
  p.close()
  if exitCode != 0:
    raise newException(OSError, &"blender had exit code {exitCode}")

proc import_audio*(files: seq[(string, string)]) =
  for (input, output) in files:
    let p = startProcess("ffmpeg", args=["-y", "-i", input, "-ar", $AUDIO_SAMPLE_RATE, output], options={poStdErrToStdOut, poUsePath})
    let exitCode = p.waitForExit()
    p.close()
    if exitCode != 0:
      raise newException(OSError, &"ffmpeg had exit code {exitCode}")

when isMainModule:
  var meshfiles: seq[(string, string)]
  var audiofiles: seq[(string, string)]

  for arg in commandLineParams():
    if arg.count(':') != 1:
      raise newException(Exception, &"Argument {arg} requires exactly one colon to separate input from output, but it contains {arg.count(':')} colons.")
    let
      input_output = arg.split(':', 1)
      input = input_output[0]
      output = input_output[1]
    if not input.fileExists:
      raise newException(IOError, &"Not found: {input}")
    if not output.fileExists or input.fileNewer(output):
      echo &"{output} is outdated"
      if input.endsWith("blend"):
        meshfiles.add (input, output)
      elif input.endsWith("mp3") or input.endsWith("ogg") or input.endsWith("wav"):
        audiofiles.add (input, output)
      else:
        raise newException(Exception, &"unkown file type: {input}")
      Path(output.parentDir()).createDir()
    else:
      echo &"{output} is up-to-date"

  import_meshes meshfiles
  import_audio audiofiles
