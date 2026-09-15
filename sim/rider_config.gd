class_name RiderConfig
extends Resource
## Tunable constants for the rider simulation.
##
## This is the single "feel" dial for the prototype. Everything about how
## forgiving / breezy / weighty the board feels lives here so it can be tuned
## in one place (and in the editor, since this is an exported Resource) without
## touching simulation logic.
##
## Units are world units (~pixels for this 2D prototype) and seconds.

## World-space "downhill" direction. Gravity accelerates the rider along this.
## We use -Y (UP the screen) as downhill/forward: in a top-down descent the road
## ahead reads best at the top of the screen with the rider kept low. "Downhill"
## is simply the travel/accel direction; the camera renders it going into the
## distance (upward).
@export var fall_line_dir: Vector2 = Vector2.UP

## Acceleration along the fall line. Higher = builds speed faster.
@export var gravity: float = 60.0

## Absolute safety cap on speed. Set above the passive gravity cruise (~gravity/
## drag) so skating has headroom to sprint into; the passive floaty feel is
## unchanged because gravity/drag settle well below this.
@export var max_speed: float = 600.0

## Fractional velocity loss per second (air/rolling resistance).
## Together with gravity this sets the natural cruising speed on the fall line
## (roughly gravity / drag), here ~400.
@export var drag: float = 0.15

## How strongly the board resists sideways sliding at LOW speed, i.e. how quickly
## velocity snaps to point along the heading. HIGH = planted (the board goes where
## you point). Also what makes carving across the slope gently scrub speed: the
## sideways component of velocity is bled off rather than kept.
@export var grip: float = 6.0

## Grip at high speed (its floor), used only when grip_speed_falloff > 0.
@export var grip_min: float = 2.2

## How quickly grip falls from `grip` toward `grip_min` as speed rises.
## Currently 0 = grip is CONSTANT at all speeds ("on rails": the board holds its
## line whether slow or fast, tucked or not). Raise it (e.g. 0.005) to bring back
## speed-understeer, where fast corners wash wide and you must anticipate.
@export var grip_speed_falloff: float = 0.0

## How fast the applied lean approaches the steering input (per second). Models
## the rider leaning into a carve rather than snapping the board — lower = smoother
## and more deliberate, higher = twitchier.
@export var lean_rate: float = 8.0

## Turn rate (radians/sec) at low speed, before speed falloff.
@export var base_turn_rate: float = 2.8

## How much speed reduces turn rate. SMALL, so turning stays responsive even
## when fast — enough weight to feel committed, not loss of control.
@export var turn_speed_falloff: float = 0.004

## Floor on turn rate (radians/sec) so the board is never unresponsive,
## no matter how fast. This is the "no fear" guarantee for steering.
@export var min_turn_rate: float = 1.4

## Extra fractional velocity loss per second when fully off the road (on grass).
## This is a gentle "get back on the road" nudge, NOT a crash: steering is
## unaffected and the rider never stops dead. Cruising speed on grass settles
## around gravity / (drag + off_road_drag).
@export var off_road_drag: float = 0.8

## Distance (world units) past the road edge over which off_road_drag ramps from
## none to full, so the edge is a soft shoulder rather than a wall.
@export var off_road_ramp: float = 70.0

## Speed (world units/sec) added along the heading by a single skate push.
@export var push_impulse: float = 80.0

## Minimum time (sec) between skate pushes. Gives skating a natural cadence and
## stops it being spammed; holding the key auto-skates at this rhythm.
@export var push_cooldown: float = 0.4

## While tucked, base drag is multiplied by this (lower = faster top end). This
## is the reward for tucking: sustain a higher speed on straights and crests.
@export var tuck_drag_multiplier: float = 0.5

## While tucked, turn rate is multiplied by this (lower = less agile). This is
## the cost of tucking, so it is a real trade-off rather than a free button:
## tuck to go fast in a straight line, stand up to carve. Kept gentle (stays
## above min_turn_rate via turn_rate_at) so it never feels like loss of control.
@export var tuck_turn_multiplier: float = 0.6

## Deceleration (world units/sec^2) applied while braking. A steady, controllable
## scrub you can feather to set up a corner — stronger than gravity so you can
## actually slow on the hill, but far from an instant stop.
@export var brake_decel: float = 300.0


## Turn rate available at the given speed. Decreases slightly with speed but
## never below min_turn_rate.
func turn_rate_at(speed: float) -> float:
	return maxf(min_turn_rate, base_turn_rate / (1.0 + speed * turn_speed_falloff))


## Grip available at the given speed. Falls from `grip` toward `grip_min` as speed
## rises, so fast corners wash wide (understeer) while slow ones stay planted.
func grip_at(speed: float) -> float:
	return maxf(grip_min, grip / (1.0 + speed * grip_speed_falloff))
