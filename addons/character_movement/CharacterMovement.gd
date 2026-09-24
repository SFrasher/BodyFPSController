class_name CharacterMovement
extends CharacterBody3D

## Resources
@export var facing_source: Node3D # Node whose global yaw sets direction and facing

## Direction
var input_dir: Vector2 # Stores WASD input (-1 to 1 on each axis)
var direction: Vector3 # Stores player direction

## Motion
@export var move_speed: float = 1.32 # Code-driven movement speed, m/s (matches walk loop clip's average net speed)

## Camera
@export var turn_speed: float = 8.0 # Modify body rotation toward facing yaw during movement
var camera_rotation: float = 0.0 # Facing yaw in radians; used to rotate input direction to facing-relative coordinates

func _physics_process(delta: float) -> void:
	_handle_input_direction(delta)
	_handle_rotation(delta)
	velocity = Vector3(direction.x * move_speed, velocity.y, direction.z * move_speed)
	move_and_slide()

func _handle_input_direction(_delta: float):
	input_dir = Input.get_vector("right", "left", "backward", "forward") # Reads WASD and returns Vector2
	direction = Vector3(input_dir.x, 0, input_dir.y) # Converts the Vector2 into a Vector3 without a vertical axis.

	if facing_source: # Checks that a facing source is wired before converting to facing rotated direction
		camera_rotation = facing_source.global_transform.basis.get_euler().y # Stores the yaw of the facing source
		direction = direction.rotated(Vector3.UP, camera_rotation).normalized() # Rotates player direction to facing yaw

func _handle_rotation(delta):
	if not facing_source:
		return

	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, camera_rotation, delta * turn_speed)
