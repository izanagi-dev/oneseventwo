extends Resource
class_name ProjectileDefinition

@export var display_name: String = "Projectile"

# Combat
@export var attack_style: GameEnums.Style = GameEnums.Style.MELEE
@export var damage: int = 1

# Extra combat payload (so projectiles share the same DamageInfo pipeline as melee)
@export var hitstop_seconds: float = 0.0
@export var camera_shake: float = 0.0
@export var knockback: Vector2 = Vector2.ZERO
@export var stun_seconds: float = 0.0
@export var tags: Array[StringName] = []

# Movement
@export var speed: float = 700.0
@export var lifetime_seconds: float = 3.0
@export var pierce_count: int = 0 # 0 = destroy on first hit
@export var movement: ProjectileMovement

# Target acquisition (mainly for homing etc.)
@export var default_target_group: StringName = &"player"

# Which hurtboxes this projectile should damage.
# (Current project uses Area2D hurtboxes with groups like "player_hurtbox")
@export var hurtbox_group: StringName = &"player_hurtbox"

# Visuals
@export var visual_scene: PackedScene
@export var texture: Texture2D
@export var sprite_scale: Vector2 = Vector2(0.32, 0.07)
@export var modulate: Color = Color.WHITE
@export var rotate_to_velocity: bool = true

# Collision shape override (optional)
@export var shape: Shape2D
