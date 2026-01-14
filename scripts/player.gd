extends Actor

# --- CONSTANTS ---
const SPEED: float = 650.0
const JUMP_VELOCITY: float = -800.0
const GRAVITY: float = 2000.0
const DASH_SPEED: float = 1400.0
const DASH_TIME: float = 0.3
const DASH_COOLDOWN: float = 0.15
const ATTACK_TIME: float = 0.5

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

# --- STYLE SYSTEM ---
var current_style: GameEnums.Style = GameEnums.Style.NONE
@onready var prayer_icon: Sprite2D = $Stance

# --- NODES ---
@onready var anim: AnimatedSprite2D = $Sprite

func _has_anim(anim_name: StringName) -> bool:
	if anim == null:
		return false
	var frames: SpriteFrames = anim.sprite_frames
	if frames == null:
		return false
	return frames.has_animation(anim_name)


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

	if is_dashing:
		process_dash(delta)
	else:
		handle_movement()

	handle_jump()
	handle_dash()
	handle_attack()
	update_animation()

	move_and_slide()
	if not was_on_floor_now and is_on_floor():
		_spawn_landing_dust()


# --- GRAVITY ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta

# --- LEFT / RIGHT ---
func handle_movement() -> void:
	if is_dashing:
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	if direction != 0.0 and not is_attacking:
		anim.flip_h = direction < 0.0
		# Flip the hitbox's position to match the direction
		$SwordHitbox.scale.x = -1 if direction < 0.0 else 1

# --- JUMP ---
func handle_jump() -> void:
	if is_dashing:
		return

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

# --- DASH ---
func handle_dash() -> void:
	if not can_dash or is_dashing or is_attacking:
		return

	if Input.is_action_just_pressed("move_dash"):
		is_dashing = true
		can_dash = false
		dash_timer = 0.0
		dash_dir = -1 if anim.flip_h else 1

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
		else:
			anim.play("attack 1")

		attack_alt = !attack_alt

		# Wait for the duration of the animation
		await get_tree().create_timer(ATTACK_TIME).timeout

		# Turn the hitbox OFF
		sword_cs.disabled = true
		is_attacking = false


# --- ANIMATIONS ---
func update_animation() -> void:
	# Priority 1: Attacks & Death (handled in their own functions)
	if is_attacking or is_dying or (health and health.current_health <= 0):
		return

	# Priority 2: Air State (Jump/Fall)
	if not is_on_floor():
		if velocity.y < 0.0:
			anim.play("jump")
		else:
			anim.play("fall")
		return

	# Priority 3: Ground State (Idle/Walk)
	if is_dashing:
		anim.play("fall")
	elif velocity.x != 0.0:
		anim.play("walk")
	else:
		anim.play("idle")