class_name ElevationProfile
extends RefCounted
## Pure 1-D downhill profile along the fall-line axis (sim y). The whole hillside
## tilts toward -y; this says how STEEP that tilt is at each point down the slope.
##
##   height(y)      -> world elevation (Terrain3D reads this to build the mesh)
##   grade(y)       -> local steepness dh/dy (kept > 0: no uphill in this stage)
##   pull_factor(y) -> gravity multiplier = grade(y) / base_grade (~1 near the mean)
##
## Because grade varies only with y, the fall line keeps its FIXED direction and
## only its STRENGTH changes: steep pitches accelerate, flat runouts bleed speed.
## Side-to-side camber/banking is a later stage (that needs a 2-D height field).
##
## Model: a base slope plus one gentle sinusoidal roll, so grade and height are
## smooth and have a clean analytic derivative (grade IS dh/dy exactly).
##   height(y) = base_grade * y + (roll_amp / roll_freq) * sin(roll_freq * y)
##   grade(y)  = base_grade + roll_amp * cos(roll_freq * y)

var base_grade: float
var roll_amp: float
var roll_freq: float


func _init(p_base_grade: float = 0.0, p_roll_amp: float = 0.0, p_roll_freq: float = 0.0) -> void:
	base_grade = p_base_grade
	roll_amp = p_roll_amp
	roll_freq = p_roll_freq


## A flat world: no elevation, gravity pull unchanged (pull_factor == 1). The
## default everywhere, so the 2-D game and the existing sim tests are untouched.
static func flat() -> ElevationProfile:
	return ElevationProfile.new()


## World elevation at fall-line position y.
func height(y: float) -> float:
	var roll := 0.0
	if roll_freq != 0.0:
		roll = (roll_amp / roll_freq) * sin(roll_freq * y)
	return base_grade * y + roll


## Local steepness (dh/dy) at y.
func grade(y: float) -> float:
	if roll_freq == 0.0:
		return base_grade
	return base_grade + roll_amp * cos(roll_freq * y)


## Gravity multiplier at y: steeper than the mean pulls harder, flatter pulls less.
## Returns 1.0 for a flat/degenerate profile so gravity is applied unchanged.
func pull_factor(y: float) -> float:
	if base_grade <= 0.0:
		return 1.0
	return grade(y) / base_grade
