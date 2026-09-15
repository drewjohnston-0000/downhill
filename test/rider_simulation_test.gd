extends GdUnitTestSuite
## Unit tests for the pure rider simulation. No scene is loaded — RiderSimulation
## is exercised directly, which is the whole point of keeping sim/ Node-free.

const DT := 1.0 / 60.0


func _make_sim() -> RiderSimulation:
	# Fresh default config per test so tuning changes are caught, not hidden.
	return RiderSimulation.new(RiderConfig.new())


# Advance a state N steps with a fixed input.
func _run(sim: RiderSimulation, state: RiderState, input: RiderInput, steps: int) -> RiderState:
	var s := state
	for _i in steps:
		s = sim.step(s, input, DT)
	return s


func test_gravity_accelerates_along_fall_line() -> void:
	var sim := _make_sim()
	# Facing straight down the fall line, at rest.
	var start := RiderState.new(Vector2.ZERO, Vector2.ZERO, -PI / 2.0)
	var after_1 := sim.step(start, RiderInput.new(), DT)
	var after_30 := _run(sim, start, RiderInput.new(), 30)
	assert_float(after_1.speed()).is_greater(0.0)
	assert_float(after_30.speed()).is_greater(after_1.speed())


func test_steering_rotates_heading() -> void:
	var sim := _make_sim()
	var start := RiderState.new(Vector2.ZERO, Vector2.ZERO, 0.0)
	var right := sim.step(start, RiderInput.new(1.0), DT)
	var left := sim.step(start, RiderInput.new(-1.0), DT)
	assert_float(right.heading).is_greater(0.0)
	assert_float(left.heading).is_less(0.0)


func test_turn_rate_decreases_with_speed_but_never_below_floor() -> void:
	var cfg := RiderConfig.new()
	assert_float(cfg.turn_rate_at(0.0)).is_greater(cfg.turn_rate_at(200.0))
	# Never drops below the responsiveness floor, no matter how fast.
	assert_float(cfg.turn_rate_at(100000.0)).is_greater_equal(cfg.min_turn_rate)
	assert_float(cfg.turn_rate_at(0.0)).is_less_equal(cfg.base_turn_rate)


func test_carving_across_fall_line_scrubs_speed_but_does_not_stall() -> void:
	var sim := _make_sim()
	# A: pointing straight down the fall line (fall line = -Y, so heading = -PI/2).
	var down := RiderState.new(Vector2.ZERO, Vector2.ZERO, -PI / 2.0)
	# B: pointing across the fall line (heading = +X).
	var across := RiderState.new(Vector2.ZERO, Vector2.ZERO, 0.0)
	var down_after := _run(sim, down, RiderInput.new(), 120)
	var across_after := _run(sim, across, RiderInput.new(), 120)
	# Carving across is meaningfully slower than the fall line...
	assert_float(across_after.speed()).is_less(down_after.speed())
	# ...but it never stalls to a stop, and still drifts downhill (no punishment).
	assert_float(across_after.speed()).is_greater(0.0)
	assert_float(across_after.position.y).is_less(0.0)


func test_grip_keeps_travel_close_to_heading() -> void:
	var sim := _make_sim()
	# Heading down the fall line, but initial velocity sideways across it.
	var start := RiderState.new(Vector2.ZERO, Vector2(100.0, 0.0), -PI / 2.0)
	var after := _run(sim, start, RiderInput.new(), 120)
	var heading_dir := Vector2.from_angle(after.heading)
	var angle_off := absf(after.velocity.normalized().angle_to(heading_dir))
	# Velocity should have converged to point along the heading.
	assert_float(angle_off).is_less(0.1)


func test_off_road_is_slower_than_on_road_but_still_moves() -> void:
	var cfg := RiderConfig.new()
	# Straight road along the fall line (-Y), half-width 150.
	var road := RoadPath.new(PackedVector2Array([Vector2(0, 200), Vector2(0, -2000)]), 150.0)
	var sim := RiderSimulation.new(cfg, road)

	# Same start, both heading down the fall line with a little speed.
	var v0 := Vector2.UP * 200.0
	var on_road := RiderState.new(Vector2(0, 100), v0, -PI / 2.0)
	var off_road := RiderState.new(Vector2(400, 100), v0, -PI / 2.0)  # x=400 -> off the road

	var on_after := _run(sim, on_road, RiderInput.new(), 180)
	var off_after := _run(sim, off_road, RiderInput.new(), 180)

	# Grass is meaningfully slower...
	assert_float(off_after.speed()).is_less(on_after.speed())
	# ...but never a crash: the rider keeps rolling and can drive back on.
	assert_float(off_after.speed()).is_greater(0.0)


func test_push_adds_speed_along_heading() -> void:
	var sim := _make_sim()
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 100.0, -PI / 2.0)  # heading & travel = -Y
	var pushed := sim.step(start, RiderInput.new(0.0, false, false, true), DT)
	var coasted := sim.step(start, RiderInput.new(), DT)
	assert_float(pushed.speed()).is_greater(coasted.speed())
	# The extra speed is along the heading (still travelling up the fall line).
	assert_float(pushed.velocity.y).is_less(coasted.velocity.y)  # more negative = faster up-screen


func test_push_is_gated_by_cooldown() -> void:
	var cfg := RiderConfig.new()
	var sim := RiderSimulation.new(cfg)
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 100.0, -PI / 2.0)
	var push_input := RiderInput.new(0.0, false, false, true)

	# First push fires and arms the cooldown.
	var after_first := sim.step(start, push_input, DT)
	assert_float(after_first.push_cooldown).is_greater(0.0)

	# A second push on the very next frame is ignored (still cooling down), so the
	# next-frame speed matches simply coasting from that state.
	var second_push := sim.step(after_first, push_input, DT)
	var coast := sim.step(after_first, RiderInput.new(), DT)
	assert_float(second_push.speed()).is_equal_approx(coast.speed(), 0.001)


