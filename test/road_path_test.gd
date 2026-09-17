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


func test_build_course_straight_segment_stays_on_the_fall_line() -> void:
	# A single slope-0 segment: x never leaves the axis, y descends by the length.
	var road := RoadPath.build_course([{"length": 2000.0, "slope": 0.0}], 40.0, 200.0, 150.0)
	assert_vector(road.centerline[0]).is_equal_approx(Vector2(0.0, 200.0), Vector2(0.001, 0.001))
	for p in road.centerline:
		assert_float(p.x).is_equal_approx(0.0, 0.001)
	var last := road.centerline[road.centerline.size() - 1]
	assert_float(last.y).is_equal_approx(-1800.0, 0.001)  # 200 - 2000


func test_build_course_corner_shifts_laterally_then_a_straight_holds() -> void:
	# Enter a right bend (slope -> +0.6), then a straight (slope back to 0).
	var road := RoadPath.build_course(
		[{"length": 1600.0, "slope": 0.6}, {"length": 1600.0, "slope": 0.0}], 40.0, 0.0, 150.0
	)
	var pts := road.centerline
	var mid := pts[pts.size() / 2]
	var last := pts[pts.size() - 1]
	# The bend pushes x positive during the enter segment...
	assert_float(mid.x).is_greater(50.0)
	# ...and keeps drifting right through the exit (slope stays >= 0, easing to 0),
	# never reversing.
	assert_float(last.x).is_greater(mid.x)
	# Monotonic descent throughout.
	for i in range(pts.size() - 1):
		assert_float(pts[i + 1].y).is_less(pts[i].y)


func test_project_gives_arc_length_lateral_offset_and_interpolated_height() -> void:
	var road := _straight_road()
	road.heights = PackedFloat32Array([400.0, 200.0, 0.0])
	var pr := road.project(Vector2(100.0, -500.0))
	assert_float(pr["s"]).is_equal_approx(500.0, 0.001)
	assert_float(absf(pr["n"])).is_equal_approx(100.0, 0.001)
	assert_float(pr["lateral"]).is_equal_approx(100.0, 0.001)
	assert_float(pr["height"]).is_equal_approx(300.0, 0.001)
	assert_float(pr["camber"]).is_equal_approx(0.0, 0.001)
	# Second segment, and the sign of n flips across the centreline.
	var far := road.project(Vector2(-30.0, -1500.0))
	assert_float(far["s"]).is_equal_approx(1500.0, 0.001)
	assert_float(far["height"]).is_equal_approx(100.0, 0.001)
	assert_float(signf(far["n"])).is_equal_approx(-signf(pr["n"]), 0.001)


func test_assign_profile_sets_descending_heights_and_tilted_plane_camber() -> void:
	var road := RoadPath.build_course(
		[{"length": 1600.0, "slope": 0.6}, {"length": 1600.0, "slope": 0.0}], 40.0, 0.0, 150.0
	)
	var profile := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	road.assign_profile(profile)
	assert_int(road.heights.size()).is_equal(road.centerline.size())
	assert_int(road.cambers.size()).is_equal(road.centerline.size())
	for i in range(road.centerline.size() - 1):
		assert_float(road.heights[i + 1]).is_less_equal(road.heights[i])  # only descends
	# Straight down the fall line the road is level across (no camber)...
	assert_float(road.cambers[0]).is_equal_approx(0.0, 0.001)
	# ...and in the bend, running across the tilted plane, it is cambered.
	assert_float(absf(road.cambers[road.centerline.size() / 2])).is_greater(0.05)
