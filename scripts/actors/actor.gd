extends CharacterBody2D
class_name Actor

@export var health_path: NodePath = NodePath("Health")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")

@onready var health: HealthComponent = get_node_or_null(health_path) as HealthComponent
@onready var hurtbox: Hurtbox = get_node_or_null(hurtbox_path) as Hurtbox

var is_dying: bool = false

func _ready() -> void:
	# Auto-wire health signals when present.
	if health:
		if not health.damaged.is_connected(_on_health_damaged):
			health.damaged.connect(_on_health_damaged)
		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)

# Unified combat entry point (Hurtbox -> owner.receive_hit)
func receive_hit(damage_info: DamageInfo, attacker: Node = null) -> void:
	if is_dying:
		return

	# Let subclasses consume/override (e.g., player parry) before health is applied.
	if _filter_hit(damage_info, attacker):
		return

	if health:
		health.apply_hit(damage_info, attacker)
	else:
		# If there's no health component, still allow subclasses to react.
		_on_damaged(damage_info, attacker)

# Return true to consume the hit (no damage applied).
func _filter_hit(_damage_info: DamageInfo, _attacker: Node) -> bool:
	return false

func _on_health_damaged(damage_info: DamageInfo, attacker: Node, _current_health: int, _max_health: int) -> void:
	_on_damaged(damage_info, attacker)

func _on_health_died(damage_info: DamageInfo, attacker: Node) -> void:
	_on_died(damage_info, attacker)

# Override points
func _on_damaged(_damage_info: DamageInfo, _attacker: Node) -> void:
	pass

func _on_died(_damage_info: DamageInfo, _attacker: Node) -> void:
	# Default: mark dying and disable the hurtbox safely.
	# Note: This can be triggered from physics query callbacks, so we use deferred property sets.
	is_dying = true
	if hurtbox:
		hurtbox.enabled = false
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		var hb_shape: CollisionShape2D = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hb_shape:
			hb_shape.set_deferred("disabled", true)

