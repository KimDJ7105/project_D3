extends Node3D
## Floor 1, variant 1 — the first hand-designed dungeon layout
## (docs/02_dungeon_town_structure.md "층별 변형 풀", 2026-09-17). Plain
## ruins theme: gray stone walls, torches at intervals. This is ONE fixed
## variant, not a template or a generator — every position here is
## hand-picked and constant, no randomness. When variant 2 exists, it'll
## be its own equally-hardcoded layout, not a parameterization of this one
## (that's exactly what was rejected in favor of chunk/procedural assembly).
##
## Deliberately built as open, continuous space rather than discrete
## "rooms" connected by corridors — a fixed hand-authored variant doesn't
## need the room-graph structure that procedural connection algorithms
## require, and an open cave/ruin with pillars and rubble breaking up
## sightlines fits the "ancient ruins" theme better than boxy rooms would.
## Built at runtime from hardcoded coordinate lists (like MovementRangeIndicator
## builds its disc mesh) rather than typed out as dozens of individual scene
## nodes — same content, easier to read/adjust as a list of numbers.

const WALL_HEIGHT := 3.0
const WALL_COLOR := Color(0.45, 0.45, 0.48)
const RUBBLE_COLOR := Color(0.4, 0.38, 0.36)
const TORCH_POST_COLOR := Color(0.22, 0.18, 0.15)
const TORCH_LIGHT_COLOR := Color(1.0, 0.6, 0.28)

## Each entry: [center_x, center_z, size_x, size_z]. Boundary walls on the
## west/north/east sides, jogged rather than a clean rectangle. South
## (toward the entrance) is deliberately left open.
const WALLS := [
	[-8.0, 3.0, 1.0, 14.0],    # west wall, entrance-area half
	[-9.5, -6.0, 1.0, 10.0],   # west wall, chamber half (jogged out slightly)
	[0.0, -11.0, 20.0, 1.0],   # north wall (far end cap)
	[9.0, -6.0, 1.0, 10.0],    # east wall, chamber half
	[7.5, 4.0, 1.0, 14.0],     # east wall, entrance-area half (jogged in slightly)
]

## Interior pillars/rubble narrowing the path between the entrance area and
## the main chamber — a chokepoint without a literal corridor.
const PILLARS := [
	[-3.0, 2.0, 3.0, 2.0],
	[3.0, 2.0, 3.0, 2.0],
]

## Torch positions (post + warm point light), scattered along the walls.
const TORCHES := [
	[-7.5, 6.0], [7.0, 6.0],
	[-8.5, -3.0], [8.0, -3.0],
	[0.0, -10.0], [-6.0, -9.0], [6.0, -9.0],
]

func _ready() -> void:
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = WALL_COLOR
	wall_material.roughness = 1.0

	var rubble_material := StandardMaterial3D.new()
	rubble_material.albedo_color = RUBBLE_COLOR
	rubble_material.roughness = 1.0

	for entry in WALLS:
		_add_block(entry[0], entry[1], entry[2], entry[3], WALL_HEIGHT, wall_material)
	for entry in PILLARS:
		_add_block(entry[0], entry[1], entry[2], entry[3], WALL_HEIGHT, rubble_material)
	for entry in TORCHES:
		_add_torch(entry[0], entry[1])

func _add_block(center_x: float, center_z: float, size_x: float, size_z: float, height: float, material: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size_x, height, size_z)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(center_x, height / 2.0, center_z)
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.position = Vector3(center_x, height / 2.0, center_z)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size_x, height, size_z)
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)

func _add_torch(x: float, z: float) -> void:
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = TORCH_POST_COLOR

	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.2, 1.2, 0.2)
	post.mesh = post_mesh
	post.material_override = post_material
	post.position = Vector3(x, 0.6, z)
	add_child(post)

	var light := OmniLight3D.new()
	light.light_color = TORCH_LIGHT_COLOR
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(x, 1.3, z)
	add_child(light)
