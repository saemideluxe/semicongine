import semicongine

const w = 500
const h = 500

var o = "P2\n" & $ w & " " & $ h & "\n255\n"

for y in 0 ..< h:
  for x in 0 ..< w:
    let v = (
      perlin(newVec2f(float(x) * 0.01, float(y) * 0.01)) * 0.7 +
      perlin(newVec2f(float(x) * 0.05, float(y) * 0.05)) * 0.25 +
      perlin(newVec2f(float(x) * 0.2, float(y) * 0.2)) * 0.05
    )
    o = o & $(int((v * 0.5 + 0.5) * 255)) & " "
  o = o & "\n"
echo o
