extends CharacterBody2D

# --- CONSTANTS ---
const SPEED := 650.0
const JUMP_VELOCITY := -800.0
const GRAVITY := 2000.0
const DASH_SPEED: float = 1400.0
const DASH_TIME: float = 0.3
const DASH_COOLDOWN: float = 0.15
const ATTACK_TIME := 0.5
const MAX_HEALTH := 3

# --- STATE ---
var is_dashing := false
var can_dash := true
var is_attacking := false
var current_health := MAX_HEALTH
var is_invulnerable := false
var attack_alt := false # Toggle for alternating attacks
var dash_timer: float = 0.0
var dash_dir: int = 1

# --- STYLE SYSTEM ---
var current_style = GameEnums.Style.NONE
@onready var prayer_icon = $Stance

# --- NODES ---
@onready var anim := $Sprite
@onready var hurtbox := $Hurtbox

func _ready() -> void:
	# Add hurtbox to group so projectiles can identify it
	if hurtbox:
		hurtbox.add_to_group("player_hurtbox")

func _input(event):
	if event.is_action_pressed("stance_wind"):
		change_style(GameEnums.Style.MELEE)
	elif event.is_action_pressed("stance_fire"):
		change_style(GameEnums.Style.MISSILES)
	elif event.is_action_pressed("stance_rock"):
		change_style(GameEnums.Style.MAGIC)

func change_style(new_style):
	current_style = new_style
	match new_style:
		GameEnums.Style.MELEE: prayer_icon.modulate = Color.WHITE
		GameEnums.Style.MISSILES: prayer_icon.modulate = Color.RED
		GameEnums.Style.MAGIC: prayer_icon.modulate = Color.SANDY_BROWN

# --- DAMAGE SYSTEM ---
func take_damage(incoming_style: GameEnums.Style, damage_amount: int) -> void:
	if is_invulnerable:
		return
	
	# Debug output
	print("Player current_style: ", current_style)
	print("Incoming projectile style: ", incoming_style)
	print("Are they equal? ", incoming_style == current_style)
	
	# Check if player is protected by matching style
	if incoming_style == current_style:
		print("PROTECTED! Parrying...")
		play_parry_effect()
		# Optional: Could deflect projectile or give player a bonus
		is_invulnerable = true
		await get_tree().create_timer(0.2).timeout
		is_invulnerable = false
	else:
		print("HIT! Taking damage...")
		current_health -= damage_amount
		play_hit_effect()
		
		if current_health <= 0:
			die()
		else:
			# Brief invulnerability after taking damage
			is_invulnerable = true
			await get_tree().create_timer(0.5).timeout
			is_invulnerable = false
func play_parry_effect() -> void:

	# Visual feedback for successful parry

	anim.modulate = Color.LIGHT_GREEN

	await get_tree().create_timer(0.1).timeout

	# Restore color based on current style

	anim.modulate = Color.WHITE
	change_style(current_style)



# --- DAMAGE SYSTEM UPDATES ---

func play_hit_effect() -> void:

	# Play the "take hit" animation

	anim.play("take hit")

	anim.modulate = Color.RED

	await get_tree().create_timer(0.2).timeout

	anim.modulate = Color.WHITE

func die() -> void:
	# Stop movement and play death animation
	set_physics_process(false) # Disable movement
	anim.play("death")
	print("DIED! Restarting level...")
	
	# Wait for animation to finish before reloading (adjust time as needed)
	await get_tree().create_timer(1.0).timeout 
	get_tree().call_deferred("reload_current_scene")

# -------------------------------------------------

func _physics_process(delta):
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


# --- GRAVITY ---
func apply_gravity(delta):
	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta

# --- LEFT / RIGHT ---
func handle_movement():
	if is_dashing:
		return

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	if direction != 0 and not is_attacking:
		anim.flip_h = direction < 0
		
		# --- ADD THESE TWO LINES ---
		# This flips the hitbox's position to match the direction
		$SwordHitbox.scale.x = -1 if direction < 0 else 1

# --- JUMP ---
func handle_jump():
	if is_dashing: # Removed "or is_attacking"
		return

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

# --- DASH ---
func handle_dash():
	if not can_dash or is_dashing or is_attacking:
		return

	if Input.is_action_just_pressed("move_dash"):
		is_dashing = true
		can_dash = false
		dash_timer = 0.0

		if anim.flip_h:
			dash_dir = -1
		else:
			dash_dir = 1


func process_dash(delta: float) -> void:
	dash_timer += delta

	var t: float = dash_timer / DASH_TIME
	t = clamp(t, 0.0, 1.0)

	var current_speed: float = lerpf(DASH_SPEED, SPEED, t)
	velocity.x = dash_dir * current_speed
	velocity.y = 0

	if dash_timer >= DASH_TIME:
		is_dashing = false
		velocity.x = 0.0

		await get_tree().create_timer(DASH_COOLDOWN).timeout
		can_dash = true


# --- ATTACK ---
func handle_attack():
	if is_attacking or is_dashing:
		return

	if Input.is_action_just_pressed("attack"):
		is_attacking = true
		
		# 1. Turn the hitbox ON right when the swing starts
		$SwordHitbox/CollisionShape2D.disabled = false
		
		if attack_alt:
			anim.play("attack 2")
		else:
			anim.play("attack 1")
		
		attack_alt = !attack_alt
		
		# 2. Wait for the duration of the animation
		await get_tree().create_timer(ATTACK_TIME).timeout
		
		# 3. Turn the hitbox OFF so it stops killing things
		$SwordHitbox/CollisionShape2D.disabled = true
		is_attacking = false
		
# --- ANIMATIONS ---
func update_animation():
	# Priority 1: Attacks & Death (handled in their own functions)
	if is_attacking or current_health <= 0:
		return

	# Priority 2: Air State (Jump/Fall)
	if not is_on_floor():
		if velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")
		return

	# Priority 3: Ground State (Idle/Walk)
	if is_dashing:
		# If you don't have a dash animation, "walk" or "jump" usually looks best
		anim.play("fall") 
	elif velocity.x != 0:
		anim.play("walk")
	else:
		anim.play("idle")


func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	# Check if the thing we hit is an enemy
	if area.get_parent().has_method("take_sword_damage"):
		area.get_parent().take_sword_damage()


