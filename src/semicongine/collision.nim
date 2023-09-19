import ./core

const MAX_COLLISON_DETECTION_ITERATIONS = 20
const MAX_COLLISON_POINT_CALCULATION_ITERATIONS = 20

type
  ColliderType* = enum
    Box, Sphere, Points
  Collider* = object
    transform*: Mat4 = Unit4F32
    case theType*: ColliderType
      of Box: discard
      of Sphere: radius*: float32
      of Points: points*: seq[Vec3f]

func between(value, b1, b2: float32): bool =
  min(b1, b2) <= value and value <= max(b1, b2)

func contains*(collider: Collider, x: Vec3f): bool =
  # from https://math.stackexchange.com/questions/1472049/check-if-a-point-is-inside-a-rectangular-shaped-area-3d
  case collider.theType:
  of Box:
    let
      P1 = collider.transform * newVec3f(0, 0, 0) # origin
      P2 = collider.transform * Z
      P4 = collider.transform * X
      P5 = collider.transform * Y
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
    ux.between(uP1, uP2) and vx.between(vP1, vP4) and wx.between(wP1, wP5)
  of Sphere:
    (collider.transform * x).length < (collider.transform * newVec3f()).length
  of Points:
    raise newException(Exception, "Points are not supported yet for 'contains'")

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

func findFurthestPoint(transform: Mat4, direction: Vec3f): Vec3f =
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
func findFurthestPoint(collider: Collider, direction: Vec3f): Vec3f =
  case collider.theType
  of Sphere:
    let directionNormalizedToSphere = ((direction / direction.length) * collider.radius)
    collider.transform * directionNormalizedToSphere
  of Box:
    findFurthestPoint(collider.transform, direction)
  of Points:
    findFurthestPoint(collider.points, direction)

func supportPoint(a, b: Collider, direction: Vec3f): Vec3f =
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

func triangle(simplex: var seq[Vec3f], direction: var Vec3f, twoDimensional=false): bool =
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
      direction = ac.cross(ao).cross(ac)
    else:
      simplex = @[a, b]
      return line(simplex, direction)
  else:
    if (sameDirection(ab.cross(abc), ao)):
      simplex = @[a, b]
      return line(simplex, direction)
    else:
      if twoDimensional:
        return true
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

func getFaceNormals(polytope: seq[Vec3f], faces: seq[int]): (seq[Vec4f], int) =
  var
    normals: seq[Vec4f]
    minTriangle = 0
    minDistance = high(float32)

  for i in countup(0, faces.len - 1, 3):
    let
      a = polytope[faces[i + 0]]
      b = polytope[faces[i + 1]]
      c = polytope[faces[i + 2]]

    var normal = (b - a).cross(c - a).normalized()
    var distance = normal.dot(a)

    if distance < 0:
      normal = normal * -1'f32
      distance = distance * -1'f32

    normals.add normal.toVec4(distance)

    if distance < minDistance:
      minTriangle = i div 3
      minDistance = distance

  return (normals, minTriangle)

func addIfUniqueEdge(edges: var seq[(int, int)], faces: seq[int], a: int, b: int) =
  let reverse = edges.find((faces[b], faces[a]))
  if (reverse >= 0):
    edges.delete(reverse)
  else:
    edges.add (faces[a], faces[b])

func nextSimplex(simplex: var seq[Vec3f], direction: var Vec3f, twoDimensional=false): bool =
  case simplex.len
  of 2: simplex.line(direction)
  of 3: simplex.triangle(direction, twoDimensional)
  of 4: simplex.tetrahedron(direction)
  else: raise newException(Exception, "Error in simplex")

