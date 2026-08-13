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
