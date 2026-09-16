extends MeshInstance3D
## Shows the player's remaining movement range as a flat disc during their
## combat turn, or the armed skill's range (in a different color) while
## aiming one — see docs/03_combat_system.md "전투 중 이동과 스테미나"
## (2026-08-18) and "스킬 범위 구조". Replaces the old grid-line overlay
## (GridOverlay.gd) now that combat uses free movement instead of a grid.
## Without this, range/effect_radius were only checked in code and had no
## way to actually see or test on screen (2026-09-17).
##
## Visibility is fully owned by the combat scene script (e.g. Dungeon.gd) —
## it toggles `visible` on/off exactly when it's the player's turn. This
## script only ever updates size/color/position while already visible.

const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")

@export var move_color: Color = Color(0.3, 0.9, 1.0, 0.35)
@export var skill_color: Color = Color(1.0, 0.35, 0.25, 0.35)
@export var y_offset: float = 0.01

var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _material

func _process(_delta: float) -> void:
	if not visible:
		return
	var player := GameManager.player
	if player == null:
		return
	var radius: float
	if player.is_aiming():
		radius = player.equipped_skills[player.pending_skill_index].range
		_material.albedo_color = skill_color
	else:
		radius = CombatFormulasScript.max_move_distance(player.current_stamina)
		_material.albedo_color = move_color
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	mesh = disc
	global_position = Vector3(player.global_position.x, y_offset, player.global_position.z)
