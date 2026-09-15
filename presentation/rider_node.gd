class_name RiderNode
extends Node2D
## Presentation + input glue for the rider. Owns a RiderSimulation, reads player
## input, advances the sim each physics tick, and mirrors the resulting state
## onto this node's transform. Drawing is placeholder shapes.
##
## Gameplay lives entirely in sim/. This node only translates Input -> RiderInput
## and RiderState -> transform, so the simulation stays testable in isolation.

## Optional injected config; falls back to defaults. Exposed so main.gd (or the
## editor) can tune feel.
var config: RiderConfig = null

## Optional road geometry; when set the sim applies gentle off-road drag.
var road_path: RoadPath = null

## Current simulation state — read by the camera. Public on purpose.
var state: RiderState = null

var _sim: RiderSimulation = null


func _ready() -> void:
	if config == null:
		config = RiderConfig.new()
	_sim = RiderSimulation.new(config, road_path)
	# Start gently rolling down the fall line so the descent begins immediately.
	var start_dir: Vector2 = config.fall_line_dir.normalized()
	state = RiderState.new(global_position, start_dir * 20.0, start_dir.angle())
	_apply_state()


func _physics_process(delta: float) -> void:
	var steer: float = Input.get_axis("steer_left", "steer_right")
	var input := RiderInput.new(steer)
	input.push = Input.is_action_pressed("skate")
	state = _sim.step(state, input, delta)
	_apply_state()
	queue_redraw()


func _apply_state() -> void:
	global_position = state.position
	rotation = state.heading


func _draw() -> void:
	# Board sprite is authored pointing along +X (heading 0); node rotation aims
	# it along the heading.
	var board_color := Color(0.15, 0.16, 0.2)
	var deck_color := Color(0.95, 0.55, 0.2)
	var rider_color := Color(0.2, 0.45, 0.85)

	# Soft ground shadow, offset "downhill-behind" a touch for depth.
	draw_circle(Vector2(-6, 4), 16.0, Color(0, 0, 0, 0.22))

	# Deck (elongated along travel).
	draw_rect(Rect2(-22, -8, 44, 16), deck_color, true)
	# Trucks/board edge.
	draw_rect(Rect2(-24, -9, 48, 18), board_color, false, 2.0)
	# Rider body (a simple wedge leaning into the carve).
	var body := PackedVector2Array([Vector2(-4, -10), Vector2(10, 0), Vector2(-4, 10)])
	draw_colored_polygon(body, rider_color)
	# Head.
	draw_circle(Vector2(2, 0), 5.0, rider_color.lightened(0.15))
