class_name RiderInput
extends RefCounted
## Pure data describing the player's intent for one simulation step.
##
## Keeping input as a plain value object (rather than reading Godot Input inside
## the simulation) is what lets the sim run headless in unit tests.

## Steering intent, -1 (full left) .. +1 (full right). 0 = straight.
var steer: float = 0.0

## Brake intent. Present so the step() signature is stable; wired up in a
## later milestone.
var brake: bool = false

## Tuck intent (reduced drag). Present but inert for Milestone 1.
var tuck: bool = false

## Skate push intent (space bar): request a forward push this step. Gated by the
## rider's push cooldown, so holding it auto-skates at a steady cadence.
var push: bool = false


func _init(p_steer: float = 0.0, p_brake: bool = false, p_tuck: bool = false, p_push: bool = false) -> void:
	steer = clampf(p_steer, -1.0, 1.0)
	brake = p_brake
	tuck = p_tuck
	push = p_push
