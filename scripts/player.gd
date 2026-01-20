extends Actor

# --- CONSTANTS ---
const SPEED: float = 650.0
const JUMP_VELOCITY: float = -1000.0
const GRAVITY: float = 2000.0
const DASH_SPEED: float = 1400.0
const DASH_TIME: float = 0.3
const DASH_COOLDOWN: float = 0.15
const ATTACK_TIME: float = 0.5

const SLIDE_SPEED := 1700.0
const SLIDE_TIME := 0.8


# Delay before we fade/restart after dying (lets the death animation read).
@export var death_restart_delay: float = 0.35

# Landing VFX (optional). This spawns a one-shot dust puff when transitioning from air -> floor.
@export var landing_dust_scene: PackedScene = preload("res://scenes/vfx/landing_dust.tscn")
@export var landing_dust_offset: Vector2 = Vector2(0, 70)

# --- STATE ---
var is_dashing: bool = false
var can_dash: bool = true
var is_attacking: bool = false
var attack_alt: bool = false # Toggle for alternating attacks
var dash_timer: float = 0.0
var dash_dir: int = 1

var max_jumps = 2
var jump_count = 0

# --- STYLE SYSTEM ---
var current_style: GameEnums.Style = GameEnums.Style.NONE
@onready var prayer_icon: Sprite2D = $Stance

# --- NODES ---
@onready var anim: AnimatedSprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
# --- STATE ---
var is_sliding := false

# --- COYOTE TIME ---
const COYOTE_TIME := 0.15
var coyote_timer := 0.0

# --- JUMP BUFFERING ---
const JUMP_BUFFER_TIME := 0.1
var jump_buffer_timer := 0.0



func _process(_delta):
	# 1. Get the direction from the player to the mouse
	var mouse_pos = get_global_mouse_position()
	
	# 2. Make the pivot point toward that position
	$SwordPivot.look_at(mouse_pos)
	
	# 3. Call the orientation function (You must call it for it to work!)
	update_sword_orientation(mouse_pos)

func update_sword_orientation(mouse_pos):
	# Check if mouse is to the left or right of the player
	if mouse_pos.x < global_position.x:
		# Match '$Sprite' to your screenshot name
		$Sprite.flip_h = true 
		# Access the sprite inside your SwordArea
		if $SwordPivot/SwordArea/Sprite2D:
			$SwordPivot/SwordArea/Sprite2D.flip_v = true
	else:
		$Sprite.flip_h = false
		if $SwordPivot/SwordArea/Sprite2D:
			$SwordPivot/SwordArea/Sprite2D.flip_v = false

func _has_anim(anim_name: StringName) -> bool:
	if anim == null:
		return false
	var frames: SpriteFrames = anim.sprite_frames
	if frames == null:
		return false
	return frames.has_animation(anim_name)

# Ensure this matches your SwordArea's starting X position in the editor
const SWORD_IDLE_X = 40.0 

func thrust_attack():
	is_attacking = true
	
	# Calculate Direction
	var mouse_pos = get_global_mouse_position()
	var mouse_dir = (mouse_pos - global_position).normalized()
	
	# Apply Recoil: 1000 is a good starting point for a noticeable bump
	var recoil_strength = 500.0 
	velocity = -mouse_dir * recoil_strength 
	
	# Sword Animation
	var tween = create_tween()
	# Move sword forward relative to its pivot
	tween.tween_property($SwordPivot/SwordArea, "position:x", 100.0, 0.1)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
		
	# Move sword back
	tween.tween_property($SwordPivot/SwordArea, "position:x", SWORD_IDLE_X, 0.15)\
		.set_trans(Tween.TRANS_SINE)
	
	# Reset state when the sword is back
	tween.finished.connect(func(): is_attacking = false)


func _events() -> Node:
	return get_node_or_null("/root/Events")

func _game_time() -> Node:
	return get_node_or_null("/root/GameTime")

func _ready() -> void:
	super._ready()
	add_to_group("player")
	# Add hurtbox to group so projectiles can identify it
	if hurtbox:
		hurtbox.add_to_group("player_hurtbox")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("stance_wind"):
		change_style(GameEnums.Style.MELEE)
	elif event.is_action_pressed("stance_fire"):
		change_style(GameEnums.Style.MISSILES)
	elif event.is_action_pressed("stance_rock"):
		change_style(GameEnums.Style.MAGIC)
	if event.is_action_pressed("secondary_attack") and not is_attacking:
		thrust_attack()

func change_style(new_style: GameEnums.Style) -> void:
	current_style = new_style
	match new_style:
		GameEnums.Style.MELEE:
			prayer_icon.modulate = Color.WHITE
		GameEnums.Style.MISSILES:
			prayer_icon.modulate = Color.RED
		GameEnums.Style.MAGIC:
			prayer_icon.modulate = Color.SANDY_BROWN
		_:
			prayer_icon.modulate = Color.WHITE