func collisionPoint3D(simplex: var seq[Vec3f], a, b: Collider): tuple[normal: Vec3f, penetrationDepth: float32] =
  var
    polytope = simplex
    faces = @[
      0, 1, 2,
      0, 3, 1,
      0, 2, 3,
      1, 3, 2
    ]
    (normals, minFace) = getFaceNormals(polytope, faces)
    minNormal: Vec3f
    minDistance = high(float32)
    iterCount = 0

  while minDistance == high(float32) and iterCount < MAX_COLLISON_POINT_CALCULATION_ITERATIONS:
    minNormal = normals[minFace].xyz
    minDistance = normals[minFace].w
    var
      support = supportPoint(a, b, minNormal)
      sDistance = minNormal.dot(support)
    
    if abs(sDistance - minDistance) > 0.001'f32:
      minDistance = high(float32)
      var uniqueEdges: seq[(int, int)]
      var i = 0
      while i < normals.len:
        if sameDirection(normals[i], support):
          var f = i * 3

          addIfUniqueEdge(uniqueEdges, faces, f + 0, f + 1)
          addIfUniqueEdge(uniqueEdges, faces, f + 1, f + 2)
          addIfUniqueEdge(uniqueEdges, faces, f + 2, f + 0)

          faces[f + 2] = faces.pop()
          faces[f + 1] = faces.pop()
          faces[f + 0] = faces.pop()

          normals[i] = normals.pop()

          dec i
        inc i

      var newFaces: seq[int]
      for (edgeIndex1, edgeIndex2) in uniqueEdges:
        newFaces.add edgeIndex1
        newFaces.add edgeIndex2
        newFaces.add polytope.len
       
      polytope.add support

      var (newNormals, newMinFace) = getFaceNormals(polytope, newFaces)
      if newNormals.len == 0:
        break

      var oldMinDistance = high(float32)
      for j in 0 ..< normals.len:
        if normals[j].w < oldMinDistance:
          oldMinDistance = normals[j].w
          minFace = j

      if (newNormals[newMinFace].w < oldMinDistance):
        minFace = newMinFace + normals.len

      for f in newFaces:
        faces.add f
      for n in newNormals:
        normals.add n
    inc iterCount

  result = (normal: minNormal, penetrationDepth: minDistance + 0.001'f32)


func collisionPoint2D(polytopeIn: seq[Vec3f], a, b: Collider): tuple[normal: Vec2f, penetrationDepth: float32] =
  var
    polytope = polytopeIn
    minIndex = 0
    minDistance = high(float32)
    iterCount = 0
    minNormal: Vec2f

  while minDistance == high(float32) and iterCount < MAX_COLLISON_POINT_CALCULATION_ITERATIONS:
    for i in 0 ..< polytope.len:
      let
        j = (i + 1) mod polytope.len
        vertexI = polytope[i]
        vertexJ = polytope[j]
        ij = vertexJ - vertexI
      var
        normal = newVec2f(ij.y, -ij.x).normalized()
        distance = normal.dot(vertexI)

      if (distance < 0):
        distance *= -1'f32
        normal = normal * -1'f32

      if distance < minDistance:
        minDistance = distance
        minNormal = normal
        minIndex = j

    let
      support = supportPoint(a, b, minNormal.toVec3)
      sDistance = minNormal.dot(support)

    if(abs(sDistance - minDistance) > 0.001):
      minDistance = high(float32)
      polytope.insert(support, minIndex)
    inc iterCount

  result = (normal: minNormal, penetrationDepth: minDistance + 0.001'f32)

func intersects*(a, b: Collider): bool =
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
      direction[0] = 0.0001
    inc n

func collision*(a, b: Collider): tuple[hasCollision: bool, normal: Vec3f, penetrationDepth: float32] =
  var
    support = supportPoint(a, b, newVec3f(0.8153, -0.4239, 0.5786)) # just random initial vector
    simplex = newSeq[Vec3f]()
    direction = -support
    n = 0
  simplex.insert(support, 0)
  while n < MAX_COLLISON_DETECTION_ITERATIONS:
    support = supportPoint(a, b, direction)
    if support.dot(direction) <= 0:
        return result
    simplex.insert(support, 0)
    if nextSimplex(simplex, direction):
      let (normal, depth) = collisionPoint3D(simplex, a, b)
      return (true, normal, depth)
    # prevent numeric instability
    if direction == newVec3f(0, 0, 0):
      direction[0] = 0.0001
    inc n

func collision2D*(a, b: Collider): tuple[hasCollision: bool, normal: Vec2f, penetrationDepth: float32] =
  var
    support = supportPoint(a, b, newVec3f(0.8153, -0.4239, 0)) # just random initial vector
    simplex = newSeq[Vec3f]()
    direction = -support
    n = 0
  simplex.insert(support, 0)
  while n < MAX_COLLISON_DETECTION_ITERATIONS:
    support = supportPoint(a, b, direction)
    if support.dot(direction) <= 0:
        return result
    simplex.insert(support, 0)
    if nextSimplex(simplex, direction, twoDimensional=true):
      let (normal, depth) = collisionPoint2D(simplex, a, b)
      return (true, normal, depth)
    # prevent numeric instability
    if direction == newVec3f(0, 0, 0):
      direction[0] = 0.0001
    inc n

func calculateCollider*(points: openArray[Vec3f], theType: ColliderType): Collider =
  var
    minX = high(float32)
    maxX = low(float32)
    minY = high(float32)
    maxY = low(float32)
    minZ = high(float32)
    maxZ = low(float32)
    center: Vec3f

  for p in points:
    minX = min(minX, p.x)
    maxX = max(maxX, p.x)
    minY = min(minY, p.y)
    maxY = max(maxY, p.y)
    minZ = min(minZ, p.z)
    maxZ = max(maxz, p.z)
    center = center + p
  center = center / float32(points.len)

  let
    scaleX = (maxX - minX)
    scaleY = (maxY - minY)
    scaleZ = (maxZ - minZ)

  if theType == Points:
    result = Collider(theType: Points, points: @points)
  else:
    result = Collider(theType: theType, transform: translate(minX, minY, minZ) * scale(scaleX, scaleY, scaleZ))

    if theType == Sphere:
      result.transform = translate(center)
      for p in points:
        result.radius = max(result.radius, (p - center).length)
