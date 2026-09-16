class_name FinishGate3D
extends Node3D
## A finish gate spanning the road at the course end: two tall edge posts and a
## checkered beam across the top. Tall on purpose — visible from far off and over
## crests, so you can see the finish coming. No art, flat unlit. Presentation only:
## reads RoadPath + Terrain3D. Set road_path before adding to the tree.

@export var post_height: float = 220.0
@export var post_width: float = 14.0
@export var beam_thickness: float = 26.0
@export var overhang: float = 24.0        ## how far outside the road edge the posts sit
@export var checker_count: int = 10       ## segments in the checkered beam
@export var post_color: Color = Color(0.10, 0.10, 0.12)

var road_path: RoadPath = null


func _ready() -> void:
	if road_path == null or road_path.centerline.size() < 2:
		return
	var i := road_path.centerline.size() - 1
	var normal := _normal(i)
	var hw := road_path.half_width + overhang
	var left_base := Terrain3D.to_world(road_path.centerline[i] - normal * hw)
	var right_base := Terrain3D.to_world(road_path.centerline[i] + normal * hw)

	add_child(_span(left_base, left_base + Vector3.UP * post_height, post_width, post_color))
	add_child(_span(right_base, right_base + Vector3.UP * post_height, post_width, post_color))

	var top := Vector3.UP * post_height
	_add_checkered_beam(left_base + top, right_base + top)


# A checkered beam from a to b: alternating black/white boxes end to end.
func _add_checkered_beam(a: Vector3, b: Vector3) -> void:
	for k in range(checker_count):
		var t0 := float(k) / checker_count
		var t1 := float(k + 1) / checker_count
		var seg_a := a.lerp(b, t0)
		var seg_b := a.lerp(b, t1)
		var color := Color.WHITE if k % 2 == 0 else Color.BLACK
		add_child(_span(seg_a, seg_b, beam_thickness, color))


# A box stretched from world point a to world point b, square in cross-section.
func _span(a: Vector3, b: Vector3, thickness: float, color: Color) -> MeshInstance3D:
	var delta := b - a
	var length := delta.length()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, thickness, thickness)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _flat_material(color)
	var x_axis := delta.normalized() if length > 0.0001 else Vector3.RIGHT
	var helper := Vector3.UP if absf(x_axis.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var z_axis := x_axis.cross(helper).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	mi.transform = Transform3D(Basis(x_axis, y_axis, z_axis), a.lerp(b, 0.5))
	return mi


func _normal(i: int) -> Vector2:
	var cl := road_path.centerline
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, cl.size() - 1)
	var tangent := cl[b] - cl[a]
	if tangent.length() < 0.0001:
		return Vector2.RIGHT
	return tangent.orthogonal().normalized()


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m
