class_name RiderSimulation
extends RefCounted
## The rider movement model. Pure logic: given a state, the player's input and a
## timestep, it produces the next state. No Node, no rendering, no global Input,
## no randomness — so it is deterministic and unit-testable without a scene.
##
## Model: "fall-line + grip", tuned forgiving (see RiderConfig).
##   1. Gravity accelerates velocity along a fixed world downhill direction.
##   2. Steering rotates the board's heading (easier at low speed).
##   3. Grip bleeds off the sideways component of velocity so travel tracks the
##      heading. High grip = the board goes where you point (forgiving), and it
##      is what makes carving across the fall line GENTLY scrub speed: the
##      across-slope velocity gravity produces is sideways to a cross-heading,
##      so grip sheds it. Point straight down and nothing is shed -> fast.
##   4. Drag applies, speed is capped at a breezy cruise, position integrates.

var config: RiderConfig

## Optional road geometry. When set, being off the road adds gentle drag.
## Left null in most unit tests (no off-road effect).
var road_path: RoadPath = null


func _init(p_config: RiderConfig = null, p_road_path: RoadPath = null) -> void:
	config = p_config if p_config != null else RiderConfig.new()
	road_path = p_road_path


## Advance the simulation by dt seconds. Returns a NEW state; the input state is
## not mutated.
func step(state: RiderState, input: RiderInput, dt: float) -> RiderState:
	var next := state.duplicate_state()

	# 1. Gravity pulls along the fall line.
	next.velocity += config.fall_line_dir.normalized() * config.gravity * dt

	# 2. Steering rotates the heading. The applied lean eases toward the input
	#    (led-into carves, not twitchy); turn rate uses speed BEFORE this step's
	#    changes so a frame feels consistent and stays above min_turn_rate.
	next.steer = lerpf(state.steer, input.steer, clampf(config.lean_rate * dt, 0.0, 1.0))
	var turn := config.turn_rate_at(state.speed())
	if input.tuck:
		turn *= config.tuck_turn_multiplier  # tucking trades agility for speed
	next.heading = state.heading + next.steer * turn * dt

	var heading_dir := Vector2.from_angle(next.heading)

	# 3. Skate push: an impulse along the heading, gated by a cooldown so pushes
	#    have a natural cadence. Added along the heading so grip preserves it.
	next.push_cooldown = maxf(0.0, state.push_cooldown - dt)
	if input.push and next.push_cooldown <= 0.0:
		next.velocity += heading_dir * config.push_impulse
		next.push_cooldown = config.push_cooldown

	# 4. Grip sheds the sideways component of velocity toward the heading.
	var forward_speed := next.velocity.dot(heading_dir)  # signed speed along heading
	var on_line_velocity := heading_dir * forward_speed  # velocity with sideways removed
	var grip_t := clampf(config.grip_at(state.speed()) * dt, 0.0, 1.0)
	next.velocity = next.velocity.lerp(on_line_velocity, grip_t)

	# 5. Drag (plus gentle off-road drag), speed cap, integrate.
	# Tucking lowers aero drag (higher sustained speed); grass drag is unaffected.
	var base_drag := config.drag
	if input.tuck:
		base_drag *= config.tuck_drag_multiplier
	var drag_rate := base_drag + _off_road_drag_at(state.position)
	next.velocity *= maxf(0.0, 1.0 - drag_rate * dt)
	next.velocity = next.velocity.limit_length(config.max_speed)
	next.position = state.position + next.velocity * dt

	return next


## Extra drag from being off the road, ramped over off_road_ramp so the shoulder
## is soft. Returns 0 when on the road or when no road is set.
func _off_road_drag_at(pos: Vector2) -> float:
	if road_path == null:
		return 0.0
	var off := road_path.off_road_amount(pos)
	if off <= 0.0:
		return 0.0
	var t := clampf(off / config.off_road_ramp, 0.0, 1.0)
	return config.off_road_drag * t
