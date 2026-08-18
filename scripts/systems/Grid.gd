extends RefCounted
class_name Grid
## World-space <-> grid-cell coordinate conversion. CELL_SIZE is a
## placeholder — the actual grid/cell size is still undecided (see
## docs/05_decisions_log.md, "캐릭터 스프라이트 해상도 및 그리드 칸 크기"),
## kept here as the single place to retune once that's settled.

const CELL_SIZE := 1.0

static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))

static func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)

## Raycasts from a screen position through `camera` onto the floor plane
## (y = floor_y) and returns the grid cell there, or null if the ray never
## hits the floor plane (camera facing away from it, etc.). Shared by
## Player (click-to-move) and GridOverlay (hover highlight) so both agree
## on exactly the same math.
static func raycast_to_cell(camera: Camera3D, screen_pos: Vector2, floor_y: float = 0.0) -> Variant:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var floor_plane := Plane(Vector3.UP, floor_y)
	var hit = floor_plane.intersects_ray(from, dir)
	if hit == null:
		return null
	return world_to_cell(hit)
