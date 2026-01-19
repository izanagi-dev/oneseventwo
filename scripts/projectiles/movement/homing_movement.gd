extends ProjectileMovement
class_name HomingMovement

## Turns the projectile toward its target over time.
##
## - `turn_speed_radians_per_sec` controls how quickly it can rotate.
## - If no target is set, it will ask the projectile to acquire one.

@export var turn_speed_radians_per_sec: float = 8.0
@export var max_seek_range: float = 1500.0

func update(projectile: Node, delta: float) -> void:
	if projectile == null:
		return

	var target: Node2D = projectile.get("target")
	if not is_instance_valid(target) and projectile.has_method("acquire_target"):
		target = projectile.acquire_target()
		projectile.set("target", target)

	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - projectile.global_position
		if max_seek_range <= 0.0 or to_target.length() <= max_seek_range:
			var v: Variant = projectile.get("velocity")
			if typeof(v) == TYPE_VECTOR2:
				var velocity: Vector2 = v
				if velocity.length() < 0.001 and projectile.has_method("get_speed"):
					velocity = Vector2.RIGHT * float(projectile.get_speed())

				var current_dir: Vector2 = velocity.normalized()
				var desired_dir: Vector2 = to_target.normalized()
				var angle_to: float = current_dir.angle_to(desired_dir)
				var max_step: float = turn_speed_radians_per_sec * delta
				var step: float = clamp(angle_to, -max_step, max_step)
				var new_dir: Vector2 = current_dir.rotated(step)
				projectile.set("velocity", new_dir * velocity.length())

	super.update(projectile, delta)
