class_name RiderState
extends RefCounted
## Pure data describing the rider at one instant. No Node, no rendering.
##
## The simulation owns this; presentation reads it. Kept deliberately minimal:
## just what the first movement model needs.

## World position (world units ~ pixels).
var position: Vector2

## World-space velocity (the direction the rider is actually travelling).
var velocity: Vector2

## Angle (radians) the board points. Steering rotates this; grip pulls
## velocity toward it. Not necessarily equal to velocity's direction mid-carve.
var heading: float

## Seconds remaining until the next skate push is allowed (0 = ready).
var push_cooldown: float


func _init(
	p_position: Vector2 = Vector2.ZERO,
	p_velocity: Vector2 = Vector2.ZERO,
	p_heading: float = 0.0,
	p_push_cooldown: float = 0.0,
) -> void:
	position = p_position
	velocity = p_velocity
	heading = p_heading
	push_cooldown = p_push_cooldown


## Current scalar speed (world units / sec).
func speed() -> float:
	return velocity.length()


## A deep copy — used by the simulation to return a new state rather than
## mutating the caller's, keeping step() pure and easy to test.
func duplicate_state() -> RiderState:
	return RiderState.new(position, velocity, heading, push_cooldown)
