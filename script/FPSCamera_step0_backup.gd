extends Node3D
## CHECKPOINT - verbatim copy of FPSCamera.gd before the Step 1 stabilization
## change (rotation decoupling). Not attached to any node. Restore by copying
## this back over res://script/FPSCamera.gd if Step 1 needs to be reverted.

@export var target_pivot: Marker3D
@export var follow_target: Node3D

@export_group("Look Parameters")
@export var pitch_max: float = 80.0
@export var pitch_min: float = -60.0
@export var mouse_sensitivity: float = 0.002
@export var gamepad_sensitivity: float = 2.5

@export_group("Weapon Aiming Parameter")
@export var target_pivot_x_offset: float = 2.45
@export var aim_speed: float = 500.0

var yaw: float = 0.0
var pitch: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if target_pivot:
		target_pivot.rotation_degrees = Vector3.ZERO
	if follow_target:
		yaw = follow_target.rotation.y


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch += event.relative.y * mouse_sensitivity


func _physics_process(delta: float) -> void:
	var gamepad_input := Vector2(Input.get_axis("lookright", "lookleft"), -Input.get_axis("lookdown", "lookup"))
	if gamepad_input.length() > 0.1:
		yaw += gamepad_input.x * gamepad_sensitivity * delta
		pitch += gamepad_input.y * gamepad_sensitivity * delta

	pitch = clamp(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

	rotation.y = yaw

	if target_pivot and follow_target:
		target_pivot.rotation_degrees.x = move_toward(
			target_pivot.rotation_degrees.x,
			rad_to_deg(pitch) + target_pivot_x_offset,
			aim_speed * delta
		)
		target_pivot.rotation_degrees.y = move_toward(
			target_pivot.rotation_degrees.y,
			clampf(follow_target.cam_angle_diff, -90, 90),
			aim_speed * delta
		)
