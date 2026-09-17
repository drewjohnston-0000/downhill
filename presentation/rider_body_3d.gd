class_name RiderBody3D
extends Node3D
## 3D presentation of the rider. Runs the shared RiderAgent, reads the input
## actions, and puts the rider on the road: a deck with wheels that yaws with the
## board's heading, carrying a RiderCard3D (painted back-view card stack that faces
## the camera). The old placeholder box stays behind `card_rider` as the known-good
## baseline. Exposes state/config/road_path so the camera and debug overlay can read it.

## Height of this node's origin above the road surface.
@export var ride_height: float = 14.0
## True: deck + painted card stack. False: the original blue box.
@export var card_rider: bool = true
@export var deck_color: Color = Color(0.79, 0.48, 0.23)   ## warm orange-brown deck (clip)
@export var wheel_color: Color = Color(0.91, 0.54, 0.18)  ## orange urethane

var config: RiderConfig = null
var road_path: RoadPath = null
var state: RiderState = null
## Shared terrain height field (same object Terrain3D uses); set by main.gd.
var field: HeightField = null
## Sim-plane start position; set by main.gd before adding to the tree.
var start_position: Vector2 = Vector2.ZERO
## When true, the rider starts parked and must be kicked off (skate) to roll.
var start_at_rest: bool = false
## Fall-line y of the finish line; once past it the rider ignores input and brakes
## to a graceful stop instead of coasting off into the void. Set by main.gd.
var finish_y: float = -INF

var _agent: RiderAgent = null


## Has the rider crossed the finish line?
func has_finished() -> bool:
	return state != null and state.position.y <= finish_y


func _ready() -> void:
	if config == null:
		config = RiderConfig.new()
	_agent = RiderAgent.new(config, road_path, start_position, field, start_at_rest)
	state = _agent.state

	if card_rider:
		_build_deck_and_card()
	else:
		_build_box()
	_apply()


# The original placeholder: a blue box elongated along travel (-Z) so yaw reads.
func _build_box() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(20.0, 24.0, 46.0)
	_mesh(box, Color(0.2, 0.45, 0.85), Vector3.ZERO)


# A longboard deck on four wheels, resting on the road under this node's origin,
# with the card stack standing on the deck top. Deck length matches the old box.
func _build_deck_and_card() -> void:
	var ground := -ride_height  # local y of the road surface
	var wheel_r := 2.4
	var deck_t := 1.8
	var deck := BoxMesh.new()
	deck.size = Vector3(10.0, deck_t, 46.0)
	var deck_y := ground + wheel_r * 2.0 + deck_t * 0.5
	_mesh(deck, deck_color, Vector3(0.0, deck_y, 0.0))
	var wheel := CylinderMesh.new()
	wheel.top_radius = wheel_r
	wheel.bottom_radius = wheel_r
	wheel.height = 3.0
	for x in [-5.0, 5.0]:
		for z in [-15.0, 15.0]:
			var w := _mesh(wheel, wheel_color, Vector3(x, ground + wheel_r, z))
			w.rotation_degrees.z = 90.0  # cylinder axis along X: rolls along Z
	var card := RiderCard3D.new()
	card.position = Vector3(0.0, deck_y + deck_t * 0.5, 0.0)
	add_child(card)


func _mesh(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Cel look: a hard light/shadow terminator (banded), matte (no highlights).
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = mat
	add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	var input: RiderInput
	if has_finished():
		# Past the line: take over and brake straight to a graceful stop.
		input = RiderInput.new(0.0)
		input.brake = true
	else:
		input = RiderInput.new(Input.get_axis("steer_left", "steer_right"))
		input.push = Input.is_action_pressed("skate")
		input.tuck = Input.is_action_pressed("tuck")
		input.brake = Input.is_action_pressed("brake")
	state = _agent.advance(input, delta)
	_apply()


func _apply() -> void:
	var pos := Terrain3D.to_world(state.position) + Vector3.UP * ride_height
	global_position = pos
	var fwd := Vector3(cos(state.heading), 0.0, sin(state.heading))
	if fwd.length() > 0.001:
		look_at(pos + fwd, Vector3.UP)
