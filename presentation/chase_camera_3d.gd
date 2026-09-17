class_name ChaseCamera3D
extends Camera3D
## Follows the rider from behind and above, looking down the road. The behind/ahead
## points set the camera's HORIZONTAL placement, but their heights are ignored:
## both the camera and its look-target are anchored to the rider's OWN elevation,
## with a steady downhill gaze from the hill's average grade. Sampling terrain
## height far ahead/behind instead makes the pitch flail across every roll (the two
## points sit on different parts of the wave) — that reads as motion sickness. Here
## the world rolls underneath while the camera holds a stable line.
##
## Purely presentational: reads the rider's state, never influences it.

@export var distance: float = 190.0 ## how far behind the rider (world units)
@export var height: float = 55.0 ## how far above — near rider height (over-the-shoulder, not a drone)
@export var look_ahead: float = 420.0 ## how far ahead the camera looks (far = near-level gaze into the vista)
@export var look_height: float = 55.0 ## match camera height so we look ALONG the road, not down at it
@export var follow_lerp: float = 5.0 ## horizontal position smoothing
@export var height_lerp: float = 2.0 ## vertical smoothing (slower: filters roll bob)
@export var min_clearance: float = 30.0 ## keep at least this far above the ground beneath the camera

@export var turn_lerp: float = 3.0 ## how fast the aim swings to new headings
## The rider to follow (exposes `state`).
var target: Node = null

var _forward := Vector2.DOWN # smoothed sim-plane forward direction
var _started := false


func _ready() -> void:
	make_current()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var state = target.state
	if state == null:
		return

	# Aim along the TRAVEL direction (velocity), not the board's heading. In a carve
	# the board (heading) angles ~20 deg off the line the rider is actually taking;
	# following velocity keeps the gaze down the road while the deck slips underneath —
	# body faces the vista, board carves beneath it. Fall back to heading when stopped.
	# Aim along TRAVEL (velocity). When stopped — parked at the top, or braked to rest
	# past the finish — velocity has no direction, so FREEZE the last aim rather than
	# snapping to the board's heading: the heading can have drifted far (e.g. during the
	# finish brake), which would swing the view sideways into a level gaze and let the
	# 2D vista/horizon draw over the poles. Seed the aim from the heading on frame one
	# (facing down the hill before the first push).
	var vel: Vector2 = state.velocity
	var moving := vel.length() >= 1.0
	if not _started:
		_forward = vel.normalized() if moving else Vector2(cos(state.heading), sin(state.heading))
		_started = true
	elif moving:
		var travel_dir := vel.normalized()
		_forward = _forward.lerp(travel_dir, clampf(turn_lerp * delta, 0.0, 1.0)).normalized()

	# Horizontal placement comes from the behind/ahead points; their HEIGHTS mostly
	# do not. Sampling terrain height far ahead/behind makes the pitch flail across
	# every roll (the two points sit on different parts of the wave). So the camera
	# rides at the RIDER's elevation + height for stability, but never below the
	# ground beneath it (uphill-behind on a descent) + min_clearance — that floor is
	# what stops it clipping through the hillside. The downhill gaze comes from the
	# hill's average grade, a stable source that ignores local crests.
	var rider_elev := Terrain3D.elevation(state.position)
	var behind := Terrain3D.to_world(state.position - _forward * distance)
	var ahead := Terrain3D.to_world(state.position + _forward * look_ahead)
	var slope_drop := Terrain3D.field.reference_grade() * look_ahead

	var target_y := maxf(rider_elev + height, behind.y + min_clearance)
	var look_pos := Vector3(ahead.x, rider_elev + look_height - slope_drop, ahead.z)

	# Smooth horizontal fast, vertical slow (so crossing rolls doesn't bob the view).
	var gp := global_position
	var t := clampf(follow_lerp * delta, 0.0, 1.0)
	gp.x = lerpf(gp.x, behind.x, t)
	gp.z = lerpf(gp.z, behind.z, t)
	gp.y = lerpf(gp.y, target_y, clampf(height_lerp * delta, 0.0, 1.0))
	global_position = gp
	look_at(look_pos, Vector3.UP)
