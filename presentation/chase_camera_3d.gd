class_name ChaseCamera3D
extends Camera3D
## Follows the rider from behind and above, looking down the road. Both the
## camera position and its look-target are projected through Terrain3D from points
## behind/ahead of the rider in the sim plane, so the camera naturally pitches
## down on descents and up over rises — the elevation does the work.
##
## Purely presentational: reads the rider's state, never influences it.

@export var distance: float = 340.0        ## how far behind the rider (world units)
@export var height: float = 150.0           ## how far above
@export var look_ahead: float = 260.0       ## how far ahead the camera looks
@export var look_height: float = 30.0       ## raise the look target off the road
@export var follow_lerp: float = 5.0        ## position smoothing
@export var turn_lerp: float = 3.0          ## how fast the aim swings to new headings

## The rider to follow (exposes `state`).
var target: Node = null

var _forward := Vector2.DOWN  # smoothed sim-plane forward direction
var _started := false


func _ready() -> void:
	make_current()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var state = target.state
	if state == null:
		return

	# Smooth the forward direction (from heading) to keep the aim steady in carves.
	var heading_dir := Vector2(cos(state.heading), sin(state.heading))
	if not _started:
		_forward = heading_dir
		_started = true
	_forward = _forward.lerp(heading_dir, clampf(turn_lerp * delta, 0.0, 1.0)).normalized()

	var cam_pos := Terrain3D.to_world(state.position - _forward * distance) + Vector3.UP * height
	var look_pos := Terrain3D.to_world(state.position + _forward * look_ahead) + Vector3.UP * look_height

	global_position = global_position.lerp(cam_pos, clampf(follow_lerp * delta, 0.0, 1.0))
	look_at(look_pos, Vector3.UP)
