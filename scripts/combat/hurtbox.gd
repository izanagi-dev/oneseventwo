extends Area2D
class_name Hurtbox

## Optional: set to false to temporarily ignore hits (e.g., during death / invulnerability)
@export var enabled: bool = true

func apply_hit(damage_info: DamageInfo, attacker: Node = null) -> void:
	if not enabled:
		return
	var host: Node = get_parent()
	if host == null:
		return

	# Unified pipeline: Hurtbox forwards to its owner's receive_hit()
	if host.has_method("receive_hit"):
		host.receive_hit(damage_info, attacker)
		return

	push_warning("Hurtbox owner has no receive_hit(): %s" % host)
