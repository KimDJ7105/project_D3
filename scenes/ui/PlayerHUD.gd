extends CanvasLayer
## Always-visible HP readout (not just during combat) — see
## docs/05_decisions_log.md: HP damage persists between separate fights
## (no auto-heal on victory, only on the placeholder defeat/retreat
## outcome), which is invisible and confusing without this. Simple
## per-frame poll rather than a signal since updating one Label's text is
## negligible cost either way.

@onready var _label: Label = $Label

var _player: Node3D

func bind(player: Node3D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null:
		return
	_label.text = "HP: %d/%d" % [_player.current_hp, _player.stats.vitality]
