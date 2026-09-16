class_name DebugOverlay
extends CanvasLayer
## On-screen readout of the rider's physics state, for playtesting/tuning. Pure
## presentation and fully optional: it only reads state, never influences it, and
## removing it from the scene changes nothing about gameplay.
##   F3 - show/hide the readout
##   E  - enable/disable auto-telemetry (on by default)
## Telemetry records automatically for every run: it starts when the rider kicks
## off and stops at the finish line, sampling once/sec to the console and its own
## timestamped file logs/physics<timestamp>.jsonl (one JSON object per line;
## Godot-style timestamp so runs never mix). So a whole descent — and only the
## descent — is always captured, with no key-timing to get right.

const LOG_DIR := "res://logs"
const SAMPLE_INTERVAL := 1.0  # seconds between samples while recording
const MOVING_SPEED := 1.0     # speed above which a run is considered under way

## The rider to inspect (exposes `state`, `config`, `road_path`) — RiderBody3D.
var target: Node = null

var _label: Label = null
var _auto_enabled := true   # master switch (E); auto-record runs when on
var _logging := false       # currently writing a run's file
var _run_recorded := false  # this run has already been captured (until scene reload)
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
		_auto_enabled = not _auto_enabled
		if not _auto_enabled and _logging:
			_stop_recording()


func _process(delta: float) -> void:
	if not _ready_to_read():
		return
	_update_auto_recording()
	if _logging:
		_sample_accum += delta
		if _sample_accum >= SAMPLE_INTERVAL:
			_sample_accum -= SAMPLE_INTERVAL
			_write_sample()
	if _label.visible:
		var header := "F3 hide   E telemetry %s" % ("on" if _auto_enabled else "off")
		var lines := PackedStringArray([header])
		if _logging:
			lines.append("● REC  %d samples" % _sample_count)
		lines.append_array(_status_lines(_metrics()))
		_label.text = "\n".join(lines)


# Drive the recording lifecycle from the run: start on kick-off, stop at finish.
func _update_auto_recording() -> void:
	if not _auto_enabled:
		return
	var finished: bool = target.has_method("has_finished") and target.has_finished()
	if not _logging and not _run_recorded and not finished and target.state.speed() > MOVING_SPEED:
		_start_recording()
	elif _logging and finished:
		_stop_recording()
		_run_recorded = true


func _start_recording() -> void:
	_logging = true
	_sample_accum = 0.0
	_sample_count = 0
	# Timestamped filename, colons -> dots, matching Godot's own log naming.
	var stamp := Time.get_datetime_string_from_system().replace(":", ".")
	_log_path = "%s/physics%s.jsonl" % [LOG_DIR, stamp]
	print("[physics] recording started -> %s (every %.0fs)" % [_log_path, SAMPLE_INTERVAL])
	_write_sample()  # capture t0 immediately


func _stop_recording() -> void:
	if not _logging:
		return
	_logging = false
	print("[physics] recording stopped (%d samples) -> %s" % [_sample_count, _log_path])


# Whether the rider and its state are available to read.
func _ready_to_read() -> bool:
	return target != null and target.state != null and target.config != null and _label != null


# Raw metrics snapshot, shared by the on-screen display and the JSON log.
# Callers must ensure _ready_to_read() first.
func _metrics() -> Dictionary:
	var s: RiderState = target.state
	var cfg: RiderConfig = target.config
	var speed := s.speed()
	var tucking := Input.is_action_pressed("tuck")

	# Effective turn rate folds in the tuck penalty; grip is unaffected by tuck.
	var eff_turn := cfg.turn_rate_at(speed)
	if tucking:
		eff_turn *= cfg.tuck_turn_multiplier

	var off := 0.0
	if target.road_path != null:
		off = target.road_path.off_road_amount(s.position)

	return {
		"t": Time.get_ticks_msec() / 1000.0,
		"speed": speed,
		# Heading relative to the fall line: 0 = straight downhill, +right / -left.
		"heading_deg": rad_to_deg(wrapf(s.heading - cfg.fall_line_dir.angle(), -PI, PI)),
		"lean": s.steer,
		"lean_input": Input.get_axis("steer_left", "steer_right"),
		"grip": cfg.grip_at(speed),
		"turn": eff_turn,
		"offroad": off,
		"on_road": off <= 0.0,
		"push_cd": s.push_cooldown,
		"tuck": tucking,
		"skate": Input.is_action_pressed("skate"),
		"brake": Input.is_action_pressed("brake"),
		"x": s.position.x,
		"y": s.position.y,
	}


# Human-readable readout lines built from a metrics dict.
func _status_lines(m: Dictionary) -> PackedStringArray:
	var side := "R" if m["heading_deg"] > 0.5 else ("L" if m["heading_deg"] < -0.5 else "--")
	var turn_note := " (tuck)" if m["tuck"] else ""
	var lines := PackedStringArray()
	lines.append("speed    %6.1f" % m["speed"])
	lines.append("heading  %+6.1f deg %s  (0=downhill)" % [m["heading_deg"], side])
	lines.append("lean     %+.2f  (in %+.1f)" % [m["lean"], m["lean_input"]])
	lines.append("grip     %5.2f   turn %5.2f%s" % [m["grip"], m["turn"], turn_note])
	lines.append("offroad  %5.1f  (%s)" % [m["offroad"], "on road" if m["on_road"] else "OFF"])
	lines.append("push cd  %.2f   tuck %s  skate %s  brake %s" % [
		m["push_cd"], _b(m["tuck"]), _b(m["skate"]), _b(m["brake"]),
	])
	lines.append("pos  (%.0f, %.0f)" % [m["x"], m["y"]])
	return lines


# Append one sample as a JSON object (one line = one record) to file + console.
func _write_sample() -> void:
	if not _ready_to_read() or _log_path == "":
		return
	var line := JSON.stringify(_metrics())
	print("[physics] ", line)
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_log_path) else FileAccess.WRITE
	var f := FileAccess.open(_log_path, mode)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
	_sample_count += 1


func _b(v: bool) -> String:
	return "Y" if v else "-"
