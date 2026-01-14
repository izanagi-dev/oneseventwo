extends ProjectileMovement
class_name WavyMovement

## Adds a sideways sine-wave component to the projectile's velocity.
##
## Important: this movement stores per-projectile state using metadata
## (so it stays safe when many projectiles share the same definition).

@export var frequency_hz: float = 2.5
@export var lateral_speed_amplitude: float = 220.0

func setup(projectile: Node) -> void:
	if projectile:
		projectile.set_meta("_wavy_t", 0.0)

func update(projectile: Node, delta: float) -> void:
	if projectile == null:
		return

	var v: Variant = projectile.get("velocity")
	if typeof(v) != TYPE_VECTOR2:
		super.update(projectile, delta)
		return

	var velocity: Vector2 = v
	if velocity.length() < 0.001:
		super.update(projectile, delta)
		return

	var t: float = float(projectile.get_meta("_wavy_t", 0.0)) + delta
	projectile.set_meta("_wavy_t", t)

	var along_dir: Vector2 = velocity.normalized()
	var perp: Vector2 = Vector2(-along_dir.y, along_dir.x)
	var osc: float = sin(t * TAU * frequency_hz)
	var new_velocity: Vector2 = along_dir * velocity.length() + perp * osc * lateral_speed_amplitude
	projectile.set("velocity", new_velocity)

	super.update(projectile, delta)
