class_name RiderBody3D
extends Node3D
## 3D presentation of the rider. Runs the shared RiderAgent (same sim as the 2D
## game), reads the same input actions, and drops a placeholder box on the road.
## Exposes state/config/road_path so the camera and debug overlay can read it,
## exactly like the 2D RiderNode.

## Height of the box centre above the road surface.
@export var ride_height: float = 14.0

var config: RiderConfig = null
var road_path: RoadPath = null
var state: RiderState = null
## Shared downhill profile (same object Terrain3D uses); set by main3d.
var elevation: ElevationProfile = null
## Sim-plane start position; set by main3d before adding to the tree.
var start_position: Vector2 = Vector2.ZERO
## When true, the rider starts parked and must be kicked off (skate) to roll.
var start_at_rest: bool = false

var _agent: RiderAgent = null


func _ready() -> void:
	if config == null:
		config = RiderConfig.new()
	_agent = RiderAgent.new(config, road_path, start_position, elevation, start_at_rest)
	state = _agent.state

	var box := BoxMesh.new()
	box.size = Vector3(20.0, 24.0, 46.0)  # elongated along travel (-Z) so yaw reads
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.45, 0.85)
	mesh.material_override = mat
	add_child(mesh)
	_apply()


func _physics_process(delta: float) -> void:
	var steer: float = Input.get_axis("steer_left", "steer_right")
	var input := RiderInput.new(steer)
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
