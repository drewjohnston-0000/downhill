class_name RiderAgent
extends RefCounted
## Owns a RiderSimulation + the evolving RiderState, and the convention for how a
## rider starts (gently rolling down the fall line). Pure logic, no Node — so any
## presentation (2D top-down, 3D chase-cam) drives the same brain the same way:
## read input, call advance(), read state.

var config: RiderConfig
var state: RiderState

var _sim: RiderSimulation


func _init(
	p_config: RiderConfig = null,
	p_road_path: RoadPath = null,
	p_start_position: Vector2 = Vector2.ZERO,
	p_elevation: ElevationProfile = null,
) -> void:
	config = p_config if p_config != null else RiderConfig.new()
	_sim = RiderSimulation.new(config, p_road_path, p_elevation)
	var start_dir := config.fall_line_dir.normalized()
	state = RiderState.new(p_start_position, start_dir * 20.0, start_dir.angle())


## Advance the simulation one step and return the new state.
func advance(input: RiderInput, dt: float) -> RiderState:
	state = _sim.step(state, input, dt)
	return state
