extends Node
class_name HealthComponent

signal damaged(damage_info: DamageInfo, attacker: Node, current_health: int, max_health: int)
signal died(damage_info: DamageInfo, attacker: Node)

@export var max_health: int = 3
@export var current_health: int = 3

## If > 0, automatically grants invulnerability for this duration after a successful hit.
@export var invulnerability_seconds_on_hit: float = 0.2

var is_invulnerable: bool = false
var is_dead: bool = false

# Used to safely cancel/replace pending invulnerability waits on repeated hits
# and to avoid timer callbacks firing after this node is freed.
var _invuln_token: int = 0

func _ready() -> void:
	# Keep current health sane on load.
	current_health = clampi(current_health, 0, max_health)
	is_dead = current_health <= 0

func reset() -> void:
	current_health = max_health
	_invuln_token += 1
	is_invulnerable = false
	is_dead = false

func set_invulnerable(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_invuln_token += 1
	var token: int = _invuln_token
	is_invulnerable = true
	# Use an awaited timer rather than connecting a callback.
	# This prevents callbacks firing after the node is freed on scene reload.
	# Ignore time scale so invulnerability ends even during hitstop.
	await get_tree().create_timer(seconds, true, false, true).timeout
	if not is_inside_tree():
		return
	if token != _invuln_token:
		return
	is_invulnerable = false

func apply_hit(damage_info: DamageInfo, attacker: Node = null) -> void:
	if is_dead:
		return
	if is_invulnerable:
		return

	var dmg: int = maxi(0, damage_info.damage)
	if dmg <= 0:
		# Still allow tags/knockback systems later without HP loss.
		damaged.emit(damage_info, attacker, current_health, max_health)
		return

	current_health -= dmg
	current_health = maxi(0, current_health)

	# Auto invulnerability after hit (optional).
	if invulnerability_seconds_on_hit > 0.0:
		set_invulnerable(invulnerability_seconds_on_hit)

	damaged.emit(damage_info, attacker, current_health, max_health)

	if current_health <= 0 and not is_dead:
		is_dead = true
		died.emit(damage_info, attacker)
