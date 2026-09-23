extends CharacterBody3D

## Resources
@export var animation_tree: AnimationTree # Stores the AnimationTree
@export var look_controller: Node3D # Store the LookController

## Direction
var input_dir: Vector2 # Stores WASD input (-1 to 1 on each axis)
var direction: Vector3 # Stores player direction

## Motion
var root_velocity = Vector3() # Stores velocity from anim root motion
@export var root_motion_speed_multiplier: float = 1.0 # Modify anim speed

## Camera
@export var turn_speed: float = 8.0 # Modify body rotation toward camera during movement
var camera_rotation: float = 0.0 # Camera's yaw angle in radians; used to rotate input direction to camera-relative coordinates

func _ready() -> void: 
	process_priority = 100 #Makes this script's _process() run after AnimationTree's, so it reads this frame's root motion instead of last frame's.

func _process(delta: float) -> void:
	root_motion(delta, true) # calls root_motion() every frame, after AnimationTree updates to read this frame's motion.

func _physics_process(delta: float) -> void:
	_handle_input_direction(delta)
	_handle_rotation(delta)
	velocity = Vector3(root_velocity.x, velocity.y, root_velocity.z)
	move_and_slide()

func _handle_input_direction(_delta: float): 
	input_dir = Input.get_vector("right", "left", "backward", "forward") # Reads WASD and returns Vector2
	direction = Vector3(input_dir.x, 0, input_dir.y) # Converts the Vector2 into a Vector3 without a vertical axis.

	if look_controller: # Checks that a LookController is wired before converting to camera rotated direction
		camera_rotation = look_controller.global_transform.basis.get_euler().y # Stores the yaw of LookController 
		direction = direction.rotated(Vector3.UP, camera_rotation).normalized() # Rotates player direction to yaw of LookController

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
