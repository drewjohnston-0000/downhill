class_name RiderCard3D
extends Node3D
## The rider as a stack of flat painted cards: a back view (legs, torso, skirt, head,
## hair, bag) drawn as separate SVG layers on the same 64x128 canvas, each on its own
## Sprite3D, stacked a hair apart in depth. The stack always faces the camera around
## the vertical axis (a body facing its travel line, seen from behind), while the
## deck underneath belongs to RiderBody3D and yaws with the board's heading — so in a
## carve the board slips under an upright body, as in the reference clip.
##
## This is the "2-D skin over 3-D space" thesis applied to the character. The paint is
## placeholder and swappable per layer; the point of the stack is that hair, skirt and
## bag are separate nodes, ready to be driven by springs (secondary motion) later.
## Presentation only: no sim, no input.

const CANVAS_HEIGHT_PX := 1024.0  ## the SVG layers render at 512x1024
const FEET_FROM_BOTTOM_PX := 32.0  ## the shoes' soles sit 4 canvas units (x8) above the edge

## Back-to-front draw order; each layer sits `layer_gap` nearer the camera than the last.
const LAYERS := ["legs", "torso", "skirt", "head", "hair", "bag"]

@export var rider_height: float = 80.0  ## world units from canvas top to bottom
@export var layer_gap: float = 0.35     ## depth between consecutive cards (world units)

var _cam: Camera3D = null


func _ready() -> void:
	var px := rider_height / CANVAS_HEIGHT_PX
	var lift := rider_height * 0.5 - FEET_FROM_BOTTOM_PX * px  # soles on the origin
	for i in range(LAYERS.size()):
		var sprite := Sprite3D.new()
		sprite.name = LAYERS[i].capitalize()
		sprite.texture = load("res://assets/rider/%s.svg" % LAYERS[i])
		sprite.pixel_size = px
		sprite.position = Vector3(0.0, lift, layer_gap * float(i))
		# Painted colour is final (no scene lighting on a flat card), but the card still
		# cuts a real silhouette: alpha discard keeps the depth buffer and shadow pass
		# honest, so cards sort against the world and cast a proper shadow.
		sprite.shaded = false
		sprite.double_sided = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(sprite)


func _process(_delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return
	# Face the camera around Y only (stay upright). A Sprite3D shows on its +Z side, so
	# point local -Z away from the camera.
	var to_cam := _cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.001:
		return
	global_basis = Basis.looking_at(-to_cam.normalized(), Vector3.UP)
