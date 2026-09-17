class_name HeightField
extends RefCounted
## A pure 2-D height field over the sim plane: the single source of truth for the
## shape of the ground. The sim reads its GRADIENT (gravity pulls downhill, scaled by
## local steepness); presentation reads its HEIGHT (terrain meshes, rider, camera).
## Same object on both sides, so physics and picture can never disagree.
##
## Subclasses override height_at() (and may override gradient_at() with an analytic
## form). The default gradient is a central difference, so any height function is
## usable without deriving anything by hand. No Node, no randomness: unit-testable.

## Step for the central-difference gradient (world units).
const GRADIENT_STEP := 1.0


## Ground height at a sim-plane position.
func height_at(_pos: Vector2) -> float:
	return 0.0


## Slope vector dh/dx, dh/dy at a position. Downhill is -gradient_at(pos).
func gradient_at(pos: Vector2) -> Vector2:
	var dx := Vector2(GRADIENT_STEP, 0.0)
	var dy := Vector2(0.0, GRADIENT_STEP)
	return Vector2(
		(height_at(pos + dx) - height_at(pos - dx)) / (2.0 * GRADIENT_STEP),
		(height_at(pos + dy) - height_at(pos - dy)) / (2.0 * GRADIENT_STEP),
	)


## The course's typical steepness. Gravity is scaled by |gradient| / reference_grade,
## so on ground of this grade the configured gravity applies unchanged; steeper pulls
## harder, flatter pulls less. Always > 0.
func reference_grade() -> float:
	return 1.0
