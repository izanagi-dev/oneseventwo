extends Node

## Handles scene transitions + the "instant retry" loop.

@export var fade_layer_scene: PackedScene = preload("res://scenes/ui/fade_layer.tscn")

var _fade_layer: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Don't add children to the scene tree while the root is still constructing.
	# We'll defer creation/attachment of the fade layer safely.
	_ensure_fade_layer()
	# Optional event wiring
	var events: Node = get_node_or_null("/root/Events")
	if events:
		events.request_restart.connect(restart_current_scene)
		events.request_change_scene.connect(change_scene)

func _ensure_fade_layer() -> void:
	# If we already have one, keep it.
	if _fade_layer and is_instance_valid(_fade_layer):
		return
	if fade_layer_scene == null:
		return

	# If one exists from a previous run/reload, reuse it.
	var existing: Node = get_tree().root.get_node_or_null("FadeLayer")
	if existing and existing is CanvasLayer:
		_fade_layer = existing
		return

	_fade_layer = fade_layer_scene.instantiate()
	_fade_layer.name = "FadeLayer"
	# Root may still be busy setting up; defer attachment.
	get_tree().root.call_deferred("add_child", _fade_layer)

func _ensure_fade_layer_ready() -> void:
	_ensure_fade_layer()
	if _fade_layer == null:
		return
	# Wait until the deferred add_child runs.
	if not _fade_layer.is_inside_tree():
		await get_tree().process_frame
	# Wait until _ready on the fade layer has run (for onready vars).
	if not _fade_layer.is_node_ready():
		await _fade_layer.ready

func restart_current_scene() -> void:
	await _ensure_fade_layer_ready()
	if _fade_layer and _fade_layer.has_method("fade_out"):
		await _fade_layer.fade_out(0.12)
	# Clear time scale (in case we died during hitstop/slowmo)
	var gt: Node = get_node_or_null("/root/GameTime")
	if gt and gt.has_method("clear"):
		gt.clear()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await _ensure_fade_layer_ready()
	if _fade_layer and _fade_layer.has_method("fade_in"):
		await _fade_layer.fade_in(0.12)

func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	await _ensure_fade_layer_ready()
	if _fade_layer and _fade_layer.has_method("fade_out"):
		await _fade_layer.fade_out(0.12)
	var gt: Node = get_node_or_null("/root/GameTime")
	if gt and gt.has_method("clear"):
		gt.clear()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _ensure_fade_layer_ready()
	if _fade_layer and _fade_layer.has_method("fade_in"):
		await _fade_layer.fade_in(0.12)
