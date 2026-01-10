extends Camera2D

@export var player: Node2D

var min_y: float

func _ready() -> void:
	min_y = global_position.y

func _process(_delta: float) -> void:
	if not player:
		return

	var target_pos := player.global_position

	# Follow X always
	global_position.x = target_pos.x

	# Follow Y only if player goes ABOVE the starting height
	if target_pos.y < min_y:
		global_position.y = target_pos.y
	else:
		global_position.y = min_y
