class_name RoadPath
extends RefCounted
## Pure geometry of the road: a centerline polyline plus a half-width. No Node,
## no rendering. Both the simulation (off-road drag) and the presentation (road
## mesh, posts) read from this, so road/gameplay geometry never lives in
## presentation code and boundary maths stays unit-testable.

var centerline: PackedVector2Array
var half_width: float


func _init(p_centerline: PackedVector2Array = PackedVector2Array(), p_half_width: float = 150.0) -> void:
	centerline = p_centerline
	half_width = p_half_width


## Shortest distance from a world position to the centerline polyline.
func distance_to_center(pos: Vector2) -> float:
	if centerline.size() == 0:
		return 0.0
	if centerline.size() == 1:
		return pos.distance_to(centerline[0])
	var best := INF
	for i in range(centerline.size() - 1):
		var d := _dist_point_to_segment(pos, centerline[i], centerline[i + 1])
		if d < best:
			best = d
	return best


## How far beyond the road edge a position is (0 while on the road).
func off_road_amount(pos: Vector2) -> float:
	return maxf(0.0, distance_to_center(pos) - half_width)


func is_off_road(pos: Vector2) -> bool:
	return off_road_amount(pos) > 0.0


static func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0
	if denom > 0.0:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Build a course from a sequence of segments, giving the run rhythm (straights,
## sweepers, tight corners) instead of one endless sine. Each segment is a
## dictionary {length, slope}: `slope` is the lateral gradient (dx along the
## fall line) reached by the END of the segment, eased smoothly from the previous
## segment's slope. slope 0 = straight down the fall line (fast); larger |slope| =
## running more across the hill (a corner). A bend is two segments — ramp the slope
## up to enter, back toward 0 to exit. Fall line is -Y, so y decreases with length.
static func build_course(
	segments: Array,
	spacing: float,
	start_y: float,
	half_width: float,
) -> RoadPath:
	var points := PackedVector2Array()
	var x := 0.0
	var y := start_y
	var slope_prev := 0.0
	points.append(Vector2(x, y))
	for seg in segments:
		var seg_len: float = seg["length"]
		var slope_target: float = seg["slope"]
		var covered := 0.0
		while covered < seg_len:
			var step: float = minf(spacing, seg_len - covered)
			covered += step
			var weight := smoothstep(0.0, 1.0, covered / seg_len)
			var slope := lerpf(slope_prev, slope_target, weight)
			x += slope * step
			y -= step
			points.append(Vector2(x, y))
		slope_prev = slope_target
	return RoadPath.new(points, half_width)
