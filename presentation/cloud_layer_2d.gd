class_name CloudLayer2D
extends CanvasLayer
## Soft cumulus clouds as a 2D painterly layer over the sky — the "2D skin" half of
## "3D space, 2D painterly skin". No shader, no texture: flat cloud shapes drawn in
## code (matching the scene's flat-shaded surfaces).
##
## Each cloud has a FIXED direction in the world (azimuth around + elevation above the
## horizon) and is projected through the live Camera3D every frame. So the clouds are
## welded to the sky at infinity: they anchor to the horizon and track it exactly as
## you yaw and pitch down the hill — no bobbing. Presentation only; it finds the active
## camera each frame, so just add it to the tree after a camera exists.

@export var cloud_color: Color = Color(0.98, 0.97, 0.93)      ## sunlit top
@export var underside_color: Color = Color(0.80, 0.83, 0.90)  ## cool shaded base
@export var count: int = 16               ## spread around the full sky so some are always ahead
@export var elev_min_deg: float = 1.5     ## lowest cloud, degrees above the horizon
@export var elev_max_deg: float = 9.0     ## highest cloud
@export var rng_seed: int = 7

var _canvas: _Canvas


func _ready() -> void:
	_canvas = _Canvas.new()
	_canvas.cfg = self
	add_child(_canvas)


# The drawing surface. Kept as an inner Node2D so the layer stays a plain CanvasLayer.
class _Canvas:
	extends Node2D
	# Far enough that camera travel causes no perceptible parallax (clouds ~ at infinity).
	const FAR := 5.0e6
	var cfg: CloudLayer2D
	var _clouds: Array = []
	var _built := false

	func _process(_delta: float) -> void:
		queue_redraw()

	# Build clouds once: a fixed sky direction (azimuth/elevation) and a puff shape each.
	func _build() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = cfg.rng_seed
		var az_step := TAU / float(maxi(cfg.count, 1))
		for i in range(cfg.count):
			var base_r := rng.randf_range(20.0, 40.0)
			var span := base_r * rng.randf_range(1.4, 2.2)
			var npuffs := rng.randi_range(4, 6)
			var puffs: Array = []
			for k in range(npuffs):
				var t := float(k) / float(npuffs - 1)
				var x := lerpf(-span, span, t)
				var r := base_r * (0.5 + 0.5 * sin(t * PI)) + rng.randf_range(-3.0, 3.0)
				var cy := -r + rng.randf_range(-0.1, 0.1) * base_r  # bottoms ~aligned (flat base)
				puffs.append({"off": Vector2(x, cy), "r": maxf(r, 6.0)})
			# Even spacing around the whole sky, jittered so it doesn't look regular.
			var az := az_step * (float(i) + rng.randf_range(-0.35, 0.35))
			_clouds.append({
				"az": az,
				"elev": deg_to_rad(rng.randf_range(cfg.elev_min_deg, cfg.elev_max_deg)),
				"puffs": puffs,
			})
		_built = true

	func _draw() -> void:
		if not _built:
			_build()
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var origin := cam.global_position
		for c in _clouds:
			var e: float = c["elev"]
			var a: float = c["az"]
			# World direction: az=0 is forward (-Z, down the course), elev lifts it up.
			var dir := Vector3(cos(e) * sin(a), sin(e), -cos(e) * cos(a))
			var world := origin + dir * FAR
			if cam.is_position_behind(world):
				continue
			_draw_cloud(cam.unproject_position(world), c["puffs"])

	# Flat two-tone cumulus: a cool underside offset down, sunlit puffs on top.
	func _draw_cloud(pos: Vector2, puffs: Array) -> void:
		for p in puffs:
			draw_circle(pos + p["off"] + Vector2(0.0, 5.0), p["r"], cfg.underside_color)
		for p in puffs:
			draw_circle(pos + p["off"], p["r"], cfg.cloud_color)
