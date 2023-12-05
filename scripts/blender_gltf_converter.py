import os
import sys

import bpy


def runner():
    argv = sys.argv
    print(sys.argv)
    script_args = sys.argv[sys.argv.index("--") + 1 :]
    inputfile = script_args[0]
    outputfile = script_args[1]
    if not os.path.exists(inputfile):
        print(f"Input file '{inputfile}' does not exists")
        quit(1)
    if not outputfile.endswith(".glb"):
        print(f"Output file '{outputfile}' is not a *.glb file")

    bpy.ops.wm.open_mainfile(filepath=inputfile)
    bpy.ops.export_scene.gltf(filepath=outputfile[:-4], export_apply=True)


if __name__ == "__main__":
    runner()
