extends MeshInstance3D
## Visual grid-line overlay matching Grid.CELL_SIZE. Hidden by default —
## Dungeon.gd shows it while GameManager.in_combat is true. Rebuilds
## automatically at _ready() so it always matches the current CELL_SIZE.

const GridScript := preload("res://scripts/systems/Grid.gd")

@export var half_extent: float = 10.0  # covers -half_extent..+half_extent on both axes
@export var line_color: Color = Color(0.3, 0.9, 1.0, 0.6)
@export var line_y: float = 0.01  # lifted slightly above the floor to avoid z-fighting
@export var highlight_color: Color = Color(1, 1, 0.3, 0.35)

var _highlight: MeshInstance3D

func _ready() -> void:
	_build_mesh()
	_build_highlight()

func _build_highlight() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(GridScript.CELL_SIZE, GridScript.CELL_SIZE) * 0.9  # slightly smaller than a cell so grid lines stay visible around it
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = highlight_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight = MeshInstance3D.new()
	_highlight.mesh = quad
	_highlight.material_override = material
	_highlight.visible = false
	add_child(_highlight)

## Shows which cell a click would move the player to (see Player.gd's
## click-to-move). Uses whatever camera is currently active rather than a
## direct Player reference, so this stays decoupled from Player entirely.
func _process(_delta: float) -> void:
	if not visible:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_highlight.visible = false
		return
	var cell = GridScript.raycast_to_cell(camera, get_viewport().get_mouse_position(), line_y)
	if cell == null:
		_highlight.visible = false
		return
	_highlight.position = GridScript.cell_to_world(cell, line_y + 0.001)
	_highlight.visible = true

func _build_mesh() -> void:
	var cell_size: float = GridScript.CELL_SIZE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(line_color)

	# Lines are drawn at half-cell offsets (cell boundaries), not at the
	# integer coordinates Grid.gd uses for cell centers — otherwise entities
	# snapped to integer coordinates end up sitting on line intersections
	# (cell corners) instead of inside a cell.
	var steps := int(ceil(half_extent / cell_size)) + 1
	for i in range(-steps, steps + 1):
		var offset := (i + 0.5) * cell_size
		if abs(offset) > half_extent + cell_size:
			continue
		st.add_vertex(Vector3(offset, line_y, -half_extent))
		st.add_vertex(Vector3(offset, line_y, half_extent))
		st.add_vertex(Vector3(-half_extent, line_y, offset))
		st.add_vertex(Vector3(half_extent, line_y, offset))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.set_material(material)

	mesh = st.commit()
