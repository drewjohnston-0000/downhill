extends Node
## Dev tool: run the game unattended and save frames for capture-driven art work.
##   Godot --path . res://main/capture_harness.tscn
## Env: CAPTURE_NAME (default "cap"), CAPTURE_FRAMES (comma list, default "90,240"),
## CAPTURE_SCENE (default res://main/main.tscn),
## CAPTURE_STEER_AT (frame to start holding steer_left; default 0 = never).
## Frames are saved to res://logs/<name>_<frame>.png (logs/ is gitignored).

var _frame := 0
var _frames: Array[int] = []
var _name := "cap"
var _steer_at := 0


func _ready() -> void:
	_name = OS.get_environment("CAPTURE_NAME")
	if _name.is_empty():
		_name = "cap"
	var spec := OS.get_environment("CAPTURE_FRAMES")
	if spec.is_empty():
		spec = "90,240"
	for part in spec.split(","):
		_frames.append(int(part))
	_steer_at = int(OS.get_environment("CAPTURE_STEER_AT"))
	var scene := OS.get_environment("CAPTURE_SCENE")
	if scene.is_empty():
		scene = "res://main/main.tscn"
	add_child(load(scene).instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 10:
		Input.action_press("skate")
	if _steer_at > 0 and _frame == _steer_at:
		Input.action_press("steer_left")
	if _frame in _frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://logs/%s_%d.png" % [_name, _frame])
	if _frame > _frames.max():
		get_tree().quit()
