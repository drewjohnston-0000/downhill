extends GdUnitTestSuite
## Unit tests for gravity from the terrain height field (chapter 1, slice 1).

const DT := 1.0 / 60.0


# The equivalence proof for the gravity model change (chapter 1, slice 1): on a 1-D
# profile the new gradient-driven pull must equal the old fall-line pull EXACTLY:
#   old: velocity += UP * gravity * grade(y) / base_grade * dt
func test_gradient_gravity_equals_the_old_fall_line_pull_exactly() -> void:
	var cfg := RiderConfig.new()
	var profile := ElevationProfile.new(0.22, 0.12, TAU / 3000.0)
	var sim := RiderSimulation.new(cfg, null, profile)
	for y in [0.0, -700.0, -1500.0, -4321.0]:
		var start := RiderState.new(Vector2(12.0, y), Vector2.ZERO, Vector2.UP.angle())
		var next := sim.step(start, RiderInput.new(), DT)
		# One step from rest, facing downhill: gravity, then drag; grip/brake are no-ops.
		var old_pull := cfg.gravity * profile.grade(y) / profile.base_grade
		var expected := Vector2.UP * old_pull * DT * (1.0 - cfg.drag * DT)
		assert_vector(next.velocity).is_equal_approx(expected, Vector2(0.000001, 0.000001))


class TiltedField:
	extends HeightField
	func height_at(pos: Vector2) -> float:
		return 0.3 * pos.x + 0.2 * pos.y
	func reference_grade() -> float:
		return 0.2


func test_gravity_follows_the_terrain_gradient_not_a_fixed_axis() -> void:
	# On a plane tilted sideways as well as down, the pull points down that plane.
	var sim := RiderSimulation.new(RiderConfig.new(), null, TiltedField.new())
	var start := RiderState.new(Vector2.ZERO, Vector2.ZERO, Vector2.UP.angle())
	var next := sim.step(start, RiderInput.new(), DT)
	var downhill := Vector2(-0.3, -0.2).normalized()
	# Grip pulls velocity toward the heading a little within the step, so compare
	# directions loosely: the pull has a clear sideways (-x) component.
	assert_float(next.velocity.x).is_less(0.0)
	assert_float(next.velocity.normalized().dot(downhill)).is_greater(0.9)
