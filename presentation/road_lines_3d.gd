class_name RoadLines3D
extends Node3D
## White markings painted on the tarmac: a dashed centre line and two solid gutter
## (edge) lines, following the centerline and terrain elevation. A splash cue and a
## readability aid (lane centre + road edges). No art — solid ribbons lit like the
## rest. Presentation only: reads RoadPath + Terrain3D. Set road_path before adding
## to the tree.

@export var line_color: Color = Color(0.90, 0.90, 0.86)  ## warm off-white paint
@export var line_width: float = 5.0        ## world-unit width of each painted line
@export var edge_inset: float = 12.0       ## how far inside the road edge the gutters sit
@export var dash_length: float = 60.0      ## centre dash on-length
@export var dash_gap: float = 60.0         ## centre dash off-length
@export var lift: float = 1.5              ## height above the road surface (anti z-fight)

var road_path: RoadPath = null


func _ready() -> void:
	if road_path == null or road_path.centerline.size() < 2:
		return
	var edge := road_path.half_width - edge_inset
	add_child(_line(0.0, true))     # centre line: dashed
	add_child(_line(-edge, false))  # left gutter: solid
	add_child(_line(edge, false))   # right gutter: solid


# A painted line ribbon centred at lateral `offset` from the centerline. When dashed,
# only the "on" spans of the dash cycle are emitted (gaps are simply skipped quads).
func _line(offset: float, dashed: bool) -> MeshInstance3D:
	var cl := road_path.centerline
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := line_width * 0.5
	var lift_v := Vector3.UP * lift
	var dist := 0.0
	var period := dash_length + dash_gap
	for i in range(cl.size() - 1):
		if i > 0:
			dist += cl[i].distance_to(cl[i - 1])
		if dashed and fposmod(dist, period) >= dash_length:
			continue
		var la := _edge(i, offset - hw) + lift_v
		var ra := _edge(i, offset + hw) + lift_v
		var lb := _edge(i + 1, offset - hw) + lift_v
		var rb := _edge(i + 1, offset + hw) + lift_v
		st.add_vertex(la)
		st.add_vertex(lb)
		st.add_vertex(rb)
		st.add_vertex(la)
		st.add_vertex(rb)
		st.add_vertex(ra)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material()
	return mi


# World position `off` units sideways (along the road normal, so lines curve with the
# road) from centerline point i, on the true h(y) surface.
func _edge(i: int, off: float) -> Vector3:
	var cl := road_path.centerline
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, cl.size() - 1)
	var tangent := cl[b] - cl[a]
	var lateral := Vector2.RIGHT
	if tangent.length() >= 0.0001:
		lateral = tangent.orthogonal().normalized()
	return Terrain3D.to_world(cl[i] + lateral * off)


func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = line_color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
