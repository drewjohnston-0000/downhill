extends Node3D
## The game scene: the carving sim rendered chase-cam behind the rider, in solid
## colours lit by a low sun (no textures yet). Builds the world from shared, pure
## data — a segment course (RoadPath) and an elevation profile the sim and Terrain3D
## both read — plus snow-depth posts for readability, a finish gate, and a run timer.

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
	add_child(_make_sun())

	var road := RoadMesh3D.new()
	road.road_path = road_path
	add_child(road)

	var lines := RoadLines3D.new()
	lines.road_path = road_path
	add_child(lines)

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
	camera.far = 6000.0  # room for the 3D vista backdrop ring (radius ~4000)
	add_child(camera)

	add_child(VistaBackdrop3D.new())
	add_child(CloudLayer2D.new())

	var debug := DebugOverlay.new()
	debug.target = rider
	add_child(debug)

	var hud := RunHud.new()
	hud.target = rider
	hud.timer = RunTimer.new(ROAD_START_Y, finish_y)
	add_child(hud)


# A procedural gradient sky plus atmosphere: soft skylight fill so shadows read
# blue-grey (not black), and depth haze so the far hill fades instead of ending in
# a hard edge. Built-in, no art. Together with the sun this turns the flat diagram
# into a lit place. (Slice A of the painterly skin; see docs/painterly-skin-spec.md.)
func _make_sky() -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	# Golden-hour sky (splash): warm cream/peach at the horizon, soft blue above.
	sky_mat.sky_horizon_color = Color(0.96, 0.90, 0.78)
	sky_mat.sky_top_color = Color(0.40, 0.60, 0.82)
	# Below the horizon is hazy green land (behind the vista ridges), not pale water.
	sky_mat.ground_horizon_color = Color(0.80, 0.83, 0.72)
	sky_mat.ground_bottom_color = Color(0.72, 0.78, 0.64)
	sky_mat.ground_curve = 0.02
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Cool skylight fill so shadowed faces read blue-grey against the warm sun, but
	# soft (the splash is gentle, low-contrast golden hour, not hard cel).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.64, 0.80)
	env.ambient_light_energy = 0.55
	# Layered haze: the far course/hill fades to warm pale, like the splash's
	# receding headlands — the strongest painterly depth cue for flat geometry.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.80, 0.68)  # hazy green so the far ground reads as land
	env.fog_depth_begin = 800.0
	env.fog_depth_end = 14000.0
	env.fog_depth_curve = 0.6
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	return we


# A warm, low directional sun casting shadows — turns flat fill into lit form.
# (Slice A of the painterly skin; see docs/painterly-skin-spec.md.)
func _make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 55.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.74)  # warm low-sun gold
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4000.0
	return sun
