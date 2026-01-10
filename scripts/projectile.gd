extends Area2D

@export var speed: float = 900.0
@export var attack_style: GameEnums.Style = GameEnums.Style.MELEE
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Use global_position to ensure it moves in world space, 
	# independent of any parent offsets.
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		# Access the player script (the parent of the hurtbox)
		var player = area.get_parent() 
		if player.has_method("take_damage"):
			player.take_damage(attack_style, damage)
			queue_free() # Destroy projectile on hit