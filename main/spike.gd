extends Node3D
## SLICE 0 SPIKE (chapter 1): does "the world far below me" land? Deliberately ugly.
## A hand-placed path with two switchbacks down a procedural hillside to a flat sea,
## the rider on rails at constant speed, a chase camera pitched down so the horizon
## sits in the top quarter. No sim, no input. Judged by one capture at the first
## switchback against the Montpelier frame. See docs/chapter-1-mountain-spec.md.

const SPEED := 400.0          # rider travel along the path (world units / s)
const PATH_WIDTH := 60.0      # narrow pale path (about 1.3 deck lengths)
const SEA_LEVEL := 0.0
const SUMMIT := 3000.0        # hillside height at the start
const COAST_Z := -9000.0      # where the hillside meets the sea (path runs toward -Z)
const GRID := 170             # hillside grid resolution per side
const GRID_SIZE := 22000.0    # hillside extent (centred on the path)
const SHELF_HALF := 45.0      # terrain is flattened onto the path within this lateral distance
const SHELF_BLEND := 260.0    # ...and eases back to the mountain over this
const STRIP_HALF := 440.0     # exact near strip either side of the path (world units)
const STRIP_STEPS := 10       # lateral subdivisions per side of the strip

# The descent, as sim-plane (x, z) waypoints. Two switchbacks: right traverse, hairpin
# back left, long traverse left, hairpin back right, then a sweep down to the shore.
const WAYPOINTS := [
	Vector2(0, 0), Vector2(150, -900), Vector2(500, -1700), Vector2(1000, -2400),
	Vector2(1350, -2750), Vector2(1450, -3000), Vector2(1250, -3200),
	Vector2(700, -3350), Vector2(-300, -3800), Vector2(-1100, -4300),
	Vector2(-1500, -4700), Vector2(-1500, -5000), Vector2(-1150, -5150),
	Vector2(-300, -5500), Vector2(400, -6300), Vector2(800, -7300),
	Vector2(700, -8300), Vector2(500, -8900),
]

var _curve := Curve3D.new()
var _noise := FastNoiseLite.new()
var _rider: Node3D
var _cam: Camera3D
var _dist := 0.0


func _ready() -> void:
	_noise.seed = 3
	_noise.frequency = 1.0 / 1800.0
	_noise.fractal_octaves = 3
	for w in WAYPOINTS:
		_curve.add_point(Vector3(w.x, 0.0, w.y))
	_smooth_curve()
	for i in range(_curve.point_count):
		var p := _curve.get_point_position(i)
		p.y = _background(p.x, p.z) + 2.0
		_curve.set_point_position(i, p)
	_curve.bake_interval = 20.0

	add_child(_sky())
	add_child(_sun())
	add_child(_hillside())
	add_child(_sea())
	add_child(_near_strip())
	add_child(_path_ribbon())
	add_child(_town())
	add_child(VistaBackdrop3D.new())
	add_child(CloudCards3D.new())

	_rider = Node3D.new()
	add_child(_rider)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(10.0, 2.0, 46.0)
	deck.mesh = dm
	deck.position.y = 5.0
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.79, 0.48, 0.23)
	deck.material_override = deck_mat
	_rider.add_child(deck)
	var card := RiderCard3D.new()
	card.position.y = 6.0
	_rider.add_child(card)

	_cam = Camera3D.new()
	_cam.far = 12000.0
	add_child(_cam)
	_cam.make_current()
	_place(0.0)


func _process(delta: float) -> void:
	_dist = minf(_dist + SPEED * delta, _curve.get_baked_length() - 1.0)
	_place(delta)


# Rider on rails; camera behind/above pitched down (horizon ~top quarter), rider ~half
# the frame height with the head near centre. Positions are smoothed lightly.
func _place(delta: float) -> void:
	var pos := _curve.sample_baked(_dist)
	var ahead := _curve.sample_baked(minf(_dist + 40.0, _curve.get_baked_length()))
	var fwd := ahead - pos
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	_rider.global_position = pos
	_rider.look_at(pos + fwd, Vector3.UP)

	var cam_target := pos - fwd * 105.0 + Vector3.UP * 80.0
	var look := pos + fwd * 180.0 - Vector3.UP * 30.0
	cam_target.y = maxf(cam_target.y, _ground(cam_target.x, cam_target.z) + 30.0)  # never inside the hill
	if delta <= 0.0:
		_cam.global_position = cam_target
	else:
		_cam.global_position = _cam.global_position.lerp(cam_target, clampf(4.0 * delta, 0.0, 1.0))
	_cam.look_at(look, Vector3.UP)


# --- world ---------------------------------------------------------------------

# Background mountain: descends from the summit to the sea toward -Z, steep near the
# top (about 34 deg), with a gentle bowl so the coast curves, plus low-frequency noise.
func _background(x: float, z: float) -> float:
	var t := clampf(-z / -COAST_Z, 0.0, 1.0)
	var fall := SUMMIT * pow(1.0 - t, 2.0)
	var bowl := 0.00002 * x * x * (1.0 - t)  # sides rise away from the path corridor
	var n := _noise.get_noise_2d(x, z) * 160.0 * (0.3 + t)
	return fall + bowl + n


# Road-first ground: the mountain, flattened onto the path's height near the path (a
# shelf cut into the slope), easing back to the mountain with lateral distance. This is
# the chapter 1 height-field model in miniature (docs/chapter-1-mountain-spec.md).
func _ground(x: float, z: float) -> float:
	var bg := _background(x, z)
	var near := _curve.get_closest_point(Vector3(x, bg, z))
	var d := Vector2(x - near.x, z - near.z).length()
	if d >= SHELF_HALF + SHELF_BLEND:
		return bg
	var w := smoothstep(0.0, 1.0, (d - SHELF_HALF) / SHELF_BLEND)
	return lerpf(near.y - 2.0, bg, w)


