class_name CloudCards3D
extends Node3D
## Soft cumulus clouds as flat painted cards in the 3D sky. The same two-tone puff
## shapes the old 2D canvas layer drew, but as real geometry: each cloud is a fan of
## flat discs (sunlit tops over a cool underside) standing on a sphere just beyond the
## vista ring, on a rig that follows the camera's POSITION each frame (never its
## rotation). So the clouds sit at infinity exactly as before, but they are now
## depth-tested: ridges occlude low clouds, and nothing near the camera — the rider's
## head against the sky — can be drawn over. That is why the canvas version went.
##
## No shader, no texture. Unshaded flat colours, like the ring. Presentation only.

const RADIUS := 4200.0       # beyond the vista ring (4000), inside the camera far plane
const DISC_SEGMENTS := 24
const TOP_LIFT := 3.0        # tops sit this much nearer the camera than the underside
const UNDERSIDE_DROP := 5.0  # underside offset down (authored units), as on the canvas

@export var cloud_color: Color = Color(0.98, 0.97, 0.93)      ## sunlit top
@export var underside_color: Color = Color(0.80, 0.83, 0.90)  ## cool shaded base
@export var count: int = 16               ## spread around the full sky so some are always ahead
@export var elev_min_deg: float = 1.5     ## lowest cloud, degrees above the horizon
@export var elev_max_deg: float = 9.0     ## highest cloud
@export var rng_seed: int = 7
## Puff radii are authored in screen-ish units (20..40); this turns them into world
## units at the card distance so they read about as they did on the 2D canvas.
@export var size_scale: float = 5.0

var _cam: Camera3D = null


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var az_step := TAU / float(maxi(count, 1))
	for i in range(count):
		var base_r := rng.randf_range(20.0, 40.0)
		var span := base_r * rng.randf_range(1.4, 2.2)
		var npuffs := rng.randi_range(4, 6)
		var puffs: Array = []
		for k in range(npuffs):
			var t := float(k) / float(npuffs - 1)
			var x := lerpf(-span, span, t)
			var r := base_r * (0.5 + 0.5 * sin(t * PI)) + rng.randf_range(-3.0, 3.0)
			var cy := r + rng.randf_range(-0.1, 0.1) * base_r  # bottoms ~aligned (flat base)
			puffs.append({"off": Vector2(x, cy) * size_scale, "r": maxf(r, 6.0) * size_scale})
		var az := az_step * (float(i) + rng.randf_range(-0.35, 0.35))
		var elev := deg_to_rad(rng.randf_range(elev_min_deg, elev_max_deg))
		add_child(_cloud(az, elev, puffs))


func _process(_delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam != null:
		global_position = _cam.global_position


# One cloud: a node on the sky sphere in direction (az, elev), yawed to face the rig
# origin (= the camera), carrying an underside fan and a sunlit top fan.
func _cloud(az: float, elev: float, puffs: Array) -> Node3D:
	var dir := Vector3(cos(elev) * sin(az), sin(elev), -cos(elev) * cos(az))
	var node := Node3D.new()
	node.position = dir * RADIUS
	# Local +Z must point back at the origin: look_at aims -Z, so aim it outward.
	node.basis = Basis.looking_at(Vector3(dir.x, 0.0, dir.z).normalized(), Vector3.UP)
	node.add_child(_fan(puffs, Vector2(0.0, -UNDERSIDE_DROP * size_scale), 0.0, underside_color))
	node.add_child(_fan(puffs, Vector2.ZERO, TOP_LIFT, cloud_color))
	return node


# A flat union of discs in the local XY plane at depth z, one mesh, unshaded.
func _fan(puffs: Array, shift: Vector2, z: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in puffs:
		var off: Vector2 = p["off"]
		var c := Vector3(off.x + shift.x, off.y + shift.y, z)
		var r: float = p["r"]
		for s in range(DISC_SEGMENTS):
			var a0 := TAU * float(s) / float(DISC_SEGMENTS)
			var a1 := TAU * float(s + 1) / float(DISC_SEGMENTS)
			st.add_vertex(c)
			st.add_vertex(c + Vector3(cos(a0), sin(a0), 0.0) * r)
			st.add_vertex(c + Vector3(cos(a1), sin(a1), 0.0) * r)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true  # real geometry now, but a painted sky: the depth haze must not tint it
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.extra_cull_margin = RADIUS * 2.0  # the rig re-centres every frame; never cull
	return mi
