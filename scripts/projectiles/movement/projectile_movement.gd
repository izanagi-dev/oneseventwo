extends Resource
class_name ProjectileMovement

## Base movement behaviour for a projectile.
##
## In `update`, call `projectile._move_with_velocity(delta)` to advance it using
## its current `velocity`.

func setup(_projectile: Node) -> void:
	pass

func update(projectile: Node, delta: float) -> void:
	if projectile == null:
		return
	if projectile.has_method("_move_with_velocity"):
		projectile._move_with_velocity(delta)
		return
	# Fallback (shouldn't be needed if you use ProjectileBase).
	var v: Variant = projectile.get("velocity")
	if typeof(v) == TYPE_VECTOR2:
		projectile.global_position += v * delta