func _hillside() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := GRID_SIZE / float(GRID)
	var x0 := -GRID_SIZE * 0.5
	var z0 := 4000.0  # a little behind the start; extends past the coast into the sea
	for i in range(GRID):
		for j in range(GRID):
			var xa := x0 + step * float(i)
			var xb := xa + step
			var za := z0 - step * float(j)
			var zb := za - step
			var a := Vector3(xa, _grid_ground(xa, za), za)
			var b := Vector3(xb, _grid_ground(xb, za), za)
			var c := Vector3(xb, _grid_ground(xb, zb), zb)
			var d := Vector3(xa, _grid_ground(xa, zb), zb)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)
	st.generate_normals()
	return _mesh(st.commit(), Color(0.42, 0.55, 0.30))


# The coarse grid cannot resolve the shelf between its vertices, so near the path it is
# pushed DOWN under the exact near strip (which covers it), fading out past the strip.
func _grid_ground(x: float, z: float) -> float:
	var near := _curve.get_closest_point(Vector3(x, 0.0, z))
	var d := Vector2(x - near.x, z - near.z).length()
	var sink := 60.0 * (1.0 - smoothstep(STRIP_HALF - 140.0, STRIP_HALF + 40.0, d))
	return _ground(x, z) - sink


# Exact ground either side of the path, built in (s, n) coordinates along the curve so
# the shelf and its blend are resolved no matter how coarse the far grid is.
func _near_strip() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := _curve.get_baked_length()
	var n_rows := int(length / 20.0)
	var prev: Array = []
	for i in range(n_rows + 1):
		var s := minf(float(i) * 20.0, length)
		var p := _curve.sample_baked(s)
		var q := _curve.sample_baked(minf(s + 5.0, length))
		var t := q - p
		t.y = 0.0
		var side := t.normalized().cross(Vector3.UP)
		var row: Array = []
		for k in range(-STRIP_STEPS, STRIP_STEPS + 1):
			var n := STRIP_HALF * float(k) / float(STRIP_STEPS)
			var v := p + side * n
			v.y = _ground(v.x, v.z) + 0.5
			row.append(v)
		if i > 0:
			for k in range(row.size() - 1):
				st.add_vertex(prev[k])
				st.add_vertex(row[k + 1])
				st.add_vertex(prev[k + 1])
				st.add_vertex(prev[k])
				st.add_vertex(row[k])
				st.add_vertex(row[k + 1])
		prev = row
	st.generate_normals()
	return _mesh(st.commit(), Color(0.42, 0.55, 0.30))


func _sea() -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000.0, 60000.0)
	var mi := _mesh(pm, Color(0.16, 0.36, 0.62))
	mi.position = Vector3(0.0, SEA_LEVEL, COAST_Z - 20000.0)
	return mi


# A flat pale ribbon along the curve (edges at the centre height: a cut shelf).
func _path_ribbon() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(_curve.get_baked_length() / 20.0)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in range(n + 1):
		var s := minf(float(i) * 20.0, _curve.get_baked_length())
		var p := _curve.sample_baked(s)
		var q := _curve.sample_baked(minf(s + 5.0, _curve.get_baked_length()))
		var t := (q - p)
		t.y = 0.0
		var side := t.normalized().cross(Vector3.UP) * PATH_WIDTH * 0.5
		var l := p - side + Vector3.UP * 1.5
		var r := p + side + Vector3.UP * 1.5
		if i > 0:
			st.add_vertex(prev_l)
			st.add_vertex(r)
			st.add_vertex(prev_r)
			st.add_vertex(prev_l)
			st.add_vertex(l)
			st.add_vertex(r)
		prev_l = l
		prev_r = r
	st.generate_normals()
	return _mesh(st.commit(), Color(0.86, 0.82, 0.70))


# The destination: a scatter of pale blocks along the shore, so there is somewhere to go.
func _town() -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(60.0, 60.0, 60.0)
	mm.mesh = bm
	mm.instance_count = 260
	for i in range(mm.instance_count):
		var x := rng.randf_range(-2600.0, 2600.0)
		var z := COAST_Z + rng.randf_range(-100.0, 1100.0)
		var h := rng.randf_range(0.6, 2.4)
		var y := maxf(_ground(x, z), SEA_LEVEL)
		var scale := Vector3(rng.randf_range(0.7, 1.4), h, rng.randf_range(0.7, 1.4))
		var xf := Transform3D(Basis().scaled(scale), Vector3(x, y + 30.0 * h, z))
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(Color(0.88, 0.86, 0.80))
	root.add_child(mmi)
	return root


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	return mi


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# Midday-ish sky and haze (spike only; the composition slice sets the real palette).
func _sky() -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_horizon_color = Color(0.82, 0.88, 0.94)
	sky_mat.sky_top_color = Color(0.30, 0.52, 0.86)
	sky_mat.ground_horizon_color = Color(0.70, 0.78, 0.84)
	sky_mat.ground_bottom_color = Color(0.40, 0.55, 0.65)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.66, 0.85)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.72, 0.80, 0.88)
	env.fog_depth_begin = 1500.0
	env.fog_depth_end = 16000.0
	env.fog_depth_curve = 0.7
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	return we


func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3000.0
	return sun


# Give the polyline rounded corners: set Catmull-Rom-ish in/out handles per point.
func _smooth_curve() -> void:
	var n := _curve.point_count
	for i in range(n):
		var prev := _curve.get_point_position(maxi(i - 1, 0))
		var next := _curve.get_point_position(mini(i + 1, n - 1))
		var tangent := (next - prev) * 0.22
		_curve.set_point_in(i, -tangent)
		_curve.set_point_out(i, tangent)
