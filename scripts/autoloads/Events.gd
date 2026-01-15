extends Node

## Global event bus.
## Use for high-level gameplay events so systems stay decoupled.
##
## NOTE: We provide small wrapper methods that *emit* these signals.
## This avoids Godot's UNUSED_SIGNAL warnings and gives a single place
## to evolve payloads later.

signal player_damaged(current_hp: int, max_hp: int)
signal player_parried()
signal player_died()

signal request_camera_shake(amount: float)

signal request_restart()
signal request_change_scene(scene_path: String)

func emit_player_damaged(current_hp: int, max_hp: int) -> void:
	player_damaged.emit(current_hp, max_hp)

func emit_player_parried() -> void:
	player_parried.emit()

func emit_player_died() -> void:
	player_died.emit()

func emit_request_camera_shake(amount: float) -> void:
	request_camera_shake.emit(amount)

func emit_request_restart() -> void:
	request_restart.emit()

func emit_request_change_scene(scene_path: String) -> void:
	request_change_scene.emit(scene_path)
