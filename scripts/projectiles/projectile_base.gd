extends Area2D
class_name ProjectileBase

@export var definition: ProjectileDefinition

@onready var sprite: Sprite2D = $Sprite
@onready var visual_root: Node2D = $VisualRoot
@onready var collision: CollisionShape2D = $Collision

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null
var shooter: Node2D = null

var _remaining_pierce: int = 0
var _visual_instance: Node = null
var _initialised: bool = false
var _lifetime_task_started: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# If initialise() has already been called, we still need signal hookups, but
	# we can skip re-applying the definition.
	if not _initialised:
		_apply_definition()
		_schedule_lifetime()
		_initialised = true

func initialize(defn: ProjectileDefinition, origin: Vector2, dir: Vector2, shooter_node: Node2D = null, target_node: Node2D = null) -> void:
	definition = defn
	global_position = origin
	direction = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	shooter = shooter_node
	target = target_node
	if is_inside_tree():
		_apply_definition()
		_schedule_lifetime()
		_initialised = true

func get_speed() -> float:
	if definition:
		return definition.speed
	return velocity.length()

func acquire_target() -> Node2D:
	if not definition:
		return null
	var group_name: StringName = definition.default_target_group
	if group_name == &"":
		return null
	var nodes: Array = get_tree().get_nodes_in_group(group_name)
	var best: Node2D = null
	var best_dist_sq: float = INF
	for n in nodes:
		var candidate: Node2D = n as Node2D
		if candidate == null:
			continue
		var d_sq: float = global_position.distance_squared_to(candidate.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = candidate
	return best

func _physics_process(delta: float) -> void:
	if not definition:
		_move_with_velocity(delta)
		return
	if definition.movement:
		definition.movement.update(self, delta)
	else:
		_move_with_velocity(delta)
	if definition.rotate_to_velocity and velocity.length() > 0.001:
		rotation = velocity.angle()

func _move_with_velocity(delta: float) -> void:
	global_position += velocity * delta

func _clear_visuals() -> void:
	if _visual_instance != null and is_instance_valid(_visual_instance):
		_visual_instance.queue_free()
	_visual_instance = null

func _apply_definition() -> void:
	if not definition:
		return
	_remaining_pierce = maxi(0, definition.pierce_count)
	velocity = direction * definition.speed
	# Visuals: prefer a visual prefab scene (AnimatedSprite2D, particles, etc.).
	_clear_visuals()
	if definition.visual_scene != null:
		if visual_root:
			_visual_instance = definition.visual_scene.instantiate()
			if _visual_instance:
				visual_root.add_child(_visual_instance)
				# Apply definition modulate to the whole visual.
				visual_root.modulate = definition.modulate
		if sprite:
			sprite.visible = false
	else:
		if sprite:
			sprite.visible = true
			if definition.texture:
				sprite.texture = definition.texture
			sprite.scale = definition.sprite_scale
			sprite.modulate = definition.modulate
		if visual_root:
			visual_root.modulate = Color.WHITE

	if collision and definition.shape:
		collision.shape = definition.shape
	if definition.movement:
		definition.movement.setup(self)

func _schedule_lifetime() -> void:
	if not definition:
		return
	if definition.lifetime_seconds <= 0.0:
		return
	if not is_inside_tree():
		return
	if _lifetime_task_started:
		return
	_lifetime_task_started = true
	await get_tree().create_timer(definition.lifetime_seconds, true, false, true).timeout
	if is_inside_tree():
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not definition:
		queue_free()
		return
	# Shooter can be freed (e.g., enemy dies or scene restarts) while a projectile is still alive.
	# Passing a freed instance into typed functions will error, so guard it.
	var attacker: Node = null
	if shooter != null and is_instance_valid(shooter):
		attacker = shooter

	if attacker != null and area.get_parent() == attacker:
		return
	if definition.hurtbox_group != &"" and area.is_in_group(definition.hurtbox_group):
		# New unified combat pipeline: projectiles build a DamageInfo payload and
		# apply it to the Hurtbox (same as melee Hitbox -> Hurtbox).
		var dmg: DamageInfo = DamageInfo.new()
		dmg.attack_style = definition.attack_style
		dmg.damage = definition.damage
		dmg.hitstop_seconds = definition.hitstop_seconds
		dmg.camera_shake = definition.camera_shake
		dmg.knockback = definition.knockback
		dmg.stun_seconds = definition.stun_seconds
		dmg.tags = definition.tags

		if area.has_method("apply_hit"):
			area.apply_hit(dmg, attacker)
		else:
			# Fallback: if Hurtbox script isn't attached, call receive_hit() on owner if present.
			var victim: Node = area.get_parent()
			if victim != null and victim.has_method("receive_hit"):
				victim.receive_hit(dmg, attacker)

		_consume_hit()

func _consume_hit() -> void:
	if _remaining_pierce <= 0:
		queue_free()
	else:
		_remaining_pierce -= 1
