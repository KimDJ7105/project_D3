extends MeshInstance3D
## Shows the armed skill's range as a flat disc around the player while
## aiming one (docs/03_combat_system.md "스킬 범위 구조") — without it,
## range/effect_radius were only checked in code with no way to see or test
## them on screen (2026-09-17).
##
## It used to also show the remaining *movement* range whenever it was the
## player's turn; that was removed 2026-09-19 (user decision: no
## reachable-area display — combat movement is a navmesh walk now, so a
## plain circle would be wrong around walls anyway). The file/node keep
## their old name to avoid touching Dungeon.tscn; it's really the skill
## range indicator now.
##
## Visibility is owned by the combat scene script (e.g. Dungeon.gd), which
## toggles `visible` on/off around the player's turn. Within that, this only
## draws anything while a skill is armed.

@export var skill_color: Color = Color(1.0, 0.35, 0.25, 0.35)
@export var y_offset: float = 0.01

var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = skill_color
	material_override = _material

func _process(_delta: float) -> void:
	if not visible:
		return
	var player := GameManager.player
	if player == null or not player.is_aiming():
		mesh = null
		return
	var radius: float = player.equipped_skills[player.pending_skill_index].range
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	mesh = disc
	global_position = Vector3(player.global_position.x, player.global_position.y + y_offset, player.global_position.z)
