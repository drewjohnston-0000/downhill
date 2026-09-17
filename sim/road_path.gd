class_name RoadPath
extends RefCounted
## Pure geometry of the road: a centerline polyline plus a half-width. No Node,
## no rendering. Both the simulation (off-road drag) and the presentation (road
## mesh, posts) read from this, so road/gameplay geometry never lives in
## presentation code and boundary maths stays unit-testable.

var centerline: PackedVector2Array
var half_width: float
## Road surface height at each centerline point (empty = all zero). The road only
## descends: heights are non-increasing along the path.
var heights: PackedFloat32Array = PackedFloat32Array()
## Camber at each point: height change per unit of lateral offset n across the
## shelf (0 = a level shelf). Empty = all zero.
var cambers: PackedFloat32Array = PackedFloat32Array()


func _init(p_centerline: PackedVector2Array = PackedVector2Array(), p_half_width: float = 150.0) -> void:
	centerline = p_centerline
	half_width = p_half_width


## Give the road the heights of a 1-D fall-line profile, with the camber the road
## would have if it were simply painted onto that tilted plane (grade * normal.y).
## This is how the baseline course is expressed in road-first terms: a RoadHeightField
## built from it reproduces the profile exactly on the centerline.
func assign_profile(profile: ElevationProfile) -> void:
	heights = PackedFloat32Array()
	cambers = PackedFloat32Array()
	for i in range(centerline.size()):
		var y := centerline[i].y
		heights.append(profile.height(y))
		cambers.append(profile.grade(y) * _normal_at(i).y)


## Project a position onto the road: arc length `s`, signed lateral offset `n`, the
## interpolated `height` and `camber` there, the unit `tangent`, `lateral` (true
## distance to the nearest point, which differs from |n| only past the road's ends)
## and `t_raw` (the unclamped segment parameter).
func project(pos: Vector2) -> Dictionary:
	var best := {"s": 0.0, "n": 0.0, "height": 0.0, "camber": 0.0,
		"tangent": Vector2.UP, "lateral": INF}
	if centerline.size() < 2:
		return best
	for i in range(centerline.size() - 1):
		var pr := project_onto_segment(pos, i)
		if pr["lateral"] < best["lateral"]:
			best = pr
	return best


## Project onto one segment (clamped to its ends). Same keys as project().
func project_onto_segment(pos: Vector2, i: int) -> Dictionary:
	var a := centerline[i]
	var b := centerline[i + 1]
	var ab := b - a
	var seg_len := ab.length()
	var t_raw := 0.0
	if seg_len > 0.0:
		t_raw = (pos - a).dot(ab) / (seg_len * seg_len)
	var t := clampf(t_raw, 0.0, 1.0)
	var proj := a + ab * t
	var tangent := ab / seg_len if seg_len > 0.0 else Vector2.UP
	var normal := tangent.orthogonal()
	return {
		"s": _arc_length_to(i) + t * seg_len,
		"n": (pos - proj).dot(normal),
		"height": lerpf(_height_at_index(i), _height_at_index(i + 1), t),
		"camber": lerpf(_camber_at_index(i), _camber_at_index(i + 1), t),
		"tangent": tangent,
		"lateral": pos.distance_to(proj),
		"t_raw": t_raw,  # unclamped: < 0 or > 1 means the foot fell off this segment's end
	}


func _height_at_index(i: int) -> float:
	return heights[i] if i < heights.size() else 0.0


func _camber_at_index(i: int) -> float:
	return cambers[i] if i < cambers.size() else 0.0


func _arc_length_to(index: int) -> float:
	var s := 0.0
	for i in range(index):
		s += centerline[i].distance_to(centerline[i + 1])
	return s


# Unit normal at centerline point i (perpendicular to the local tangent).
func _normal_at(i: int) -> Vector2:
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, centerline.size() - 1)
	var tangent := centerline[b] - centerline[a]
	if tangent.length() < 0.0001:
		return Vector2.RIGHT
	return tangent.normalized().orthogonal()


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
