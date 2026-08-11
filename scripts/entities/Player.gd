extends Node3D
## Free 8-directional movement on the XZ plane (Y is height/elevation, used
## later for the confirmed cover/elevation combat mechanic — see
## docs/03_combat_system.md).

const SPEED := 4.0

func _process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
	position.x += input_dir.x * SPEED * delta
	position.z += input_dir.y * SPEED * delta
