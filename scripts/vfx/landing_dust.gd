extends GPUParticles2D

func _ready() -> void:
	# Start emitting immediately when spawned
	emitting = true 
	
	# Wait for the duration of the particles (Lifetime)
	# We add a small buffer (like 0.5s) to ensure all particles have faded out
	await get_tree().create_timer(lifetime + 0.5).timeout
	
	# Delete the node from the game
	queue_free()