# --- COMBAT FILTER (parry) ---
func _filter_hit(damage_info: DamageInfo, _attacker: Node = null) -> bool:
	# Runs before health is applied. Return true to consume the hit.
	if is_dashing:
		# Optional: ignore hits while dashing (feel). Uncomment if desired.
		# return true
		pass
	if is_dying or (health and health.is_dead):
		return true
	if health and health.is_invulnerable:
		return true

	var incoming_style: GameEnums.Style = damage_info.attack_style

	# Parry when style matches current stance
	if incoming_style == current_style:
		play_parry_effect()

		var gt: Node = _game_time()
		if gt and gt.has_method("hitstop"):
			var hs: float = damage_info.hitstop_seconds if damage_info.hitstop_seconds > 0.0 else 0.03
			gt.hitstop(hs)

		var events: Node = _events()
		if events:
			events.emit_player_parried()

		# Brief invulnerability after a parry
		if health:
			health.set_invulnerable(0.2)
		return true

	return false

func play_parry_effect() -> void:
	# Visual feedback for a successful parry.
	# Keep this resilient: animations may change in the future.
	if not anim:
		return
	# Prefer a dedicated animation if it exists.
	if _has_anim("parry"):
		anim.play("parry")
		return
	if _has_anim("block"):
		anim.play("block")
		return
	# Fallback: quick color flash.
	anim.modulate = Color(0.75, 0.9, 1.0)
	await get_tree().create_timer(0.08, true, false, true).timeout
	if not is_inside_tree() or anim == null:
		return
	if not is_dying:
		anim.modulate = Color.WHITE

func _on_damaged(damage_info: DamageInfo, _attacker: Node = null) -> void:
	# Health has already been reduced at this point.
	# If this hit was lethal, skip the take-hit animation (death handles visuals).
	if health and health.current_health <= 0:
		return

	var gt2: Node = _game_time()
	if gt2 and gt2.has_method("hitstop"):
		var hs2: float = damage_info.hitstop_seconds if damage_info.hitstop_seconds > 0.0 else 0.06
		gt2.hitstop(hs2)

	var events: Node = _events()
	if events:
		events.emit_player_damaged(health.current_health if health else 0, health.max_health if health else 0)

	# Camera shake on PLAYER hit only (not on parry). Value comes from DamageInfo.
	if damage_info.camera_shake > 0.0:
		events.emit_request_camera_shake(damage_info.camera_shake)

	# Play the take-hit feedback
	if _has_anim("take hit"):
		anim.play("take hit")
	anim.modulate = Color.RED
	await get_tree().create_timer(0.2, true, false, true).timeout
	if not is_inside_tree() or anim == null:
		return
	if not is_dying:
		anim.modulate = Color.WHITE

func _on_died(_damage_info: DamageInfo, _attacker: Node = null) -> void:
	die()

func die() -> void:
	# NOTE: Death should always be visually readable.
	# If we died during hitstop/slowmo, clear it so AnimatedSprite2D can advance.
	var gt0: Node = _game_time()
	if gt0 and gt0.has_method("clear"):
		gt0.clear()

	# Stop movement and play death animation
	if is_dying:
		return
	is_dying = true

	# Immediately ignore future hits (logic-level) + safely disable physics monitoring.
	if hurtbox:
		hurtbox.enabled = false
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		var hb_shape: CollisionShape2D = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hb_shape:
			hb_shape.set_deferred("disabled", true)

	# Disable sword hitbox as well (deferred to be safe)
	var sword_shape: CollisionShape2D = get_node_or_null("SwordHitbox/CollisionShape2D") as CollisionShape2D
	if sword_shape:
		sword_shape.set_deferred("disabled", true)

	velocity = Vector2.ZERO
	set_physics_process(false) # Disable movement
	if _has_anim("death"):
		anim.play("death")
		# Ensure at least one rendered frame of the death animation before we start fading.
		await get_tree().process_frame

	var events: Node = _events()
	if events:
		events.emit_player_died()

	# Let the death animation read before we fade/restart.
	var delay: float = maxf(0.0, death_restart_delay)
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout

	# Request restart (guard in case node was freed)
	if is_inside_tree():
		events = _events()
		if events:
			events.emit_request_restart()

func _spawn_landing_dust() -> void:
	if landing_dust_scene == null:
		return
	if not is_inside_tree():
		return
	var dust: Node2D = landing_dust_scene.instantiate() as Node2D
	if dust == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		return
	parent_node.add_child(dust)
	# Place it near the player feet.
	dust.global_position = global_position + landing_dust_offset

func _physics_process(delta: float) -> void:
	var was_on_floor_now: bool = is_on_floor()
	apply_gravity(delta)

	# Update coyote timer
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	
	apply_gravity(delta)

	if is_dashing:
		process_dash(delta)
	else:
		handle_movement()

	handle_jump()
	handle_dash()
	handle_attack()
	handle_slide()

	update_animation()

	move_and_slide()
	if not was_on_floor_now and is_on_floor():
		_spawn_landing_dust()
	# Aim the sword pivot at the mouse cursor

	if is_on_floor():
		jump_count = 0

