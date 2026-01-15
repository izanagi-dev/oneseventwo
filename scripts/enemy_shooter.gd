extends Actor

@export var speed: float = 300.0
@export var shoot_interval: float = 1.2
@export var target_distance: float = 400.0
@export var stop_threshold: float = 50.0 # Increased for smoother movement
@export var gravity: float = 2000.0

# Projectile system (data-driven)
@export var projectile_scene: PackedScene
@export var wind_projectile: ProjectileDefinition
@export var fire_projectile: ProjectileDefinition
@export var rock_projectile: ProjectileDefinition
# Optional example: assign a homing definition to enable homing shots
@export var homing_fire_projectile: ProjectileDefinition
@export var homing_rock_projectile: ProjectileDefinition

@onready var shoot_point: Marker2D = $ShootPoint
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var indicator: Sprite2D = $AttackIndicator

var player: CharacterBody2D = null
var is_attacking := false

var _shooting: bool = false

func _ready() -> void:
	super._ready()
	randomize()
	if not _shooting:
		_shooting = true
		_shoot_loop.call_deferred()

func _exit_tree() -> void:
	_shooting = false

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# 2. Safety Check for Player
	if not player:
		player = get_tree().get_first_node_in_group("player")
		velocity.x = 0
		update_animations()
		move_and_slide()
		return

	# 3. Movement Logic (only if not attacking)
	if not is_attacking:
		var vector_to_player = player.global_position - global_position
		var distance = vector_to_player.length()
		var direction_vector = vector_to_player.normalized()

		# Maintain target distance
		if distance > target_distance + stop_threshold:
			velocity.x = direction_vector.x * speed
		elif distance < target_distance - stop_threshold:
			velocity.x = -direction_vector.x * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# 4. Sprite Flipping
	if player:
		anim.flip_h = player.global_position.x < global_position.x
		# Correct shoot point position based on flip
		shoot_point.position.x = abs(shoot_point.position.x) * (-1 if anim.flip_h else 1)

	move_and_slide()
	update_animations()

func update_animations() -> void:
	if is_attacking:
		return

	if abs(velocity.x) > 10:
		anim.play("walk")
	else:
		anim.play("idle")

func _shoot_loop() -> void:
	while _shooting and is_inside_tree() and not is_dying and (health == null or not health.is_dead):
		await get_tree().create_timer(shoot_interval).timeout
		if not _shooting or not is_inside_tree() or is_dying or (health and health.is_dead):
			break
		if player and is_on_floor():
			await shoot_random()

func shoot_random() -> void:
	is_attacking = true

	# Build options list from the definitions you assigned in the inspector.
	var options: Array = []
	if wind_projectile:
		options.append({"def": wind_projectile, "color": Color.WHITE})
	if fire_projectile:
		options.append({"def": fire_projectile, "color": Color.RED})
	if homing_rock_projectile:
		options.append({"def": homing_rock_projectile, "color": Color.SANDY_BROWN})

	if options.is_empty() or projectile_scene == null:
		push_warning("EnemyShooter: projectile_scene or projectile definitions not set.")
		is_attacking = false
		return

	var choice = options.pick_random()
	var defn: ProjectileDefinition = choice["def"]

	# Telegraph the attack
	telegraph_attack(choice["color"])

	# Sync with your animation
	var attack_anim = ["attack 1", "attack 2"].pick_random()
	anim.play(attack_anim)
	await get_tree().create_timer(0.4).timeout

	# Spawn projectile
	var shoot_dir: Vector2 = (player.global_position - shoot_point.global_position).normalized()
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	if projectile.has_method("initialize"):
		projectile.initialize(defn, shoot_point.global_position, shoot_dir, self, player)
	else:
		# Fallback: support old projectile scenes
		projectile.global_position = shoot_point.global_position
		if "attack_style" in projectile:
			projectile.attack_style = defn.attack_style
		if "damage" in projectile:
			projectile.damage = defn.damage
		if "speed" in projectile:
			projectile.speed = defn.speed
		if "direction" in projectile:
			projectile.direction = shoot_dir

	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func telegraph_attack(target_color: Color) -> void:
	indicator.modulate = target_color
	indicator.modulate.a = 0

	var tween = create_tween()
	# Fade in
	tween.tween_property(indicator, "modulate:a", 0.8, 0.2)
	# Grow
	tween.parallel().tween_property(indicator, "scale", Vector2(1.5, 1.5), 0.2)
	# Fade out
	tween.tween_property(indicator, "modulate:a", 0.0, 0.1)
	tween.parallel().tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.1)

func _on_damaged(_damage_info: DamageInfo, _attacker: Node = null) -> void:
	# For now enemies die in one hit, so this usually won't run unless you raise max_health.
	# You can add hit flash / stagger here later.
	pass

func _on_died(damage_info: DamageInfo, attacker: Node = null) -> void:
	super._on_died(damage_info, attacker)
	_shooting = false
	queue_free()

func take_sword_damage() -> void:
	var d: DamageInfo = DamageInfo.new()
	d.attack_style = GameEnums.Style.MELEE
	d.damage = 999
	receive_hit(d, null)
