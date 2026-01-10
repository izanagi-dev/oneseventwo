# HitboxPlayer.gd
extends Area2D

@onready var player = get_parent()

func _ready():
	area_entered.connect(_on_area_entered)

func _on_area_entered(hitbox):
	if hitbox.has_method("get_damage_type"): # Ensure it's a hitbox
		var incoming_type = hitbox.attack_style
		
		if incoming_type == player.current_style:
			print("PROTECTED! Parrying sound effect...")
			# Logic for deflecting bullets back or knocking enemies back
		else:
			print("DIED! Restarting level...")
			get_tree().reload_current_scene()