extends Node2D
## Root scene wiring for Milestone 1. Deliberately thin: it builds the road
## geometry, the course renderer, the rider and the camera, and connects them.
## No gameplay logic lives here.

# Milestone-1 course shape (see RoadPath.build_s_curve).
const ROAD_LENGTH := 22000.0
const ROAD_SPACING := 40.0
const ROAD_AMPLITUDE := 340.0
const ROAD_WAVELENGTH := 1700.0
const ROAD_START_Y := 200.0
const ROAD_HALF_WIDTH := 150.0


func _ready() -> void:
	var config := RiderConfig.new()
	var road_path := RoadPath.build_s_curve(
		ROAD_LENGTH, ROAD_SPACING, ROAD_AMPLITUDE, ROAD_WAVELENGTH, ROAD_START_Y, ROAD_HALF_WIDTH
	)

	var course := Course.new()
	course.road_path = road_path
	add_child(course)

	var rider := RiderNode.new()
	rider.config = config
	rider.road_path = road_path
	rider.position = road_path.centerline[0]  # start on the centerline
	add_child(rider)

	var camera := ChaseCamera.new()
	camera.target = rider
	camera.position = rider.position
	add_child(camera)

	# Optional physics readout for playtesting (toggle F3). Remove these two lines
	# to disable — nothing else depends on it.
	var debug := DebugOverlay.new()
	debug.target = rider
	add_child(debug)
