class_name Course
extends Node2D
## Draws the road for Milestone 1. Pure renderer: it takes a RoadPath (centerline
## + half-width, defined in sim/) and draws a ribbon from it. Road geometry and
## boundary maths live in the RoadPath, not here.

@export var grass_color: Color = Color(0.42, 0.58, 0.34)
@export var road_color: Color = Color(0.28, 0.29, 0.32)
@export var edge_color: Color = Color(0.9, 0.9, 0.92)
@export var dash_color: Color = Color(0.85, 0.82, 0.5)

## The road geometry to draw. Set before adding to the tree.
var road_path: RoadPath = null


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if road_path == null or road_path.centerline.size() < 2:
		return

	var centerline := road_path.centerline
	var half_width := road_path.half_width

	# Grass backdrop covering the whole descent (derived from the centerline).
	var bounds := _centerline_bounds(centerline)
	var pad := 4000.0
	draw_rect(Rect2(bounds.position - Vector2(pad, pad), bounds.size + Vector2(pad, pad) * 2.0), grass_color, true)

	# Road ribbon: one quad per centerline segment.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(centerline.size()):
		var normal := _normal_at(centerline, i)
		left.append(centerline[i] - normal * half_width)
		right.append(centerline[i] + normal * half_width)

	for i in range(centerline.size() - 1):
		var quad := PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]])
		draw_colored_polygon(quad, road_color)

	# Painted edges.
	draw_polyline(left, edge_color, 4.0)
	draw_polyline(right, edge_color, 4.0)

	# Dashed centre line for readability / sense of speed.
	var i := 0
	while i < centerline.size() - 1:
		draw_line(centerline[i], centerline[i + 1], dash_color, 3.0)
		i += 3  # draw ~1 in 3 segments -> dashes


func _centerline_bounds(centerline: PackedVector2Array) -> Rect2:
	var r := Rect2(centerline[0], Vector2.ZERO)
	for p in centerline:
		r = r.expand(p)
	return r


## Unit normal (perpendicular to travel) at centerline point i.
func _normal_at(centerline: PackedVector2Array, i: int) -> Vector2:
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, centerline.size() - 1)
	var tangent := centerline[b] - centerline[a]
	if tangent.length() < 0.0001:
		return Vector2.RIGHT
	return tangent.orthogonal().normalized()
