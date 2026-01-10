extends CharacterBody2D

@export var speed: float = 300.0
@export var shoot_interval: float = 1.2
@export var target_distance: float = 400.0
@export var stop_threshold: float = 50.0 # Increased for smoother movement
@export var gravity: float = 2000.0

@export var projectile_wind: PackedScene
@export var projectile_fire: PackedScene
@export var projectile_rock: PackedScene

@onready var shoot_point: Marker2D = $ShootPoint
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player: CharacterBody2D = null
var is_attacking := false

func _ready() -> void:
	randomize()
	_shoot_loop()

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

		# Maintain 800px distance
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
	while true:
		await get_tree().create_timer(shoot_interval).timeout
		if player and is_on_floor(): # Only shoot if player found and enemy is grounded
			await shoot_random()

@onready var indicator: Sprite2D = $AttackIndicator

func shoot_random() -> void:
	is_attacking = true
	
	# 1. Determine style and color first
	var scenes = [
		{"scene": projectile_wind, "style": GameEnums.Style.MELEE, "color": Color.WHITE},
		{"scene": projectile_fire, "style": GameEnums.Style.MISSILES, "color": Color.RED},
		{"scene": projectile_rock, "style": GameEnums.Style.MAGIC, "color": Color.SANDY_BROWN}
	]
	var choice = scenes.pick_random()
	
	# 2. Telegraph the attack
	telegraph_attack(choice["color"])
	
	# Wait for the telegraph to finish (sync with your animation)
	var attack_anim = ["attack 1", "attack 2"].pick_random()
	anim.play(attack_anim)
	
	await get_tree().create_timer(0.4).timeout 

	# 3. Spawn the projectile (using your existing logic)
	if choice["scene"]:
		var projectile = choice["scene"].instantiate()
		projectile.attack_style = choice["style"]
		var shoot_dir = (player.global_position - shoot_point.global_position).normalized()
		if "direction" in projectile:
			projectile.direction = shoot_dir
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = shoot_point.global_position

	await get_tree().create_timer(0.3).timeout 
	is_attacking = false

func telegraph_attack(target_color: Color):
	# Set the color but keep it transparent initially
	indicator.modulate = target_color
	indicator.modulate.a = 0
	
	# Create a quick fade-in/fade-out glow effect
	var tween = create_tween()
	# Fade in to 0.8 opacity over 0.2 seconds
	tween.tween_property(indicator, "modulate:a", 0.8, 0.2)
	# Grow the indicator slightly
	tween.parallel().tween_property(indicator, "scale", Vector2(1.5, 1.5), 0.2)
	# Fade out and shrink back right as the projectile fires
	tween.tween_property(indicator, "modulate:a", 0.0, 0.1)
	tween.parallel().tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.1)


func take_sword_damage():
	# You can add a 'health' variable if you want them to take multiple hits
	# For now, let's just make them vanish!
	print("Enemy slain by Ronin!")
	queue_free() # This removes the enemy from the game