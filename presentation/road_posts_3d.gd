class_name RoadPosts3D
extends Node3D
## Snow-depth marker posts lining both road edges, evenly spaced along the course.
## They do three readability jobs at once: delineate the road edge, give a
## streaming range/speed cue (parallax you can judge distance by), and — because
## they stand upright — crest a rise BEFORE the road does, so you can read where
## the road goes while the tarmac is still hidden.
##
## No art: a dark pole with a bright tip, flat unlit, drawn as two MultiMeshes
## (one draw call each) so hundreds of posts are nearly free. Presentation only —
## reads RoadPath + Terrain3D, never the sim. Set road_path before adding to tree.

@export var spacing: float = 160.0          ## distance between posts along the road
@export var margin: float = 22.0            ## how far outside the road edge they sit
@export var post_height: float = 120.0
@export var post_width: float = 7.0
@export var pole_color: Color = Color(0.12, 0.12, 0.14)
@export var tip_color: Color = Color(0.95, 0.45, 0.15)

var road_path: RoadPath = null


func _ready() -> void:
	if road_path == null or road_path.centerline.size() < 2:
		return
	var grounds := _ground_points()
	# Pole body: base sits on the ground, so lift the (centred) box half its height.
	var pole := _box_mesh(post_width, post_height, post_width)
	add_child(_layer(pole, pole_color, grounds, post_height * 0.5))
	# Bright tip: a fatter, shorter box capping the top.
	var tip_h := post_height * 0.28
	var tip := _box_mesh(post_width * 1.5, tip_h, post_width * 1.5)
	add_child(_layer(tip, tip_color, grounds, post_height - tip_h * 0.5))


# World ground points where posts stand: both edges, every `spacing` along the road.
func _ground_points() -> Array:
	var grounds := []
	var cl := road_path.centerline
	var acc := spacing  # drop the first pair right at the start
	for i in range(cl.size()):
		if i > 0:
			acc += cl[i].distance_to(cl[i - 1])
		if acc < spacing:
			continue
		acc = 0.0
		var normal := _normal(i)
		for side in [-1.0, 1.0]:
			var edge: Vector2 = cl[i] + normal * float(side) * (road_path.half_width + margin)
			grounds.append(Terrain3D.to_world(edge))
	return grounds


# One MultiMesh layer: the given mesh placed at each ground point, raised by y_off.
func _layer(mesh: Mesh, color: Color, grounds: Array, y_off: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = grounds.size()
	for i in range(grounds.size()):
		var origin: Vector3 = grounds[i] + Vector3.UP * y_off
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, origin))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _flat_material(color)
	return mmi


func _box_mesh(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


# Road normal at centerline point i (same convention as RoadMesh3D).
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
	m.albedo_color = color
	return m
