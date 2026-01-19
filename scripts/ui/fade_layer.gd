extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	rect.visible = false

func fade_out(duration: float = 0.12) -> void:
	rect.visible = true
	rect.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, max(duration, 0.01))
	await tween.finished

func fade_in(duration: float = 0.12) -> void:
	rect.visible = true
	rect.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, max(duration, 0.01))
	await tween.finished
	rect.visible = false
