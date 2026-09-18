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

const TargetingScript := preload("res://scripts/systems/Targeting.gd")

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

## Elevation prototype (2026-09-19): a raised platform in the chamber with a
## ramp up to it, purely to exercise gravity / ground-following / height
## reading before the real floor-1 layout gets designed with height.
## Platform: [center_x, center_z, size_x, size_z, height]; its top is at
## `height`. Ramp: rises toward -Z from the floor (y=0) at RAMP_START_Z to
## the platform's top at RAMP_END_Z, across x = RAMP_CENTER_X +- RAMP_WIDTH/2.
const PLATFORM := [4.5, -6.5, 4.0, 3.0, 1.0]
const RAMP_CENTER_X := 4.5
const RAMP_WIDTH := 4.0
const RAMP_START_Z := -2.0
const RAMP_END_Z := -5.0
const RAMP_THICKNESS := 0.3

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
	_build_ground(rubble_material)
	_bake_navigation()

## Bakes a navmesh from this scene's solid geometry so combat click-moves
## can path around walls/pillars instead of teleporting through them. Runs
## once here, right after the geometry is built — the layout is fixed, so
## the result is always the same. Only layer-1 bodies count (walls, ground):
## enemy pick bodies are layer 2 and shouldn't carve holes.
func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.agent_radius = 0.4   # matches the player's capsule
	nav_mesh.agent_height = 1.2
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav_mesh
	add_child(region)

## Solid ground for gravity to land on. The visible floor is the Floor
## mesh in Dungeon.tscn — this adds the collision under it (top at y=0,
## no mesh of its own), plus the prototype platform and ramp.
func _build_ground(material: StandardMaterial3D) -> void:
	_add_ground_solid(Vector3(0, -0.5, 0), Vector3(24, 1, 24), 0.0, null)

	var height: float = PLATFORM[4]
	_add_ground_solid(
		Vector3(PLATFORM[0], height / 2.0, PLATFORM[1]),
		Vector3(PLATFORM[2], height, PLATFORM[3]), 0.0, material)

	# Ramp: a thin box tilted about X so its top surface runs from (y=0 at
	# RAMP_START_Z) to (y=height at RAMP_END_Z). Box center sits half a
	# thickness *below* the surface midpoint, along the surface normal.
	var run: float = RAMP_START_Z - RAMP_END_Z
	var length: float = sqrt(run * run + height * height)
	var angle: float = atan2(height, run)
	var surface_mid := Vector3(RAMP_CENTER_X, height / 2.0, (RAMP_START_Z + RAMP_END_Z) / 2.0)
	var normal := Vector3(0.0, cos(angle), sin(angle))
	_add_ground_solid(
		surface_mid - normal * (RAMP_THICKNESS / 2.0),
		Vector3(RAMP_WIDTH, RAMP_THICKNESS, length), rad_to_deg(angle), material)

## Ground bodies sit on layer 1 (so the player collides with them) *and*
## Targeting.GROUND_LAYER (so height/click rays can find them without
## hitting walls). Pass a null material for collision-only.
func _add_ground_solid(center: Vector3, size: Vector3, rotation_x_deg: float, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | TargetingScript.GROUND_LAYER
	body.position = center
	body.rotation_degrees.x = rotation_x_deg
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	if material != null:
		var box := BoxMesh.new()
		box.size = size
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	add_child(body)

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
