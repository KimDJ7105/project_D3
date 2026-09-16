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

## Distance on the XZ plane only (ignores Y/elevation) — range and effect-
## radius checks are judged on this plane; elevation is a separate range/
## accuracy bonus, not part of the radius check (docs/03_combat_system.md
## "스킬 범위 구조").
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
