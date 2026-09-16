extends GdUnitTestSuite
## Unit tests for the shared RiderAgent glue.

const DT := 1.0 / 60.0


func test_agent_starts_rolling_down_the_fall_line() -> void:
	var cfg := RiderConfig.new()
	var agent := RiderAgent.new(cfg, null, Vector2(10.0, 20.0))
	assert_vector(agent.state.position).is_equal_approx(Vector2(10.0, 20.0), Vector2(0.001, 0.001))
	# Begins with some speed along the fall line, not at rest.
	assert_float(agent.state.speed()).is_greater(0.0)
	assert_float(agent.state.velocity.normalized().angle_to(cfg.fall_line_dir.normalized())).is_equal_approx(0.0, 0.001)


func test_agent_advance_updates_and_returns_state() -> void:
	var agent := RiderAgent.new(RiderConfig.new(), null, Vector2.ZERO)
	var returned := agent.advance(RiderInput.new(), DT)
	assert_object(returned).is_same(agent.state)
	# Moved from the origin under gravity.
	assert_bool(agent.state.position.is_equal_approx(Vector2.ZERO)).is_false()


func test_start_at_rest_stays_parked_until_kicked_off() -> void:
	var agent := RiderAgent.new(RiderConfig.new(), null, Vector2(5.0, 5.0), null, true)
	assert_bool(agent.launched).is_false()
	assert_float(agent.state.speed()).is_equal_approx(0.0, 0.0001)
	# No input -> stays put even after many steps (gravity is gated too).
	for _i in 60:
		agent.advance(RiderInput.new(), DT)
	assert_vector(agent.state.position).is_equal_approx(Vector2(5.0, 5.0), Vector2(0.001, 0.001))
	assert_bool(agent.launched).is_false()
	# A skate push kicks it off; from then on it rolls.
	var kick := RiderInput.new()
	kick.push = true
	agent.advance(kick, DT)
	assert_bool(agent.launched).is_true()
	assert_float(agent.state.speed()).is_greater(0.0)
