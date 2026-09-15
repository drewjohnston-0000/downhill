extends GdUnitTestSuite
## Unit tests for the pure road geometry / boundary maths.

func _straight_road() -> RoadPath:
	# Vertical centerline along the fall line (-Y), half-width 150.
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, -1000), Vector2(0, -2000)])
	return RoadPath.new(pts, 150.0)


func test_point_on_centerline_is_on_road() -> void:
	var road := _straight_road()
	assert_float(road.off_road_amount(Vector2(0, -500))).is_equal_approx(0.0, 0.001)
	assert_bool(road.is_off_road(Vector2(0, -500))).is_false()


func test_point_within_half_width_is_on_road() -> void:
	var road := _straight_road()
	assert_float(road.off_road_amount(Vector2(100, -500))).is_equal_approx(0.0, 0.001)
	assert_bool(road.is_off_road(Vector2(100, -500))).is_false()


func test_point_beyond_edge_is_off_road_by_the_overshoot() -> void:
	var road := _straight_road()
	assert_float(road.distance_to_center(Vector2(300, -500))).is_equal_approx(300.0, 0.001)
	assert_float(road.off_road_amount(Vector2(300, -500))).is_equal_approx(150.0, 0.001)
	assert_bool(road.is_off_road(Vector2(300, -500))).is_true()


func test_build_s_curve_starts_on_axis_and_samples_the_length() -> void:
	var road := RoadPath.build_s_curve(2000.0, 40.0, 300.0, 1000.0, 200.0, 150.0)
	assert_int(road.centerline.size()).is_greater(1)
	# First sample sits at x=0, y=start_y.
	assert_vector(road.centerline[0]).is_equal_approx(Vector2(0.0, 200.0), Vector2(0.001, 0.001))
	assert_float(road.half_width).is_equal_approx(150.0, 0.001)
