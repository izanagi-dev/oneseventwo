extends Area2D

@export var shake_amount: float = 15.0
@export var restart_delay: float = 0.2
@export var trigger_once: bool = true

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if trigger_once and _triggered:
		return
	# Only react to the player.
	if body == null or not body.is_in_group("player"):
		return
	_triggered = true
	# Prevent repeat triggers while the player is dying.
	set_deferred("monitoring", false)

	# Screen shake (if the active camera supports it).
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(shake_amount)

	# Prefer the player's own death flow (plays animation + uses SceneRouter restart).
	if body.has_method("die"):
		body.call_deferred("die")
		return

	# Next best: use the unified combat pipeline to apply a fatal hit.
	# (This keeps all death behaviour consistent across Actors.)
	if body.has_method("receive_hit"):
		var dmg: DamageInfo = DamageInfo.new()
		dmg.attack_style = GameEnums.Style.NONE
		dmg.damage = 999
		body.call_deferred("receive_hit", dmg, null)
		return

	# Final fallback: just request a restart.
	if restart_delay > 0.0:
		await get_tree().create_timer(restart_delay, true, false, true).timeout
	var events: Node = get_node_or_null("/root/Events")
	if events:
		events.emit_request_restart()
