import os
import sys

import bpy


def runner():
    script_args = sys.argv[sys.argv.index("--") + 1 :]
    for i in range(0, len(script_args), 2):
        inputfile = script_args[i]
        outputfile = script_args[i + 1]
        if not os.path.exists(inputfile):
            print(f"Input file '{inputfile}' does not exists")
            quit(1)
        if not outputfile.endswith(".glb"):
            print(f"Output file '{outputfile}' is not a *.glb file")
            quit(1)

        bpy.ops.wm.open_mainfile(filepath=inputfile)
        bpy.ops.export_scene.gltf(filepath=outputfile[:-4], export_apply=True)


if __name__ == "__main__":
    runner()
