class_name RoadMesh3D
extends Node3D
## Builds the 3D road as flat-shaded ribbons from a RoadPath: a wide green grass
## band and the grey road on top, both following the centerline and the terrain
## elevation. No textures — solid colours, lit by the scene sun (normals generated).
## Set road_path before adding to the tree.

## Half-width of the grass band flanking the road (world units).
@export var grass_half_width: float = 2500.0
@export var road_color: Color = Color(0.30, 0.31, 0.34)
@export var grass_color: Color = Color(0.42, 0.58, 0.34)

var road_path: RoadPath = null


func _ready() -> void:
	if road_path == null or road_path.centerline.size() < 2:
		return
	# Grass sits below the road. The gap is generous (not just anti-z-fighting): the
	# road widens along its normal, so on a curve a single road quad spans a long
	# stretch of the fall line and sags a few units below the true crest as a flat
	# approximation. The grass (short world-X quads) hugs the surface, so too small a
	# gap lets grass poke through the sagging road. It widens along world-X (not the
	# road normal) so a wide band never samples elevation far down the hill.
	add_child(_ribbon(grass_half_width, -8.0, grass_color, false))
	add_child(_ribbon(road_path.half_width, 0.0, road_color, true))


# A ribbon mesh (one quad per centerline segment) at the given half-width and
# vertical offset, with a flat unlit material of the given colour. When
# follow_normal is true the ribbon widens along the road normal (so it curves with
# the road); otherwise it widens along world-X (a flat ground band).
func _ribbon(half_width: float, y_offset: float, color: Color, follow_normal: bool) -> MeshInstance3D:
	var centerline := road_path.centerline
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := Vector3(0.0, y_offset, 0.0)
	for i in range(centerline.size() - 1):
		var la := _edge(i, -half_width, follow_normal) + lift
		var ra := _edge(i, half_width, follow_normal) + lift
		var lb := _edge(i + 1, -half_width, follow_normal) + lift
		var rb := _edge(i + 1, half_width, follow_normal) + lift
		# Two triangles per quad (material is double-sided, so winding is moot).
		st.add_vertex(la)
		st.add_vertex(lb)
		st.add_vertex(rb)
		st.add_vertex(la)
		st.add_vertex(rb)
		st.add_vertex(ra)
	st.generate_normals()  # so the sun has surface normals to light the ribbon
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _flat_material(color)
	return mi


# World position of the ribbon edge `offset` units sideways from centerline point i.
# Height comes from the edge point's own y (via to_world) so every vertex lies on
# the true h(y) surface and road/grass can never cross. The road widens along its
# normal (curves with the road); the grass widens along world-X, so its wide span
# stays near the centerline's y instead of sampling elevation far down the hill.
func _edge(i: int, offset: float, follow_normal: bool) -> Vector3:
	var centerline := road_path.centerline
	var lateral := Vector2.RIGHT
	if follow_normal:
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, centerline.size() - 1)
		var tangent := centerline[b] - centerline[a]
		if tangent.length() >= 0.0001:
			lateral = tangent.orthogonal().normalized()
	return Terrain3D.to_world(centerline[i] + lateral * offset)


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m
