extends MeshInstance3D
## Visual grid-line overlay matching Grid.CELL_SIZE. Hidden by default —
## Dungeon.gd shows it while GameManager.in_combat is true. Rebuilds
## automatically at _ready() so it always matches the current CELL_SIZE.

const GridScript := preload("res://scripts/systems/Grid.gd")

@export var half_extent: float = 10.0  # covers -half_extent..+half_extent on both axes
@export var line_color: Color = Color(0.3, 0.9, 1.0, 0.6)
@export var line_y: float = 0.01  # lifted slightly above the floor to avoid z-fighting

func _ready() -> void:
	_build_mesh()

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
