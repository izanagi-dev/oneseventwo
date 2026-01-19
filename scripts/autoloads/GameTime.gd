extends Node

## Global time controller for hitstop + slowmo.
## Uses real time (ticks) so it resolves even when time_scale is 0.

var _slowmo_scale: float = 1.0
var _slowmo_until_ms: int = 0

var _hitstop_until_ms: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_time_scale()

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _hitstop_until_ms > 0 and now >= _hitstop_until_ms:
		_hitstop_until_ms = 0
	if _slowmo_until_ms > 0 and now >= _slowmo_until_ms:
		_slowmo_until_ms = 0
		_slowmo_scale = 1.0
	_apply_time_scale()

func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var now: int = Time.get_ticks_msec()
	_hitstop_until_ms = maxi(_hitstop_until_ms, now + int(seconds * 1000.0))
	_apply_time_scale()

func slowmo(scale: float, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_slowmo_scale = clampf(scale, 0.05, 1.0)
	var now: int = Time.get_ticks_msec()
	_slowmo_until_ms = maxi(_slowmo_until_ms, now + int(seconds * 1000.0))
	_apply_time_scale()

func clear() -> void:
	_hitstop_until_ms = 0
	_slowmo_until_ms = 0
	_slowmo_scale = 1.0
	_apply_time_scale()

func _apply_time_scale() -> void:
	if _hitstop_until_ms > 0:
		Engine.time_scale = 0.0
	else:
		Engine.time_scale = _slowmo_scale