func test_push_available_again_after_cooldown() -> void:
	var cfg := RiderConfig.new()
	var sim := RiderSimulation.new(cfg)
	# Start already off cooldown-ready but simulate time passing: hold push and run
	# long enough for at least two pushes to land.
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 100.0, -PI / 2.0)
	var hold := RiderInput.new(0.0, false, false, true)
	var steps := int(ceil((cfg.push_cooldown * 2.5) / DT))
	var held := _run(sim, start, hold, steps)
	var coasted := _run(sim, start, RiderInput.new(), steps)
	# Repeated pushes over time build meaningfully more speed than coasting.
	assert_float(held.speed()).is_greater(coasted.speed() + cfg.push_impulse)


func test_tuck_sustains_higher_speed() -> void:
	var sim := _make_sim()
	# Both head down the fall line from the same speed; one tucks.
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 200.0, -PI / 2.0)
	var tucked := _run(sim, start, RiderInput.new(0.0, false, true), 240)   # tuck = true
	var upright := _run(sim, start, RiderInput.new(0.0, false, false), 240)
	assert_float(tucked.speed()).is_greater(upright.speed())


func test_tuck_reduces_agility() -> void:
	var sim := _make_sim()
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 200.0, 0.0)
	# Same full steer, one tucking: the tucked rider turns less this step.
	var tucked := sim.step(start, RiderInput.new(1.0, false, true), DT)
	var upright := sim.step(start, RiderInput.new(1.0, false, false), DT)
	assert_float(absf(tucked.heading)).is_less(absf(upright.heading))
	# ...but still turns (never fully locked out).
	assert_float(absf(tucked.heading)).is_greater(0.0)


func test_grip_is_constant_by_default() -> void:
	# On-rails default: grip does not change with speed.
	var cfg := RiderConfig.new()
	assert_float(cfg.grip_at(0.0)).is_equal_approx(cfg.grip, 0.001)
	assert_float(cfg.grip_at(500.0)).is_equal_approx(cfg.grip, 0.001)


func test_grip_falloff_mechanism_when_enabled() -> void:
	# The speed-understeer mechanism still works when dialled in explicitly.
	var cfg := RiderConfig.new()
	cfg.grip_speed_falloff = 0.005
	assert_float(cfg.grip_at(0.0)).is_greater(cfg.grip_at(400.0))
	assert_float(cfg.grip_at(100000.0)).is_greater_equal(cfg.grip_min)
	assert_float(cfg.grip_at(0.0)).is_less_equal(cfg.grip)


func test_lean_eases_in_rather_than_snapping() -> void:
	var sim := _make_sim()
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 100.0, -PI / 2.0)  # steer starts at 0
	var after_1 := sim.step(start, RiderInput.new(1.0), DT)
	# One frame of full-right input does not jump straight to full lean...
	assert_float(after_1.steer).is_greater(0.0)
	assert_float(after_1.steer).is_less(1.0)
	# ...but held, it converges toward it.
	var after_1s := _run(sim, start, RiderInput.new(1.0), 60)
	assert_float(after_1s.steer).is_greater(0.9)


func test_faster_riders_change_direction_less() -> void:
	# Speed understeer: carrying more speed washes wider, so the same steering
	# input rotates a fast rider's line less than a slow rider's.
	var sim := _make_sim()
	var slow := RiderState.new(Vector2.ZERO, Vector2.UP * 80.0, -PI / 2.0)
	var fast := RiderState.new(Vector2.ZERO, Vector2.UP * 450.0, -PI / 2.0)
	var steer := RiderInput.new(1.0)
	var slow_after := _run(sim, slow, steer, 20)
	var fast_after := _run(sim, fast, steer, 20)
	var slow_turn := absf(Vector2.UP.angle_to(slow_after.velocity.normalized()))
	var fast_turn := absf(Vector2.UP.angle_to(fast_after.velocity.normalized()))
	assert_float(slow_turn).is_greater(fast_turn)


func test_braking_scrubs_speed_faster_than_coasting() -> void:
	var sim := _make_sim()
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 300.0, -PI / 2.0)
	var braked := _run(sim, start, RiderInput.new(0.0, true), 30)   # brake = true
	var coasted := _run(sim, start, RiderInput.new(0.0, false), 30)
	assert_float(braked.speed()).is_less(coasted.speed())


func test_braking_does_not_reverse_or_go_negative() -> void:
	var sim := _make_sim()
	# Low speed, braking hard for a while: settles near zero, never negative,
	# and never flips to travelling backwards along the heading.
	var start := RiderState.new(Vector2.ZERO, Vector2.UP * 40.0, -PI / 2.0)
	var after := _run(sim, start, RiderInput.new(0.0, true), 120)
	assert_float(after.speed()).is_greater_equal(0.0)
	assert_float(after.speed()).is_less(40.0)
	# Still heading up the fall line (or stopped), not shoved backwards.
	assert_float(after.velocity.dot(Vector2.UP)).is_greater_equal(-0.001)


func test_speed_is_clamped_to_max() -> void:
	var cfg := RiderConfig.new()
	var sim := RiderSimulation.new(cfg)
	# Start absurdly fast; a single step must bring it within the cruising cap.
	var start := RiderState.new(Vector2.ZERO, Vector2(0.0, 10000.0), -PI / 2.0)
	var after := sim.step(start, RiderInput.new(), DT)
	assert_float(after.speed()).is_less_equal(cfg.max_speed + 0.001)
