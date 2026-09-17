class_name RoadHeightField
extends HeightField
## Road-first terrain: the ground is a background field (a mountain) with the road cut
## into it as a shelf. Near the road the height is the ROAD's (plus its camber across
## the shelf), beyond the edge a cross-section climbs on the rise side and falls on
## the drop side, and over `blend` that eases back into the background. Lets the road
## switchback freely across a real hillside while the sim reads one consistent field.
##
## On the shelf the height is exact (the nearest on-shelf segment wins outright), so a
## road never drifts because another tier of a hairpin is nearby. Off the shelf,
## every road segment within reach contributes, weighted by how close it is, which
## keeps the ground continuous between two nearby tiers instead of terracing.
## Design rule: keep hairpin tiers at least 2 * (half_width + blend) apart so their
## blends do not overlap.

var road: RoadPath
var base: HeightField
var blend: float        ## lateral distance past the edge over which the shelf eases into base
var rise_slope: float   ## dh per unit of lateral distance beyond the edge, rise side (> 0 climbs)
var drop_slope: float   ## same on the drop side (< 0 falls)
var rise_side: float    ## +1 or -1: which sign of lateral offset n is the rise side


func _init(
	p_road: RoadPath,
	p_base: HeightField,
	p_blend: float = 200.0,
	p_rise_slope: float = 0.0,
	p_drop_slope: float = 0.0,
	p_rise_side: float = 1.0,
) -> void:
	road = p_road
	base = p_base
	blend = p_blend
	rise_slope = p_rise_slope
	drop_slope = p_drop_slope
	rise_side = p_rise_side


func height_at(pos: Vector2) -> float:
	var hw := road.half_width
	var reach := hw + blend
	var cl := road.centerline
	var on_shelf_h := 0.0
	var on_shelf_d := INF
	var mix_h := 0.0
	var mix_w := 0.0
	var w_max := 0.0
	var last := cl.size() - 2
	for i in range(cl.size() - 1):
		var pr := road.project_onto_segment(pos, i)
		var lateral: float = pr["lateral"]
		if lateral > reach:
			continue
		if not _owns_projection(pos, i, last, pr["t_raw"]):
			continue
		var n: float = pr["n"]
		var h_centre: float = pr["height"]
		var camber: float = pr["camber"]
		if lateral <= hw:
			if lateral < on_shelf_d:
				on_shelf_d = lateral
				on_shelf_h = h_centre + camber * n
			continue
		# Past the edge: the shelf edge height, then the cross-section slope outward.
		var side := signf(n) if n != 0.0 else 1.0
		var h_edge := h_centre + camber * side * hw
		var slope := rise_slope if side == rise_side else drop_slope
		var h := h_edge + slope * (lateral - hw)
		var w := 1.0 - smoothstep(hw, reach, lateral)
		mix_h += w * h
		mix_w += w
		w_max = maxf(w_max, w)
	if on_shelf_d < INF:
		return on_shelf_h
	var b := base.height_at(pos)
	if mix_w > 0.0:
		return lerpf(b, mix_h / mix_w, w_max)
	return b


# A polyline joint must contribute once, not once per segment touching it. A segment
# whose foot fell off its START (t_raw < 0) at an interior joint never owns the point:
# the previous segment either projects onto it properly or owns the joint's outer
# wedge. A segment whose foot fell off its END at an interior joint owns the point
# only if it lies in that wedge (the next segment's foot also falls off, before its
# start). The road's two ends keep their rounded caps.
func _owns_projection(pos: Vector2, i: int, last: int, t_raw: float) -> bool:
	if t_raw < 0.0:
		return i == 0
	if t_raw > 1.0:
		if i == last:
			return true
		return road.project_onto_segment(pos, i + 1)["t_raw"] < 0.0
	return true


## Mean grade of the road (total drop over total length); the course's typical
## steepness, so gravity on the road behaves as configured.
func reference_grade() -> float:
	var cl := road.centerline
	if cl.size() < 2 or road.heights.size() != cl.size():
		return 1.0
	var length := 0.0
	for i in range(cl.size() - 1):
		length += cl[i].distance_to(cl[i + 1])
	var drop := road.heights[0] - road.heights[cl.size() - 1]
	if length <= 0.0 or drop <= 0.0:
		return 1.0
	return drop / length
