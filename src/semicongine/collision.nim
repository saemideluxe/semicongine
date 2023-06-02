import ./core
import ./scene

type
  Hitbox* = ref object of Component
    transform*: Mat4

#[
    dir1   
    from core to point
    dir_vec = point - cube3d_center

    res1 = np.where( (np.absolute(np.dot(dir_vec, dir1)) * 2) > size1 )[0]
    res2 = np.where( (np.absolute(np.dot(dir_vec, dir2)) * 2) > size2 )[0]
    res3 = np.where( (np.absolute(np.dot(dir_vec, dir3)) * 2) > size3 )[0]
]#

func between(value, b1, b2: float32): bool =
  min(b1, b2) <= value and value <= max(b1, b2)

func contains*(hitbox: Hitbox, x: Vec3f): bool =
  # from https://math.stackexchange.com/questions/1472049/check-if-a-point-is-inside-a-rectangular-shaped-area-3d
  let
    t = hitbox.entity.getModelTransform() * hitbox.transform
    P1 = t * newVec4f(0, 0, 0, 1) # origin
    P2 = t * Z.toVec4(1'f32)
    P4 = t * X.toVec4(1'f32)
    P5 = t * Y.toVec4(1'f32)
    u = (P1 - P4).cross(P1 - P5)
    v = (P1 - P2).cross(P1 - P5)
    w = (P1 - P2).cross(P1 - P4)
    uP1 = u.dot(P1)
    uP2 = u.dot(P2)
    vP1 = v.dot(P1)
    vP4 = v.dot(P4)
    wP1 = w.dot(P1)
    wP5 = w.dot(P5)
    ux = u.dot(x)
    vx = v.dot(x)
    wx = w.dot(x)

  result = ux.between(uP1, uP2) and vx.between(vP1, vP4) and wx.between(wP1, wP5)

# implementation of GJK, based on https://blog.winter.dev/2020/gjk-algorithm/

func findFurthestPoint(points: openArray[Vec3f], direction: Vec3f): Vec3f =
  var maxDist = low(float32)
  for p in points:
    let dist = direction.dot(p)
    if dist > maxDist:
      maxDist = dist
      result = p

func supportPoint(a, b: openArray[Vec3f], direction: Vec3f): Vec3f =
  a.findFurthestPoint(direction) - b.findFurthestPoint(-direction)

func sameDirection(direction: Vec3f, ao: Vec3f): bool =
  direction.dot(ao) > 0

func line(simplex: var seq[Vec3f], direction: var Vec3f): bool =
  let
    a = simplex[0]
    b = simplex[1]
    ab = b - a
    ao =   - a

  if sameDirection(ab, ao):
    direction = cross(cross(ab, ao), ab)
  else:
    simplex = @[a]
    direction = ao

  return false

func triangle(simplex: var seq[Vec3f], direction: var Vec3f): bool =
  let
    a = simplex[0]
    b = simplex[1]
    c = simplex[2]
    ab = b - a
    ac = c - a
    ao =   - a
    abc = ab.cross(ac)
 
  if sameDirection(abc.cross(ac), ao):
    if sameDirection(ac, ao):
      simplex = @[a, c]
      direction = ac.cross(ao).cross(ac);
    else:
      simplex = @[a, b]
      return line(simplex, direction)
  else:
    if (sameDirection(ab.cross(abc), ao)):
      simplex = @[a, b]
      return line(simplex, direction)
    else:
      if (sameDirection(abc, ao)):
        direction = abc
      else:
        simplex = @[ a, c, b]
        direction = -abc

  return false

func tetrahedron(simplex: var seq[Vec3f], direction: var Vec3f): bool =
  let
    a = simplex[0]
    b = simplex[1]
    c = simplex[2]
    d = simplex[3]
    ab = b - a
    ac = c - a
    ad = d - a
    ao =   - a
    abc = ab.cross(ac)
    acd = ac.cross(ad)
    adb = ad.cross(ab)
 
  if sameDirection(abc, ao):
    simplex = @[a, b, c]
    return triangle(simplex, direction)
  if sameDirection(acd, ao):
    simplex = @[a, c, d]
    return triangle(simplex, direction)
  if sameDirection(adb, ao):
    simplex = @[a, d, b]
    return triangle(simplex, direction)
 
  return true

func nextSimplex(simplex: var seq[Vec3f], direction: var Vec3f): bool =
  case simplex.len
  of 2: simplex.line(direction)
  of 3: simplex.triangle(direction)
  of 4: simplex.tetrahedron(direction)
  else: raise newException(Exception, "Error in simplex")

func overlaps*(a, b: openArray[Vec3f]): bool =
  var support = supportPoint(a, b, X)
  var simplex: seq[Vec3f]
  simplex.insert(support, 0)
  var direction = -support;
  while true:
    support = supportPoint(a, b, direction)
    if support.dot(direction) <= 0:
        return false
    simplex.insert(support, 0)
    if nextSimplex(simplex, direction):
      return true
    # prevent a numeric instability
    if direction == newVec3f(0, 0, 0):
      direction[0] = 0.001

func overlaps*(a, b: Hitbox): bool =
  let ta = a.entity.getModelTransform() * a.transform
  let tb = b.entity.getModelTransform() * b.transform
  let points1 = [
    (ta * newVec4f(0, 0, 0, 1)).toVec3,
    (ta * X.toVec4(1'f32)).toVec3,
    (ta * Y.toVec4(1'f32)).toVec3,
    (ta * Z.toVec4(1'f32)).toVec3,
    (ta * (X + Y).toVec4(1'f32)).toVec3,
    (ta * (X + Z).toVec4(1'f32)).toVec3,
    (ta * (Y + Z).toVec4(1'f32)).toVec3,
    (ta * (X + Y + Z).toVec4(1'f32)).toVec3,
  ]
  let points2 = [
    (tb * newVec4f(0, 0, 0, 1)).toVec3,
    (tb * X.toVec4(1'f32)).toVec3,
    (tb * Y.toVec4(1'f32)).toVec3,
    (tb * Z.toVec4(1'f32)).toVec3,
    (tb * (X + Y).toVec4(1'f32)).toVec3,
    (tb * (X + Z).toVec4(1'f32)).toVec3,
    (tb * (Y + Z).toVec4(1'f32)).toVec3,
    (tb * (X + Y + Z).toVec4(1'f32)).toVec3,
  ]
  return overlaps(points1, points2)
