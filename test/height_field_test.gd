extends GdUnitTestSuite
## Unit tests for the pure terrain height fields.


class PlaneField:
	extends HeightField
	func height_at(pos: Vector2) -> float:
		return 0.3 * pos.x - 0.5 * pos.y + 7.0


class BowlField:
	extends HeightField
	func height_at(pos: Vector2) -> float:
		return 0.001 * (pos.x * pos.x + pos.y * pos.y)


func _straight_road(heights: Array, cambers: Array = []) -> RoadPath:
	var road := RoadPath.new(PackedVector2Array([Vector2(0, 0), Vector2(0, -1000), Vector2(0, -2000)]), 150.0)
	road.heights = PackedFloat32Array(heights)
	if not cambers.is_empty():
		road.cambers = PackedFloat32Array(cambers)
	return road


func test_default_gradient_is_central_difference_exact_on_a_plane() -> void:
	var f := PlaneField.new()
	assert_vector(f.gradient_at(Vector2(10.0, -20.0))).is_equal_approx(Vector2(0.3, -0.5), Vector2(0.0001, 0.0001))
	assert_vector(f.gradient_at(Vector2(-900.0, 3.0))).is_equal_approx(Vector2(0.3, -0.5), Vector2(0.0001, 0.0001))


func test_default_gradient_on_a_bowl_points_away_from_the_centre() -> void:
	var f := BowlField.new()
	assert_vector(f.gradient_at(Vector2(100.0, 0.0))).is_equal_approx(Vector2(0.2, 0.0), Vector2(0.001, 0.001))
	assert_vector(f.gradient_at(Vector2(0.0, -50.0))).is_equal_approx(Vector2(0.0, -0.1), Vector2(0.001, 0.001))


func test_road_field_is_exact_on_the_shelf() -> void:
	var road := _straight_road([400.0, 200.0, 0.0])
	var f := RoadHeightField.new(road, ElevationProfile.new(0.05), 400.0)
	assert_float(f.height_at(Vector2(0.0, -500.0))).is_equal_approx(300.0, 0.001)
	assert_float(f.height_at(Vector2(120.0, -500.0))).is_equal_approx(300.0, 0.001)  # level shelf
	assert_float(f.height_at(Vector2(-149.0, -1250.0))).is_equal_approx(150.0, 0.001)
	# Gradient on the shelf is the road's own grade, straight along the road.
	assert_vector(f.gradient_at(Vector2(60.0, -500.0))).is_equal_approx(Vector2(0.0, 0.2), Vector2(0.001, 0.001))
	assert_float(f.reference_grade()).is_equal_approx(0.2, 0.0001)


func test_camber_tilts_the_shelf_across_the_road() -> void:
	var road := _straight_road([400.0, 200.0, 0.0], [0.1, 0.1, 0.1])
	var f := RoadHeightField.new(road, ElevationProfile.new(0.05), 400.0)
	var left := f.height_at(Vector2(-100.0, -500.0))
	var right := f.height_at(Vector2(100.0, -500.0))
	assert_float(left + right).is_equal_approx(600.0, 0.001)   # centred on the road height
	assert_float(absf(left - right)).is_equal_approx(20.0, 0.001)  # 0.1 per unit across 200
	assert_float(absf(f.gradient_at(Vector2(50.0, -500.0)).x)).is_equal_approx(0.1, 0.001)


func test_cross_section_rises_on_one_side_and_falls_on_the_other() -> void:
	var road := _straight_road([400.0, 200.0, 0.0])
	# A huge blend so the cross-section is read almost undiluted 100 units past the edge.
	var f := RoadHeightField.new(road, ElevationProfile.new(0.05), 100000.0, 0.5, -0.5, 1.0)
	var pr := road.project(Vector2(250.0, -500.0))
	var rise_x := 250.0 if pr["n"] > 0.0 else -250.0
	assert_float(f.height_at(Vector2(rise_x, -500.0))).is_equal_approx(350.0, 0.5)
	assert_float(f.height_at(Vector2(-rise_x, -500.0))).is_equal_approx(250.0, 0.5)


func test_far_from_the_road_the_background_wins() -> void:
	var road := _straight_road([400.0, 200.0, 0.0])
	var base := ElevationProfile.new(0.05)
	var f := RoadHeightField.new(road, base, 400.0)
	var pos := Vector2(5000.0, -500.0)
	assert_float(f.height_at(pos)).is_equal_approx(base.height_at(pos), 0.001)
	assert_vector(f.gradient_at(pos)).is_equal_approx(base.gradient_at(pos), Vector2(0.001, 0.001))


func test_two_tiers_stay_exact_on_their_own_shelves_and_ground_stays_finite_between() -> void:
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(0, -1000), Vector2(0, -2000),
		Vector2(1000, -2000), Vector2(1000, -1000), Vector2(1000, 0),
	])
	var road := RoadPath.new(pts, 150.0)
	road.heights = PackedFloat32Array([900.0, 800.0, 700.0, 600.0, 500.0, 400.0])
	var f := RoadHeightField.new(road, ElevationProfile.new(0.0), 200.0)
	assert_float(f.height_at(Vector2(0.0, -500.0))).is_equal_approx(850.0, 0.001)
	assert_float(f.height_at(Vector2(1000.0, -500.0))).is_equal_approx(450.0, 0.001)
	var between := f.height_at(Vector2(500.0, -500.0))
	assert_float(between).is_between(0.0, 900.0)


func test_baseline_course_as_a_road_field_reproduces_the_profile_on_the_centreline() -> void:
	# The old course, painted onto its tilted-plane profile (tilted-plane camber):
	# on the centreline the road field must give the profile's height AND gradient.
	var profile := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	var road := RoadPath.build_course(
		[{"length": 2000.0, "slope": 0.0}, {"length": 1600.0, "slope": 0.55},
			{"length": 1600.0, "slope": 0.0}, {"length": 1300.0, "slope": -0.7}],
		40.0, 200.0, 150.0
	)
	road.assign_profile(profile)
	var f := RoadHeightField.new(road, profile, 200.0)
	var cl := road.centerline
	for i in range(3, cl.size() - 3, 7):
		var mid := (cl[i] + cl[i + 1]) * 0.5
		# Heights are interpolated linearly between vertices 40 units apart; the roll's
		# curvature makes that differ from the analytic profile by a few hundredths.
		assert_float(f.height_at(mid)).is_equal_approx(profile.height_at(mid), 0.5)
		assert_vector(f.gradient_at(mid)).is_equal_approx(profile.gradient_at(mid), Vector2(0.02, 0.02))
