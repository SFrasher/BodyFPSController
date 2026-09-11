extends CharacterBody3D

## Resources
## animation_tree is read here only for root motion - this is a root-motion-
## driven controller, so animation_tree.get_root_motion_position()/rotation()
## IS this body's velocity/rotation source, not an animation-driving concern.
## Nothing else animation-related (blend params, hold state, turn-in-place,
## etc.) happens in this script - see LocomotionAnimator.gd and
## HoldStateController.gd, both sibling nodes under Player in Player.tscn.
## This script is movement/collision/physics only, nothing about the mesh.
@export var animation_tree: AnimationTree
@export var look_controller: Node3D

## Direction
var input_dir: Vector2 # Stores raw keyboard/gamepad input (-1 to 1 on each axis)
var direction: Vector3 # Stores camera-rotated direction (input mapped to world space relative to camera look)

## Motion
var root_velocity = Vector3() # Stores velocity from anim root motion
@export var root_motion_speed_multiplier: float = 1.0 # Modify anim speed
@export var turn_speed: float = 8.0 # Modify body rotation toward camera during movement
var camera_rotation: float = 0.0 # Camera's yaw angle in degrees; used to rotate input direction to camera-relative coordinates


func _ready() -> void:
	add_to_group("player")
	# Runs after AnimationTree's own (default-priority) update each frame, so
	# root_motion() below reads this frame's motion, not last frame's.
	process_priority = 100


func _process(delta: float) -> void:
	root_motion(delta, true)


func _physics_process(delta: float) -> void:
	_handle_input_direction(delta)
	_handle_rotation(delta)

	velocity = Vector3(root_velocity.x, velocity.y, root_velocity.z)
	move_and_slide()


func _handle_input_direction(_delta: float):
	input_dir = Input.get_vector("right", "left", "backward", "forward")
	direction = Vector3(input_dir.x, 0, input_dir.y)

	if look_controller:
		camera_rotation = look_controller.global_transform.basis.get_euler().y
		direction = direction.rotated(Vector3.UP, camera_rotation).normalized()

func _handle_rotation(delta):
	if not look_controller:
		return

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, camera_rotation, delta * turn_speed)


func root_motion(delta, enabled: bool):
	if !enabled:
		return

	#root motion code
	var root_pos = animation_tree.get_root_motion_position()
	var current_rotation = (animation_tree.get_root_motion_rotation_accumulator().inverse() * get_quaternion())
	root_velocity = current_rotation * root_pos / delta * root_motion_speed_multiplier
	var root_rotation =  animation_tree.get_root_motion_rotation() *2.0
	set_quaternion(get_quaternion() * root_rotation)
