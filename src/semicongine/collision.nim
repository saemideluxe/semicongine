import ./core
import ./scene

const MAX_COLLISON_DETECTION_ITERATIONS = 20

type
  HitBox* = ref object of Component
    transform*: Mat4
  HitSphere* = ref object of Component
    radius*: float32

func between(value, b1, b2: float32): bool =
  min(b1, b2) <= value and value <= max(b1, b2)

func contains*(hitbox: HitBox, x: Vec3f): bool =
  # from https://math.stackexchange.com/questions/1472049/check-if-a-point-is-inside-a-rectangular-shaped-area-3d
  let
    t = hitbox.entity.getModelTransform() * hitbox.transform
    P1 = t * newVec3f(0, 0, 0) # origin
    P2 = t * Z
    P4 = t * X
    P5 = t * Y
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

# most generic implementation of findFurthestPoint
# add other implementations of findFurthestPoint for other kind of geometry or optimization
# (will be selected depening on type of the first parameter)
func findFurthestPoint(points: openArray[Vec3f], direction: Vec3f): Vec3f =
  var maxDist = low(float32)
  for p in points:
    let dist = direction.dot(p)
    if dist > maxDist:
      maxDist = dist
      result = p

func findFurthestPoint(hitsphere: HitSphere, direction: Vec3f): Vec3f =
  let directionNormalizedToSphere = ((direction / direction.length) * hitsphere.radius)
  return hitsphere.entity.getModelTransform() * directionNormalizedToSphere

func findFurthestPoint(hitbox: HitBox, direction: Vec3f): Vec3f =
  let transform = hitbox.entity.getModelTransform() * hitbox.transform
  return findFurthestPoint(
    [
      transform * newVec3f(0, 0, 0),
      transform * X,
      transform * Y,
      transform * Z,
      transform * (X + Y),
      transform * (X + Z),
      transform * (Y + Z),
      transform * (X + Y + Z),
    ],
    direction
  )

func supportPoint[A, B](a: A, b: B, direction: Vec3f): Vec3f =
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

func intersects*[A, B](a: A, b: B): bool =
  var
    support = supportPoint(a, b, newVec3f(0.8153, -0.4239, 0.5786)) # just random initial vector
    simplex = newSeq[Vec3f]()
    direction = -support
    n = 0
  simplex.insert(support, 0)
  while n < MAX_COLLISON_DETECTION_ITERATIONS:
    support = supportPoint(a, b, direction)
    if support.dot(direction) <= 0:
        return false
    simplex.insert(support, 0)
    if nextSimplex(simplex, direction):
      return true
    # prevent numeric instability
    if direction == newVec3f(0, 0, 0):
      direction[0] = 0.001
    inc n

func calculateHitbox*(points: seq[Vec3f]): HitBox =
  var
    minX = high(float32)
    maxX = low(float32)
    minY = high(float32)
    maxY = low(float32)
    minZ = high(float32)
    maxZ = low(float32)

  for p in points:
    minX = min(minX, p.x)
    maxX = max(maxX, p.x)
    minY = min(minY, p.y)
    maxY = max(maxY, p.y)
    minZ = min(minZ, p.z)
    maxZ = max(maxz, p.z)

  let
    scaleX = (maxX - minX)
    scaleY = (maxY - minY)
    scaleZ = (maxZ - minZ)

  HitBox(transform: translate3d(minX, minY, minZ) * scale3d(scaleX, scaleY, scaleZ))

func calculateHitsphere*(points: seq[Vec3f]): HitSphere =
  result = HitSphere()
  for p in points:
    result.radius = max(result.radius, p.length)
