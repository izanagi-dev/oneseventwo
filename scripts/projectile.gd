extends Area2D

# Legacy straight-line projectile script kept for older scenes.
# New combat pipeline prefers ProjectileBase + ProjectileDefinition resources.

@export var attack_style: GameEnums.Style = GameEnums.Style.MISSILES
@export var damage: int = 1
@export var camera_shake: float = 0.0
@export var hurtbox_group: StringName = &"player_hurtbox"
@export_group("Tracking Settings")
@export var speed: float = 800.0
@export var steer_force: float = 12.0 # How sharp it can turn
@export var tracking_delay: float = 0.5 # Seconds before it starts homing

var velocity := Vector2.ZERO
var can_track := false


var direction := Vector2.RIGHT
var shooter: Node = null



func _ready() -> void:
    area_entered.connect(_on_area_entered)

func init(dir: Vector2, shooter_node: Node = null) -> void:
    direction = dir.normalized()
    shooter = shooter_node

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
    # Shooter can be freed while a projectile is still alive (death/restart). Guard it.
    var attacker: Node = null
    if shooter != null and is_instance_valid(shooter):
        attacker = shooter
    if attacker != null and area.get_parent() == attacker:
        return
    if hurtbox_group != &"" and not area.is_in_group(hurtbox_group):
        return

    var dmg: DamageInfo = DamageInfo.new()
    dmg.attack_style = attack_style
    dmg.damage = damage
    dmg.camera_shake = camera_shake

    if area.has_method("apply_hit"):
        area.apply_hit(dmg, attacker)
    elif area.get_parent() != null and area.get_parent().has_method("receive_hit"):
        area.get_parent().receive_hit(dmg, attacker)

    queue_free()
