extends CanvasLayer

@onready var parry_label: Label = $Label

@export var reset_on_damage: bool = true
@export var reset_on_death: bool = true

var parry_count: int = 0

func _ready() -> void:
	var events: Node = get_node_or_null("/root/Events")
	if events:
		# Parry increments.
		if events.has_signal("player_parried"):
			events.player_parried.connect(_on_player_parried)
		# Optional resets.
		if reset_on_damage and events.has_signal("player_damaged"):
			events.player_damaged.connect(_on_player_damaged)
		if reset_on_death and events.has_signal("player_died"):
			events.player_died.connect(_on_player_died)
		# Also reset when a restart is requested.
		if events.has_signal("request_restart"):
			events.request_restart.connect(_on_request_restart)

	_update_display()

func _on_player_parried() -> void:
	parry_count += 1
	_update_display()
	_pop_effect()

func _on_player_damaged(_current_health: int, _max_health: int) -> void:
	# A hit breaks the combo (Katana Zero-ish feel).
	parry_count = 0
	_update_display()

func _on_player_died() -> void:
	parry_count = 0
	_update_display()

func _on_request_restart() -> void:
	parry_count = 0
	_update_display()

func _update_display() -> void:
	if not parry_label:
		return
	parry_label.text = "Parry Combo: %d" % parry_count

func _pop_effect() -> void:
	if not parry_label:
		return
	# Visual feedback: make the text pop.
	parry_label.pivot_offset = parry_label.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(parry_label, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(parry_label, "scale", Vector2(1.0, 1.0), 0.10)
