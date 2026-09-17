class_name ElevationProfile
extends HeightField
## A 1-D downhill profile along the fall-line axis (sim y), as a HeightField: the
## whole hillside tilts toward -y and this says how STEEP that tilt is at each point.
##
##   height(y) -> world elevation;  grade(y) -> steepness dh/dy (kept > 0: no uphill)
##
## Because height varies only with y, the gradient is exactly (0, grade(y)): the fall
## line keeps a fixed direction and only its strength changes. This is the baseline
## course's terrain and the reference the new gradient-driven gravity is proven
## against (see the equivalence tests).
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


## A uniform slope of unit grade: gravity applies unchanged, straight down -y,
## everywhere. The sim's default, so tests without terrain behave as before.
static func uniform() -> ElevationProfile:
	return ElevationProfile.new(1.0)


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


func height_at(pos: Vector2) -> float:
	return height(pos.y)


## Analytic: height depends on y only, so the slope is straight down the fall line.
func gradient_at(pos: Vector2) -> Vector2:
	return Vector2(0.0, grade(pos.y))


func reference_grade() -> float:
	return base_grade if base_grade > 0.0 else 1.0
