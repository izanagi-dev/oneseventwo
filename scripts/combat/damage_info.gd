extends Resource
class_name DamageInfo

@export var attack_style: GameEnums.Style = GameEnums.Style.NONE
@export var damage: int = 1
@export var hitstop_seconds: float = 0.0
@export var camera_shake: float = 0.0
@export var knockback: Vector2 = Vector2.ZERO
@export var stun_seconds: float = 0.0
@export var tags: Array[StringName] = []

