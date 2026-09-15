class_name ChaseCamera
extends Camera2D
## Follows the rider while communicating speed. Purely presentational — it reads
## the target's position/velocity and never influences the simulation.
##
## All feel constants live here so camera behaviour can be tuned or disabled
## without touching gameplay.

## How far the camera sits ahead of the rider along travel, per unit of speed.
## Higher = you see further ahead the faster you go.
@export var lookahead_per_speed: float = 0.55

## Cap on look-ahead distance (world units) so it never runs away.
@export var max_lookahead: float = 520.0

## Baseline offset keeping the rider in the lower-middle of the screen even at
## rest (world units along the fall line / -Y = up-screen).
@export var base_offset: float = 260.0

## Smoothing rate for position (higher = snappier, lower = more lag).
@export var follow_lerp: float = 4.0

## Extra lateral smoothing so quick carves let the camera trail slightly.
@export var lateral_lerp: float = 3.0

## Subtle zoom-out with speed to reinforce the sense of pace.
@export var zoom_at_rest: float = 1.0
@export var zoom_at_top: float = 0.9
@export var zoom_reference_speed: float = 400.0

## The node to follow. Expected to expose a `state: RiderState` (the rider node).
var target: Node = null


func _ready() -> void:
	make_current()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var state = target.state
	if state == null:
		return

	var vel: Vector2 = state.velocity
	var speed: float = vel.length()
	var travel_dir: Vector2 = vel.normalized() if speed > 1.0 else Vector2.UP

	# Desired camera centre: ahead of the rider along travel, plus a baseline
	# push so the rider rests low on screen.
	var lookahead: float = minf(speed * lookahead_per_speed, max_lookahead)
	var desired: Vector2 = state.position + travel_dir * (base_offset + lookahead)

	# Smooth follow, with a little extra lateral lag for carve feel.
	var next_pos: Vector2 = global_position
	next_pos.y = lerpf(global_position.y, desired.y, clampf(follow_lerp * delta, 0.0, 1.0))
	next_pos.x = lerpf(global_position.x, desired.x, clampf(lateral_lerp * delta, 0.0, 1.0))
	global_position = next_pos

	# Subtle speed-based zoom.
	var t: float = clampf(speed / zoom_reference_speed, 0.0, 1.0)
	var z: float = lerpf(zoom_at_rest, zoom_at_top, t)
	zoom = zoom.lerp(Vector2(z, z), clampf(follow_lerp * delta, 0.0, 1.0))
