class_name Terrain3D
extends RefCounted
## The single source of truth for mapping the simulation's 2D plane into the 3D
## world. The sim plane (x, y) becomes the ground; a height comes from the
## elevation profile. Every 3D node (road mesh, rider, camera) projects through
## here so they always agree.
##
## Height comes from a shared ElevationProfile — the SAME object the sim reads for
## its fall-line pull, so terrain and physics can never disagree. main.gd sets this
## to the course profile; the default is a plain constant grade so Terrain3D also
## works standalone (and matches the old Stage 0 look).
static var profile: ElevationProfile = ElevationProfile.new(0.2, 0.0, 0.0)


## Ground height (world Y) at a point in the sim plane.
static func elevation(sim_pos: Vector2) -> float:
	return profile.height(sim_pos.y)


## Lift a sim-plane point onto the 3D ground: sim x -> world X, sim y -> world Z,
## elevation -> world Y.
static func to_world(sim_pos: Vector2) -> Vector3:
	return Vector3(sim_pos.x, elevation(sim_pos), sim_pos.y)
