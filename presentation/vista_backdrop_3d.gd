class_name VistaBackdrop3D
extends Node3D
## The distant vista as real 3D backdrop geometry — the robust answer to why the 2D
## version clipped the poles. A CanvasLayer composites OVER the whole 3D image (2D and
## 3D share no depth buffer), so it can never sit behind a pole. Real geometry does:
## the poles are simply nearer, and the depth buffer occludes the vista correctly in
## every camera angle.
##
## Ridge rings are centred on the camera each frame (follow its POSITION, not its
## rotation) so they behave as if at infinity: no translation parallax, they pan with
## yaw, and the horizon holds as you descend. Each ring is a hazy silhouette welded
## around the sky; nearer rings use a slightly smaller radius so the depth buffer sorts
## them (nearer in front) and their peaks show through. Flat unshaded haze colours — no
## shader, no texture. Presentation only; finds the active camera each frame.

const R_BASE := 4000.0    # radius of the farthest ring (well inside the camera far plane)
const RING_GAP := 90.0    # nearer rings shrink by this, so depth sorts them front-to-back
const SEGMENTS := 180     # azimuth resolution of each ring
const BASELINE_DEG := -1.5  # ring closes just below the horizon (behind the fogged ground)

# Farthest → nearest: far = tall + pale blue; near = low + greener.
const LAYERS := [
	{"base": 3.6, "amp": 3.0, "color": Color(0.66, 0.73, 0.82), "ph": [0.0, 1.7, 3.9]},
	{"base": 2.5, "amp": 2.4, "color": Color(0.56, 0.65, 0.73), "ph": [2.1, 4.3, 0.6]},
	{"base": 1.6, "amp": 2.0, "color": Color(0.50, 0.61, 0.59), "ph": [4.8, 0.9, 2.7]},
	{"base": 0.8, "amp": 1.5, "color": Color(0.49, 0.60, 0.50), "ph": [1.2, 3.1, 5.5]},
]

var _cam: Camera3D = null


func _ready() -> void:
	for i in range(LAYERS.size()):
		add_child(_build_ring(LAYERS[i], R_BASE - float(i) * RING_GAP))


func _process(_delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam != null:
		# Follow the camera's POSITION only (world-axis aligned), so the ring reads as
		# distant: pans with yaw, no translation parallax, horizon stays put on descent.
		global_position = _cam.global_position


func _build_ring(l: Dictionary, r: float) -> MeshInstance3D:
	var base: float = l["base"]
	var amp: float = l["amp"]
	var ph: Array = l["ph"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		var t0 := _dir(a0, deg_to_rad(base + amp * _ridge01(a0, ph))) * r
		var t1 := _dir(a1, deg_to_rad(base + amp * _ridge01(a1, ph))) * r
		var b0 := _dir(a0, deg_to_rad(BASELINE_DEG)) * r
		var b1 := _dir(a1, deg_to_rad(BASELINE_DEG)) * r
		st.add_vertex(t0)
		st.add_vertex(b0)
		st.add_vertex(b1)
		st.add_vertex(t0)
		st.add_vertex(b1)
		st.add_vertex(t1)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = l["color"]
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # distant haze, not lit by our sun
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.extra_cull_margin = r * 2.0  # it re-centres every frame; never cull it
	return mi


# Unit direction for azimuth `a` (a=0 is -Z, down the course) and elevation `e`.
func _dir(a: float, e: float) -> Vector3:
	return Vector3(cos(e) * sin(a), sin(e), -cos(e) * cos(a))


# A smooth, seamless-around-the-circle ridge height in 0..1 for azimuth `a`.
func _ridge01(a: float, ph: Array) -> float:
	var n := 0.5 * sin(3.0 * a + ph[0]) + 0.3 * sin(7.0 * a + ph[1]) + 0.2 * sin(11.0 * a + ph[2])
	return clampf(0.5 + 0.5 * n, 0.0, 1.0)
