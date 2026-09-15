class_name DebugOverlay
extends CanvasLayer
## On-screen readout of the rider's physics state, for playtesting/tuning. Pure
## presentation and fully optional: it only reads state, never influences it, and
## removing it from the scene changes nothing about gameplay.
##   F3 - show/hide the readout
##   E  - log the current snapshot to the console and user://physics_log.txt

const LOG_PATH := "user://physics_log.txt"

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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F3:
		_label.visible = not _label.visible
	elif event.keycode == KEY_E:
		_log_snapshot()


func _process(_delta: float) -> void:
	if not _ready_to_read() or not _label.visible:
		return
	var lines := PackedStringArray(["F3 hide   E log"])
	lines.append_array(_status_lines())
	_label.text = "\n".join(lines)


# Whether the rider and its state are available to read.
func _ready_to_read() -> bool:
	return target != null and target.state != null and target.config != null and _label != null


# The core readout lines (no key hints), shared by the on-screen display and the
# log. Callers must ensure _ready_to_read() first.
func _status_lines() -> PackedStringArray:
	var s: RiderState = target.state
	var cfg: RiderConfig = target.config
	var speed := s.speed()
	var tucking := Input.is_action_pressed("tuck")

	# Effective turn rate folds in the tuck penalty; grip is unaffected by tuck.
	var eff_turn := cfg.turn_rate_at(speed)
	if tucking:
		eff_turn *= cfg.tuck_turn_multiplier
	var turn_note := " (tuck)" if tucking else ""

	# Heading relative to the fall line: 0 = straight downhill, +right / -left.
	var rel_deg := rad_to_deg(wrapf(s.heading - cfg.fall_line_dir.angle(), -PI, PI))
	var side := "R" if rel_deg > 0.5 else ("L" if rel_deg < -0.5 else "--")

	var lines := PackedStringArray()
	lines.append("speed    %6.1f" % speed)
	lines.append("heading  %+6.1f deg %s  (0=downhill)" % [rel_deg, side])
	lines.append("lean     %+.2f  (in %+.1f)" % [s.steer, Input.get_axis("steer_left", "steer_right")])
	lines.append("grip     %5.2f   turn %5.2f%s" % [cfg.grip_at(speed), eff_turn, turn_note])
	if target.road_path != null:
		var off := target.road_path.off_road_amount(s.position)
		lines.append("offroad  %5.1f  (%s)" % [off, "OFF" if off > 0.0 else "on road"])
	lines.append("push cd  %.2f   tuck %s  skate %s" % [s.push_cooldown, _yn("tuck"), _yn("skate")])
	lines.append("pos  (%.0f, %.0f)" % [s.position.x, s.position.y])
	return lines


# Print a timestamped snapshot to the console and append it to the log file.
func _log_snapshot() -> void:
	if not _ready_to_read():
		return
	var entry := "t=%.1fs  %s" % [Time.get_ticks_msec() / 1000.0, "  ".join(_status_lines())]
	print("[physics] ", entry)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f != null:
		f.seek_end()
		f.store_line(entry)
		f.close()


func _yn(action: String) -> String:
	return "Y" if Input.is_action_pressed(action) else "-"
