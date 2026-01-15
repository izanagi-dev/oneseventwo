extends Node

## Lightweight session state.

var death_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var events: Node = get_node_or_null("/root/Events")
	if events:
		events.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	death_count += 1
