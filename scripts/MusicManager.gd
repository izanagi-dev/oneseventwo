extends Node

# Load your specific track
var start_music = preload("res://assets/audio/music/folk-horn.wav")
var music_player: AudioStreamPlayer

func _ready() -> void:
	# Setup the player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.stream = start_music
	music_player.bus = "Music" # Optional: route to your Music bus
	
	# Play it immediately
	music_player.play()

func stop_music():
	music_player.stop()