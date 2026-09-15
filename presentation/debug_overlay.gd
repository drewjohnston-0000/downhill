class_name DebugOverlay
extends CanvasLayer
## On-screen readout of the rider's physics state, for playtesting/tuning. Pure
## presentation and fully optional: it only reads state, never influences it, and
## removing it from the scene changes nothing about gameplay. Toggle with F3.

## The rider to inspect (exposes `state`, `config`, `road_path`).
var target: RiderNode = null

var _label: Label = null


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_label.visible = not _label.visible


func _process(_delta: float) -> void:
	if target == null or _label == null or not _label.visible:
		return
	var s: RiderState = target.state
	if s == null:
		return
	var cfg: RiderConfig = target.config
	var speed := s.speed()

	var lines := PackedStringArray()
	lines.append("F3: toggle debug")
	lines.append("speed    %6.1f" % speed)
	lines.append("heading  %5.1f deg" % fposmod(rad_to_deg(s.heading), 360.0))
	lines.append("lean     %+.2f  (in %+.1f)" % [s.steer, Input.get_axis("steer_left", "steer_right")])
	lines.append("grip     %5.2f   turn %5.2f" % [cfg.grip_at(speed), cfg.turn_rate_at(speed)])
	if target.road_path != null:
		var off := target.road_path.off_road_amount(s.position)
		lines.append("offroad  %5.1f  (%s)" % [off, "OFF" if off > 0.0 else "on road"])
	lines.append("push cd  %.2f   tuck %s  skate %s" % [s.push_cooldown, _yn("tuck"), _yn("skate")])
	lines.append("pos  (%.0f, %.0f)" % [s.position.x, s.position.y])
	_label.text = "\n".join(lines)


func _yn(action: String) -> String:
	return "Y" if Input.is_action_pressed(action) else "-"
