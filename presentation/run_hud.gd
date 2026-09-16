class_name RunHud
extends CanvasLayer
## Always-on run UI across the top of the screen. Owns a pure RunTimer and feeds it
## the rider's fall-line position each physics tick (in lockstep with the sim).
## Before the start it prompts the kick-off and shows the best time; while running
## it shows the clock; at the finish it records the time, announces it against your
## best, and prompts a restart. Presentation only.

var target: Node = null       ## the rider (exposes `state`)
var timer: RunTimer = null
var best_times: BestTimes = null

var _clock: Label = null
var _sub: Label = null
var _recorded: bool = false
var _new_best: bool = false


func _ready() -> void:
	if best_times == null:
		best_times = BestTimes.new()
	_clock = _make_label(44, 18.0)
	_sub = _make_label(24, 74.0)
	_refresh()


func _physics_process(delta: float) -> void:
	if target == null or timer == null:
		return
	var state = target.state
	if state == null:
		return
	timer.update(state.position.y, delta)

	if timer.finished and not _recorded:
		_recorded = true
		_new_best = best_times.record(timer.elapsed)

	if timer.finished and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	_refresh()


func _refresh() -> void:
	if timer == null:
		return
	if not timer.running:
		_clock.text = "skate to start"
		_sub.text = _best_line()
	elif timer.finished:
		_clock.text = "FINISH   %s" % _format(timer.elapsed)
		if _new_best:
			_sub.text = "NEW BEST!   ·   R to restart"
		else:
			_sub.text = "%s   ·   R to restart" % _best_line()
	else:
		_clock.text = _format(timer.elapsed)
		_sub.text = _best_line()


func _best_line() -> String:
	if best_times != null and best_times.has_any():
		return "best  %s" % _format(best_times.best())
	return ""


func _make_label(font_size: int, y: float) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0.0, y)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


# Seconds as m:ss.cc (or just ss.cc under a minute).
static func _format(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := seconds - float(mins * 60)
	if mins > 0:
		return "%d:%05.2f" % [mins, secs]
	return "%.2f" % secs
