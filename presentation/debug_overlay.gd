class_name DebugOverlay
extends CanvasLayer
## On-screen readout of the rider's physics state, for playtesting/tuning. Pure
## presentation and fully optional: it only reads state, never influences it, and
## removing it from the scene changes nothing about gameplay.
##   F3 - show/hide the readout
##   E  - toggle telemetry recording; each recording samples once/sec to the
##        console and its own timestamped file logs/physics<timestamp>.log
##        (same naming pattern as Godot's own logs, so runs never mix)

const LOG_DIR := "res://logs"
const SAMPLE_INTERVAL := 1.0  # seconds between samples while recording

## The rider to inspect (exposes `state`, `config`, `road_path`).
var target: RiderNode = null

var _label: Label = null
var _logging := false
var _sample_accum := 0.0
var _sample_count := 0
var _log_path := ""  # timestamped file for the current recording


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
		_toggle_recording()


func _process(delta: float) -> void:
	if not _ready_to_read():
		return
	if _logging:
		_sample_accum += delta
		if _sample_accum >= SAMPLE_INTERVAL:
			_sample_accum -= SAMPLE_INTERVAL
			_write_sample()
	if _label.visible:
		var header := "F3 hide   E %s" % ("stop rec" if _logging else "record")
		var lines := PackedStringArray([header])
		if _logging:
			lines.append("● REC  %d samples" % _sample_count)
		lines.append_array(_status_lines())
		_label.text = "\n".join(lines)


func _toggle_recording() -> void:
	_logging = not _logging
	if _logging:
		_sample_accum = 0.0
		_sample_count = 0
		# Timestamped filename, colons -> dots, matching Godot's own log naming.
		var stamp := Time.get_datetime_string_from_system().replace(":", ".")
		_log_path = "%s/physics%s.log" % [LOG_DIR, stamp]
		print("[physics] recording started -> %s (every %.0fs)" % [_log_path, SAMPLE_INTERVAL])
		_write_sample()  # capture t0 immediately
	else:
		print("[physics] recording stopped (%d samples) -> %s" % [_sample_count, _log_path])


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
	lines.append("push cd  %.2f   tuck %s  skate %s  brake %s" % [
		s.push_cooldown, _yn("tuck"), _yn("skate"), _yn("brake"),
	])
	lines.append("pos  (%.0f, %.0f)" % [s.position.x, s.position.y])
	return lines


# Append one timestamped sample to the console and the log file.
func _write_sample() -> void:
	if not _ready_to_read():
		return
	if _log_path == "":
		return
	var entry := "t=%.1fs  %s" % [Time.get_ticks_msec() / 1000.0, "  ".join(_status_lines())]
	print("[physics] ", entry)
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_log_path) else FileAccess.WRITE
	var f := FileAccess.open(_log_path, mode)
	if f != null:
		f.seek_end()
		f.store_line(entry)
		f.close()
	_sample_count += 1


func _yn(action: String) -> String:
	return "Y" if Input.is_action_pressed(action) else "-"
