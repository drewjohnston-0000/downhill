class_name RunTimer
extends RefCounted
## Pure run clock. Deterministic, Node-free: the presentation feeds it the rider's
## fall-line position and dt each tick. It starts the moment the rider leaves the
## start line (so the parked kick-off doesn't count), accumulates while running,
## and freezes the instant the rider crosses the finish (passes finish_y down the
## fall line). Fall line is -Y, so "further down" means a smaller y.

## How far the rider must move off the start before the clock starts.
const START_EPSILON := 1.0

var start_y: float
var finish_y: float
var elapsed: float = 0.0
var running: bool = false
var finished: bool = false


func _init(p_start_y: float, p_finish_y: float) -> void:
	start_y = p_start_y
	finish_y = p_finish_y


## Advance the clock by dt given the rider's current fall-line position.
func update(position_y: float, dt: float) -> void:
	if finished:
		return
	if not running:
		if position_y <= start_y - START_EPSILON:
			running = true
		else:
			return
	elapsed += dt
	if position_y <= finish_y:
		finished = true
