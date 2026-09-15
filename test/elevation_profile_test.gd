extends GdUnitTestSuite
## Unit tests for the pure ElevationProfile.


func test_flat_profile_is_level_and_neutral() -> void:
	var p := ElevationProfile.flat()
	assert_float(p.height(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(p.height(1234.0)).is_equal_approx(0.0, 0.0001)
	assert_float(p.grade(1234.0)).is_equal_approx(0.0, 0.0001)
	# Flat leaves gravity untouched.
	assert_float(p.pull_factor(1234.0)).is_equal_approx(1.0, 0.0001)


func test_constant_grade_is_linear_and_neutral_pull() -> void:
	var p := ElevationProfile.new(0.2, 0.0, 0.0)
	assert_float(p.height(100.0)).is_equal_approx(20.0, 0.0001)
	assert_float(p.height(-50.0)).is_equal_approx(-10.0, 0.0001)
	assert_float(p.grade(999.0)).is_equal_approx(0.2, 0.0001)
	# A constant grade equal to base means no relative pull change anywhere.
	assert_float(p.pull_factor(999.0)).is_equal_approx(1.0, 0.0001)


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
	var steep := p.pull_factor(0.0)
	var gentle := p.pull_factor(1500.0)  # half wavelength -> cos = -1
	assert_float(steep).is_greater(1.0)
	assert_float(gentle).is_less(1.0)
	assert_float(steep).is_greater(gentle)
