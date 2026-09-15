extends Node3D
## Stage 0 "ugly spike": the same 2D carving sim rendered in 3D, chase-cam behind
## the rider, flat unlit colours, a constant downhill grade (Terrain3D). No art.
## Purpose: feel whether forward-into-the-road-and-vista works before we build
## elevation systems or paint anything. main.tscn (the 2D game) is untouched.

# Same course shape as the 2D game (duplicated for the spike).
const ROAD_LENGTH := 22000.0
const ROAD_SPACING := 40.0
const ROAD_AMPLITUDE := 340.0
const ROAD_WAVELENGTH := 1700.0
const ROAD_START_Y := 200.0
const ROAD_HALF_WIDTH := 150.0

# Downhill elevation: a base grade with a gentle roll so the hill has real crests
# (which hide the road ahead) and steep/shallow pitches (which vary speed).
const ELEV_BASE_GRADE := 0.22
const ELEV_ROLL_AMP := 0.12
const ELEV_ROLL_WAVELENGTH := 3000.0


func _ready() -> void:
	var config := RiderConfig.new()
	var road_path := RoadPath.build_s_curve(
		ROAD_LENGTH, ROAD_SPACING, ROAD_AMPLITUDE, ROAD_WAVELENGTH, ROAD_START_Y, ROAD_HALF_WIDTH
	)

	# One profile shared by the sim (fall-line pull) and Terrain3D (mesh height).
	var elevation := ElevationProfile.new(ELEV_BASE_GRADE, ELEV_ROLL_AMP, TAU / ELEV_ROLL_WAVELENGTH)
	Terrain3D.profile = elevation

	add_child(_make_sky())

	var road := RoadMesh3D.new()
	road.road_path = road_path
	add_child(road)

	var rider := RiderBody3D.new()
	rider.config = config
	rider.road_path = road_path
	rider.elevation = elevation
	rider.start_position = road_path.centerline[0]
	add_child(rider)

	var camera := ChaseCamera3D.new()
	camera.target = rider
	add_child(camera)

	var debug := DebugOverlay.new()
	debug.target = rider
	add_child(debug)


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
