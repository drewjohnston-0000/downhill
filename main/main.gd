extends Node3D
## The game scene: the carving sim rendered chase-cam behind the rider, flat unlit
## colours, no art yet. Builds the world from shared, pure data — a segment course
## (RoadPath) and an elevation profile the sim and Terrain3D both read — plus
## snow-depth posts for readability, a finish gate, and a run timer.

const ROAD_SPACING := 40.0
const ROAD_START_Y := 200.0
const ROAD_HALF_WIDTH := 150.0

# The run as a sequence of segments (length, target lateral slope), giving it
# rhythm: fast straights (tuck earns its keep), sweepers to carry speed through,
# and tight technical corners to brake and set up for. A bend is enter+exit: ramp
# the slope, then bring it back to 0. slope 0 = straight down the fall line.
const COURSE := [
	{"length": 3200.0, "slope": 0.0},    # opening straight — settle in, tuck
	{"length": 1600.0, "slope": 0.55},   # right sweeper (enter)
	{"length": 1600.0, "slope": 0.0},    # (exit)
	{"length": 2600.0, "slope": 0.0},    # straight breather
	{"length": 1300.0, "slope": -0.70},  # chicane left
	{"length": 1300.0, "slope": 0.70},   # chicane right
	{"length": 1300.0, "slope": 0.0},    # (exit)
	{"length": 3200.0, "slope": 0.0},    # long straight — top speed, tuck
	{"length": 1500.0, "slope": -0.85},  # tight left (enter, brake for it)
	{"length": 1500.0, "slope": 0.0},    # (exit)
	{"length": 1300.0, "slope": 0.45},   # gentle right sweeper (enter)
	{"length": 1300.0, "slope": 0.0},    # (exit) — finish straight
]

# Road past the finish line to coast/brake to a stop on (a runout apron), so
# crossing the line at speed doesn't run you off the end of the built ground.
const RUNOUT_LENGTH := 1200.0

# Downhill elevation: a base grade with a gentle roll so the hill has real crests
# (which hide the road ahead) and steep/shallow pitches (which vary speed).
const ELEV_BASE_GRADE := 0.22
const ELEV_ROLL_AMP := 0.12
const ELEV_ROLL_WAVELENGTH := 3000.0


func _ready() -> void:
	var config := RiderConfig.new()

	# The finish is at the end of the race segments; the road continues past it as a
	# runout so you have ground to brake to a stop on after crossing the line.
	var race_length := 0.0
	for seg in COURSE:
		race_length += seg["length"]
	var finish_y: float = ROAD_START_Y - race_length
	var full_course: Array = COURSE + [{"length": RUNOUT_LENGTH, "slope": 0.0}]
	var road_path := RoadPath.build_course(full_course, ROAD_SPACING, ROAD_START_Y, ROAD_HALF_WIDTH)

	# One profile shared by the sim (fall-line pull) and Terrain3D (mesh height).
	var elevation := ElevationProfile.new(ELEV_BASE_GRADE, ELEV_ROLL_AMP, TAU / ELEV_ROLL_WAVELENGTH)
	Terrain3D.profile = elevation

	add_child(_make_sky())

	var road := RoadMesh3D.new()
	road.road_path = road_path
	add_child(road)

	var posts := RoadPosts3D.new()
	posts.road_path = road_path
	add_child(posts)

	var finish := FinishGate3D.new()
	finish.road_path = road_path
	finish.finish_y = finish_y
	add_child(finish)

	var rider := RiderBody3D.new()
	rider.config = config
	rider.road_path = road_path
	rider.elevation = elevation
	rider.start_position = road_path.centerline[0]
	rider.start_at_rest = true  # parked at the top; kick off (skate) to roll
	rider.finish_y = finish_y   # past the line: brake to a graceful stop, no void
	add_child(rider)

	var camera := ChaseCamera3D.new()
	camera.target = rider
	add_child(camera)

	var debug := DebugOverlay.new()
	debug.target = rider
	add_child(debug)

	var hud := RunHud.new()
	hud.target = rider
	hud.timer = RunTimer.new(ROAD_START_Y, finish_y)
	add_child(hud)


# A simple procedural gradient sky (built-in, no art) to give a horizon.
func _make_sky() -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky_mat.sky_top_color = Color(0.30, 0.55, 0.90)
	sky_mat.ground_horizon_color = Color(0.55, 0.70, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	return we
