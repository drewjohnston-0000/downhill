class_name RunHud
extends CanvasLayer
## Always-on run timer across the top of the screen. Owns a pure RunTimer and feeds
## it the rider's fall-line position each physics tick (in lockstep with the sim).
## Before the start it prompts the kick-off; while running it shows the clock; at
## the finish it freezes and announces the time. Presentation only.

var target: Node = null       ## the rider (exposes `state`)
var timer: RunTimer = null

var _label: Label = null


func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0.0, 18.0)
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	_refresh()


func _physics_process(delta: float) -> void:
	if target == null or timer == null:
		return
	var state = target.state
	if state == null:
		return
	timer.update(state.position.y, delta)
	_refresh()


func _refresh() -> void:
	if timer == null:
		return
	if not timer.running:
		_label.text = "skate to start"
	elif timer.finished:
		_label.text = "FINISH   %s" % _format(timer.elapsed)
	else:
		_label.text = _format(timer.elapsed)


# Seconds as m:ss.cc (or just ss.cc under a minute).
static func _format(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := seconds - float(mins * 60)
	if mins > 0:
		return "%d:%05.2f" % [mins, secs]
	return "%.2f" % secs
