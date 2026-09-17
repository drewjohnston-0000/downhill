class_name RiderAgent
extends RefCounted
## Owns a RiderSimulation + the evolving RiderState, and the convention for how a
## rider starts. Pure logic, no Node — so any presentation (2D top-down, 3D
## chase-cam) drives the same brain the same way: read input, call advance(), read
## state.
##
## Start mode: by default the rider begins gently rolling down the fall line. With
## start_at_rest, it begins stationary and stays frozen — gravity and all — until
## the first skate push kicks it off, like stepping onto a parked board.

## Starting speed (world units) when NOT starting at rest.
const ROLL_START_SPEED := 20.0

var config: RiderConfig
var state: RiderState
## Whether the rider is waiting for the first kick before the sim runs.
var launched: bool = true

var _sim: RiderSimulation


func _init(
	p_config: RiderConfig = null,
	p_road_path: RoadPath = null,
	p_start_position: Vector2 = Vector2.ZERO,
	p_field: HeightField = null,
	p_start_at_rest: bool = false,
) -> void:
	config = p_config if p_config != null else RiderConfig.new()
	_sim = RiderSimulation.new(config, p_road_path, p_field)
	# Face downhill at the start: minus the terrain gradient there.
	var grad := _sim.field.gradient_at(p_start_position)
	var start_dir := (-grad).normalized() if grad.length() > 0.0 else Vector2.UP
	var start_speed := 0.0 if p_start_at_rest else ROLL_START_SPEED
	state = RiderState.new(p_start_position, start_dir * start_speed, start_dir.angle())
	launched = not p_start_at_rest


## Advance the simulation one step and return the new state. While waiting to be
## kicked off, the rider stays put (no gravity, no drift) until a skate push
## arrives; that push then flows through the normal step as the first stroke.
func advance(input: RiderInput, dt: float) -> RiderState:
	if not launched:
		if not input.push:
			return state
		launched = true
	state = _sim.step(state, input, dt)
	return state
