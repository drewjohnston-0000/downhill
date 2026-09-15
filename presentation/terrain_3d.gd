class_name Terrain3D
extends RefCounted
## The single source of truth for mapping the simulation's 2D plane into the 3D
## world. The sim plane (x, y) becomes the ground; a height comes from the
## elevation profile. Every 3D node (road mesh, rider, camera) projects through
## here so they always agree.
##
## Stage 0: a constant downhill grade (the whole road tips down at a fixed slope).
## Stage 1 will replace `elevation()` with a real profile that varies along the
## course — and, because everything routes through here, that's the only change.

## Downhill grade: world-Y drops by GRADE per unit travelled along the fall line.
const GRADE := 0.2


## Ground height (world Y) at a point in the sim plane.
static func elevation(sim_pos: Vector2) -> float:
	return GRADE * sim_pos.y


## Lift a sim-plane point onto the 3D ground: sim x -> world X, sim y -> world Z,
## elevation -> world Y.
static func to_world(sim_pos: Vector2) -> Vector3:
	return Vector3(sim_pos.x, elevation(sim_pos), sim_pos.y)
