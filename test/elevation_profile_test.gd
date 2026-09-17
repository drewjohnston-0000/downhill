extends GdUnitTestSuite
## Unit tests for the pure ElevationProfile.


# Downhill pull vector the sim derives from a field: unit strength on reference grade.
func _pull(f: HeightField, pos: Vector2) -> Vector2:
	return -f.gradient_at(pos) / f.reference_grade()


func test_uniform_profile_pulls_straight_down_the_fall_line_unchanged() -> void:
	var p := ElevationProfile.uniform()
	assert_float(p.grade(1234.0)).is_equal_approx(1.0, 0.0001)
	# The sim's default: gravity applied unchanged, straight down -y, everywhere.
	assert_vector(_pull(p, Vector2(0.0, 0.0))).is_equal_approx(Vector2.UP, Vector2(0.0001, 0.0001))
	assert_vector(_pull(p, Vector2(50.0, -900.0))).is_equal_approx(Vector2.UP, Vector2(0.0001, 0.0001))


func test_constant_grade_is_linear_and_neutral_pull() -> void:
	var p := ElevationProfile.new(0.2, 0.0, 0.0)
	assert_float(p.height(100.0)).is_equal_approx(20.0, 0.0001)
	assert_float(p.height(-50.0)).is_equal_approx(-10.0, 0.0001)
	assert_float(p.grade(999.0)).is_equal_approx(0.2, 0.0001)
	assert_float(p.height_at(Vector2(77.0, 100.0))).is_equal_approx(20.0, 0.0001)
	# A constant grade equal to base means no relative pull change anywhere.
	assert_vector(_pull(p, Vector2(3.0, 999.0))).is_equal_approx(Vector2.UP, Vector2(0.0001, 0.0001))


func test_analytic_gradient_matches_central_differences() -> void:
	var p := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	for y in [-2000.0, -500.0, 0.0, 700.0, 1800.0]:
		var pos := Vector2(40.0, y)
		var h := HeightField.GRADIENT_STEP
		var fd := Vector2(
			(p.height_at(pos + Vector2(h, 0)) - p.height_at(pos - Vector2(h, 0))) / (2.0 * h),
			(p.height_at(pos + Vector2(0, h)) - p.height_at(pos - Vector2(0, h))) / (2.0 * h),
		)
		assert_vector(p.gradient_at(pos)).is_equal_approx(fd, Vector2(0.001, 0.001))


func test_grade_is_the_derivative_of_height() -> void:
	var p := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	# Finite-difference the height and compare to the analytic grade.
	for y in [-2000.0, -500.0, 0.0, 700.0, 1800.0]:
		var h := 1.0
		var fd := (p.height(y + h) - p.height(y - h)) / (2.0 * h)
		assert_float(fd).is_equal_approx(p.grade(y), 0.001)


func test_grade_stays_positive_no_uphill() -> void:
	var p := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	for y in range(-4000, 4000, 137):
		assert_float(p.grade(float(y))).is_greater(0.0)


func test_steeper_sections_pull_harder_than_flatter_ones() -> void:
	var freq := TAU / 3000.0
	var p := ElevationProfile.new(0.22, 0.12, freq)
	# cos(freq*y) peaks at y = 0 (steepest) and troughs at y = half wavelength.
	var steep := _pull(p, Vector2(0.0, 0.0)).length()
	var gentle := _pull(p, Vector2(0.0, 1500.0)).length()  # half wavelength -> cos = -1
	assert_float(steep).is_greater(1.0)
	assert_float(gentle).is_less(1.0)
	assert_float(steep).is_greater(gentle)
	# ...and both pull straight down the fall line.
	assert_vector(_pull(p, Vector2(0.0, 0.0)).normalized()).is_equal_approx(Vector2.UP, Vector2(0.0001, 0.0001))
