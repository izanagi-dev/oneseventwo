extends Area2D
class_name Hitbox

@export var attack_style: GameEnums.Style = GameEnums.Style.MELEE
@export var damage: int = 1
@export var hitstop_seconds: float = 0.0
@export var knockback: Vector2 = Vector2.ZERO
@export var stun_seconds: float = 0.0

## Optional: only hit Hurtboxes that are in this group. Leave empty to hit any.
@export var hurtbox_group: StringName = &""

## If true, the hitbox will only hit each Hurtbox once until reset_hits() is called.
@export var one_hit_per_target: bool = true

var _hit_ids: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func reset_hits() -> void:
	_hit_ids.clear()

func _build_damage_info() -> DamageInfo:
	var dmg: DamageInfo = DamageInfo.new()
	dmg.attack_style = attack_style
	dmg.damage = damage
	dmg.hitstop_seconds = hitstop_seconds
	dmg.knockback = knockback
	dmg.stun_seconds = stun_seconds
	return dmg

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return

	# Ignore self hits
	if area.get_parent() == get_parent():
		return

	# --- PROJECTILE NULLIFICATION ---
	# Check if the object we hit is a projectile
	if area.is_in_group("projectiles") or area.name.contains("Projectile"):
		# Delete the projectile root node immediately
		area.get_parent().queue_free() 
		
		# Trigger visual feedback (reuse your parry effect)
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("play_parry_effect"):
			player.play_parry_effect()
		return # Stop here so we don't process "damage" on a deleted object
	
	# --- STANDARD DAMAGE LOGIC ---
	if hurtbox_group != &"" and not area.is_in_group(hurtbox_group):
		return

	if one_hit_per_target:
		var id: int = area.get_instance_id()
		if _hit_ids.has(id):
			return
		_hit_ids[id] = true

	var dmg: DamageInfo = _build_damage_info()

	if area.has_method("apply_hit"):
		area.apply_hit(dmg, get_parent())
		return

	var host: Node = area.get_parent()
	if host != null and host.has_method("receive_hit"):
		host.receive_hit(dmg, get_parent())
