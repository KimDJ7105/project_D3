extends RefCounted
class_name Targeting
## World-space raycasting and range math for free-movement combat — click-
## to-move and skill/throw targeting all resolve a screen click to a floor
## point and then measure against it. Replaces the old grid-cell system
## (Grid.gd) now that combat isn't tile-based — see docs/03_combat_system.md
## "전투 중 이동과 스테미나" / "스킬 범위 구조" (2026-08-18).

## Raycasts from a screen position through `camera` onto the floor plane
## (y = floor_y) and returns the world-space hit point, or null if the ray
## never hits the floor plane (camera facing away from it, etc.). Shared by
## Player (click-to-move) and MovementRangeIndicator (hover preview) so both
## agree on exactly the same math.
static func raycast_to_floor_point(camera: Camera3D, screen_pos: Vector2, floor_y: float = 0.0) -> Variant:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var floor_plane := Plane(Vector3.UP, floor_y)
	return floor_plane.intersects_ray(from, dir)

## Physics layer (bit value, i.e. layer 2) enemies' click-pick bodies live
## on. Walls stay on the default layer 1, so a pick ray masked to this
## layer ignores them entirely — a wall drawn in front of an enemy can't
## steal the click. Separate from what blocks player movement (layer 1).
const ENEMY_PICK_LAYER := 2

## Physics layer (bit value, i.e. layer 3) for walkable ground: the floor,
## platforms, ramps. Ground bodies also sit on layer 1 so the player still
## collides with them; walls are layer 1 only, so height/click rays masked
## to this layer see the ground and ignore walls.
const GROUND_LAYER := 4

## Height of the ground at (x, z), found by casting straight down from
## `from_y` against ground bodies only. Null if there's no ground below.
## This is how terrain height is read — the same works for any authored
## geometry (platforms, ramps, slopes), no height grid needed.
static func ground_height(world: World3D, x: float, z: float, from_y: float) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, from_y, z), Vector3(x, from_y - 100.0, z), GROUND_LAYER)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position.y

## Like raycast_to_floor_point(), but hits the real ground geometry under
## the cursor instead of assuming a flat plane. On a tilted camera a flat-
## plane guess is off by ~2x the height difference once the player stands
## on a platform. Falls back to the plane at `fallback_y` if the ray finds
## no ground.
static func raycast_to_ground(camera: Camera3D, screen_pos: Vector2, fallback_y: float) -> Variant:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to, GROUND_LAYER)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return raycast_to_floor_point(camera, screen_pos, fallback_y)
	return hit.position

## Casts a ray from the screen position through `camera` against enemy pick
## bodies only, and returns the enemy node (the pick body's parent) it hit
## first, or null. Used instead of the floor-plane point for single-target
## skills: on a tilted camera a click on an enemy's body lands on the floor
## well *behind* its feet, so a floor-point tolerance check misses.
static func pick_enemy(camera: Camera3D, screen_pos: Vector2) -> Node3D:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to, ENEMY_PICK_LAYER)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return (hit.collider as Node).get_parent() as Node3D

## Distance on the XZ plane only (ignores Y/elevation) — range and effect-
## radius checks are judged on this plane; elevation is a separate range/
## accuracy bonus, not part of the radius check (docs/03_combat_system.md
## "스킬 범위 구조").
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
