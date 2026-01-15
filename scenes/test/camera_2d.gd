extends Camera2D

@export var player: Node2D

# --- SHAKE SETTINGS ---
var shake_intensity: float = 0.0
@export var shake_fade: float = 10.0 # Higher number means the shake ends faster

# --- FOLLOW SETTINGS ---
var min_y: float

func _ready() -> void:
	randomize()
	# Set the initial Y position as the "floor" for the camera.
	min_y = global_position.y

	# Listen for global camera shake requests (used for player-hit only).
	var events: Node = get_node_or_null("/root/Events")
	if events != null and events.has_signal("request_camera_shake"):
		var cb: Callable = Callable(self, "apply_shake")
		if not events.request_camera_shake.is_connected(cb):
			events.request_camera_shake.connect(cb)

func _process(delta: float) -> void:
	# --- 1. SHAKE LOGIC ---
	if shake_intensity > 0.1:
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		# Smoothly reduce the shake over time.
		shake_intensity = lerp(shake_intensity, 0.0, shake_fade * delta)
	else:
		offset = Vector2.ZERO
		shake_intensity = 0.0

	# --- 2. FOLLOW LOGIC ---
	if not player:
		return

	var target_pos: Vector2 = player.global_position

	# Follow X always.
	global_position.x = target_pos.x

	# Follow Y only if player goes ABOVE the starting height.
	if target_pos.y < min_y:
		global_position.y = target_pos.y
	else:
		global_position.y = min_y

func apply_shake(amount: float) -> void:
	shake_intensity = maxf(shake_intensity, amount)
