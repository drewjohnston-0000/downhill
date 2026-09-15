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
