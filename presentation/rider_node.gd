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

var _agent: RiderAgent = null

## Presentation-only: whether the rider is tucking this frame (drives the crouch
## visual). Mirrors the last input; the sim is the source of truth for physics.
var _tucking: bool = false


func _ready() -> void:
	if config == null:
		config = RiderConfig.new()
	# Start position was set on this node before it entered the tree.
	_agent = RiderAgent.new(config, road_path, global_position)
	state = _agent.state
	_apply_state()


func _physics_process(delta: float) -> void:
	var steer: float = Input.get_axis("steer_left", "steer_right")
	var input := RiderInput.new(steer)
	input.push = Input.is_action_pressed("skate")
	input.tuck = Input.is_action_pressed("tuck")
	input.brake = Input.is_action_pressed("brake")
	_tucking = input.tuck
	state = _agent.advance(input, delta)
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
	# Rider body: a wedge that flattens and reaches forward when tucking, so the
	# tuck reads at a glance (low and streamlined vs. upright).
	if _tucking:
		var body := PackedVector2Array([Vector2(-6, -6), Vector2(16, 0), Vector2(-6, 6)])
		draw_colored_polygon(body, rider_color)
		draw_circle(Vector2(9, 0), 4.0, rider_color.lightened(0.15))  # head forward, low
	else:
		var body := PackedVector2Array([Vector2(-4, -10), Vector2(10, 0), Vector2(-4, 10)])
		draw_colored_polygon(body, rider_color)
		draw_circle(Vector2(2, 0), 5.0, rider_color.lightened(0.15))
