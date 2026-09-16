extends MeshInstance3D
## Shows the player's remaining movement range as a flat disc during their
## combat turn. Replaces the old grid-line overlay (GridOverlay.gd) now that
## combat uses free movement instead of a grid — see
## docs/03_combat_system.md "전투 중 이동과 스테미나" (2026-08-18).
##
## Visibility is fully owned by the combat scene script (e.g. Dungeon.gd) —
## it toggles `visible` on/off exactly when it's the player's turn. This
## script only ever updates size/position while already visible.

const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")

@export var disc_color: Color = Color(0.3, 0.9, 1.0, 0.35)
@export var y_offset: float = 0.01

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = disc_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = material

func _process(_delta: float) -> void:
	if not visible:
		return
	var player := GameManager.player
	if player == null:
		return
	var radius: float = CombatFormulasScript.max_move_distance(player.current_stamina)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	mesh = disc
	global_position = Vector3(player.global_position.x, y_offset, player.global_position.z)
