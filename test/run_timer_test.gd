extends GdUnitTestSuite
## Unit tests for the pure RunTimer.

const DT := 1.0 / 60.0


func test_does_not_start_until_the_rider_moves() -> void:
	var t := RunTimer.new(200.0, -1000.0)
	for _i in 30:
		t.update(200.0, DT)  # parked at the start line
	assert_bool(t.running).is_false()
	assert_float(t.elapsed).is_equal_approx(0.0, 0.0001)


func test_starts_and_accumulates_once_moving() -> void:
	var t := RunTimer.new(200.0, -1000.0)
	t.update(150.0, DT)  # moved off the start
	assert_bool(t.running).is_true()
	assert_bool(t.finished).is_false()
	t.update(120.0, DT)
	assert_float(t.elapsed).is_equal_approx(2.0 * DT, 0.0001)


func test_freezes_at_the_finish_line() -> void:
	var t := RunTimer.new(200.0, -1000.0)
	t.update(0.0, DT)          # running
	t.update(-1000.0, DT)      # crosses the finish
	assert_bool(t.finished).is_true()
	var at_finish := t.elapsed
	# Further updates do not add time.
	t.update(-2000.0, DT)
	t.update(-3000.0, DT)
	assert_float(t.elapsed).is_equal_approx(at_finish, 0.0001)
