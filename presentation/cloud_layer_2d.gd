class_name CloudLayer2D
extends CanvasLayer
## Soft cumulus clouds as a 2D painterly layer over the sky — the "2D skin" half of
## "3D space, 2D painterly skin". No shader, no texture: flat cloud shapes drawn in
## code (matching the scene's flat-shaded surfaces), parallax-scrolled by the 3D
## camera's yaw/pitch so they feel pinned to the sky at infinity. Confined to the
## upper sky so they don't composite over road geometry. Presentation only; it finds
## the active Camera3D each frame, so just add it to the tree after a camera exists.

@export var cloud_color: Color = Color(0.98, 0.97, 0.93)      ## sunlit top
@export var underside_color: Color = Color(0.80, 0.83, 0.90)  ## cool shaded base
@export var count: int = 6
@export var parallax_gain: float = 560.0  ## pixels of sky scroll per radian of camera turn
@export var rng_seed: int = 7

var _canvas: _Canvas


func _ready() -> void:
	_canvas = _Canvas.new()
	_canvas.layer_cfg = self
	add_child(_canvas)


# The drawing surface. Kept as an inner Node2D so the layer stays a plain CanvasLayer.
class _Canvas:
	extends Node2D
	var layer_cfg: CloudLayer2D
	var _clouds: Array = []
	var _scroll: Vector2 = Vector2.ZERO
	var _built := false

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var fwd := -cam.global_transform.basis.z
			var yaw := atan2(fwd.x, -fwd.z)
			var pitch := asin(clampf(fwd.y, -1.0, 1.0))
			# Vertical parallax is damped so cresting a rise never shoves clouds down
			# onto the horizon (where they'd wrongly composite over posts/road).
			_scroll = Vector2(yaw * layer_cfg.parallax_gain, -pitch * layer_cfg.parallax_gain * 0.4)
		queue_redraw()

	# Build clouds lazily once the viewport size is known.
	func _build(vs: Vector2) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = layer_cfg.rng_seed
		for _i in range(layer_cfg.count):
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
			_clouds.append({
				"fx": rng.randf(),                                 # position across the wrap field
				"y": rng.randf_range(0.06, 0.28) * vs.y,           # upper sky only
				"puffs": puffs,
			})
		_built = true

	func _draw() -> void:
		var vs := get_viewport_rect().size
		if not _built:
			_build(vs)
		var field := vs.x * 2.0
		for c in _clouds:
			var x0: float = fposmod(c["fx"] * field - _scroll.x, field)
			# Never let a cloud drift below the upper sky (keeps them off the horizon).
			var y: float = clampf(c["y"] + _scroll.y, -120.0, vs.y * 0.40)
			# Draw at the wrapped position and one field to the left, so a cloud
			# scrolling off one edge reappears on the other.
			for ox in [x0, x0 - field]:
				if ox < -260.0 or ox > vs.x + 260.0:
					continue
				_draw_cloud(Vector2(ox, y), c["puffs"])

	# Flat two-tone cumulus: a cool underside offset down, sunlit puffs on top.
	func _draw_cloud(pos: Vector2, puffs: Array) -> void:
		for p in puffs:
			draw_circle(pos + p["off"] + Vector2(0.0, 5.0), p["r"], layer_cfg.underside_color)
		for p in puffs:
			draw_circle(pos + p["off"], p["r"], layer_cfg.cloud_color)