# --- GRAVITY ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta

# --- LEFT / RIGHT ---
func handle_movement() -> void:
	if is_dashing or is_attacking: # Added 'is_attacking' guard here!
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	if direction != 0.0:
		anim.flip_h = direction < 0.0
		$SwordHitbox.scale.x = -1 if direction < 0.0 else 1

# --- JUMP ---
func handle_jump() -> void:
	if is_dashing:
		return

	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	jump_buffer_timer -= get_physics_process_delta_time()

	if Input.is_action_just_pressed("move_jump"):
		if (is_on_floor() or coyote_timer > 0.0) and jump_count == 0:
			velocity.y = JUMP_VELOCITY
			jump_count += 1
			coyote_timer = 0.0
		elif jump_count < max_jumps:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

# --- DASH ---
func handle_dash() -> void:
	if not can_dash or is_dashing or is_attacking:
		return

	if Input.is_action_just_pressed("move_dash"):
		is_dashing = true
		can_dash = false
		dash_timer = 0.0
		dash_dir = -1 if anim.flip_h else 1

		if not is_on_floor():
			velocity.y = -200.0  # Neutralize vertical velocity when dashing in air

		var dash_sounds = [
			"res://assets/audio/sfx/dash.1.wav",
			"res://assets/audio/sfx/dash.2.wav",
			"res://assets/audio/sfx/dash.3.wav"
		]
		
		var random_dash_sfx = dash_sounds.pick_random()
		play_sfx(random_dash_sfx)


func process_dash(delta: float) -> void:
	dash_timer += delta

	var t: float = dash_timer / DASH_TIME
	t = clampf(t, 0.0, 1.0)

	var current_speed: float = lerpf(DASH_SPEED, SPEED, t)
	velocity.x = float(dash_dir) * current_speed
	velocity.y = 0.0

	if dash_timer >= DASH_TIME:
		is_dashing = false
		velocity.x = 0.0
		await get_tree().create_timer(DASH_COOLDOWN).timeout
		can_dash = true


# --- ATTACK ---
func handle_attack() -> void:
	if is_attacking or is_dashing:
		return

	if Input.is_action_just_pressed("attack"):
		is_attacking = true
		# Reset hit tracking so this swing can hit targets again
		var hb: Node = get_node_or_null("SwordHitbox")
		if hb and hb.has_method("reset_hits"):
			hb.reset_hits()

		# Turn the hitbox ON at swing start
		var sword_cs: CollisionShape2D = $SwordHitbox/CollisionShape2D
		sword_cs.disabled = false

		if attack_alt:
			anim.play("attack 2")
			play_sfx("res://assets/audio/sfx/sword-slash-and-swing-185432.mp3")
		else:
			anim.play("attack 1")
			play_sfx("res://assets/audio/sfx/sword-slash-and-swing-185432.mp3")

		attack_alt = !attack_alt

		# Wait for the duration of the animation
		await get_tree().create_timer(ATTACK_TIME).timeout

		# Turn the hitbox OFF
		sword_cs.disabled = true
		is_attacking = false


# --- ANIMATIONS ---
func update_animation():
	# If any of these are true, don't let walk/idle animations play
	if is_sliding or is_attacking or health.current_health <= 0: 
		return

	if not is_on_floor():
		anim.play("jump" if velocity.y < 0 else "fall")
	elif is_dashing:
		anim.play("fall")
	elif velocity.x != 0:
		anim.play("walk")
	else:
		anim.play("idle")

	# Priority 3: Ground State (Idle/Walk)
	if is_dashing:
		anim.play("fall")
	elif velocity.x != 0.0:
		anim.play("walk")
	else:
		anim.play("idle")


func handle_slide():
	if is_on_floor() and Input.is_action_just_pressed("move_slide") and not is_sliding:
		print("slide")
		is_sliding = true
		anim.play("move_slide")
		collision_shape.position.y = 40  # Reduce height for sliding
		collision_shape.scale.y = 0.7
		
		# Set slide direction based on facing
		var slide_dir = -1 if anim.flip_h else 1
		velocity.x = slide_dir * SLIDE_SPEED
		
		await get_tree().create_timer(SLIDE_TIME).timeout
		is_sliding = false
		collision_shape.position.y = 21
		collision_shape.scale.y = 1.0

		# Maintain some momentum after slide
		velocity.x = slide_dir * SPEED * 0.6

func play_sfx(sound_path: String):
	var p = AudioStreamPlayer.new()
	p.stream = load(sound_path)
	p.bus = "SFX" # This links back to your default_bus_layout.tres
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free) # Deletes the node when sound ends to save memory
