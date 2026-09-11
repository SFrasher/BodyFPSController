extends CharacterBody3D

## Resources
@export var animation_tree: AnimationTree
@export var look_controller: Node3D
@export var armed_state: HoldStateConfig = preload("res://HoldStates/armed_state.tres") # Armed stance config
@export var unarmed_state: HoldStateConfig = preload("res://HoldStates/unarmed_state.tres") # Unarmed stance config
@export var current_hold_state: HoldStateConfig # Currently active hold state

## Direction
var input_dir: Vector2 # Stores raw keyboard/gamepad input (-1 to 1 on each axis)
var direction: Vector3 # Stores camera-rotated direction (input mapped to world space relative to camera look)

## Motion
var root_velocity = Vector3() # Stores velocity from anim root motion
@export var root_motion_speed_multiplier: float = 1.0 # Modify anim speed
@export var turn_speed: float = 8.0 # Modify body rotation toward camera during movement
@export var gait_blend_speed: float = 6.0 # How fast gait transitions between walk/jog
var gait_blend: float = 0.0 # Current gait blend amount (0=walk, 1=jog)

## Strafe
var currentspeed = Vector2.ZERO # Current animation blend space values (X/Y); lerps toward targetspeed to smooth animation transitions
var strafe_acceleration = 3 # Controls how quickly currentspeed reaches targetspeed; prevents animation pops when input direction changes suddenly
var targetspeed # Desired animation blend space values we're accelerating toward based on player input direction
var strafe_input: Vector2 = Vector2.ZERO # Normalized player input (-1 to 1 on each axis); fed into animation tree after camera rotation
var camera_rotation: float = 0.0 # Camera's yaw angle in degrees; used to rotate input direction to camera-relative coordinates

## Hold State - node references and apply logic live in HoldStateController
## (script/HoldStateController.gd) instead of here. It's a plain object
## Player.gd instantiates and drives, not a scene node, so pulling this out
## didn't need any Player.tscn changes. armed_state/unarmed_state/
## current_hold_state stay exported here since this is the node the
## Inspector actually shows.
var hold_state := HoldStateController.new()

## Turn In Place - all other state and logic live in TurnInPlaceController
## (script/TurnInPlaceController.gd) for the same reason as hold_state
## above. cam_angle_diff stays here (not moved into the controller) because
## LookController.gd reads it externally as body.cam_angle_diff for its
## neck-turn clamp - don't rename or relocate it without updating that too.
var cam_angle_diff = float() # Angle between body facing and camera direction
var tip := TurnInPlaceController.new()


func _ready() -> void:
	add_to_group("player")
	# Runs after AnimationTree's own (default-priority) update each frame - see
	# TurnInPlaceController's doc comment for why this matters.
	process_priority = 100
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()
	tip.setup(self)
	hold_state.setup(self, animation_tree)
	var initial_state := current_hold_state if current_hold_state else unarmed_state
	hold_state.apply_state(initial_state)
	current_hold_state = initial_state


## Registers the baked UUS animation library on AnimationPlayer at runtime
## instead of baking the reference into Player.tscn. Player.tscn's live IK
## modifiers bake current bone pose into the scene on every editor save, so
## data-only wiring like this is kept out of the scene file on purpose.
func _register_uus_animation_library() -> void:
	var anim_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if anim_player.has_animation_library("UUS"):
		return
	var uus_lib := load("res://AnimLib/UUS.tres") as AnimationLibrary
	if uus_lib:
		anim_player.add_animation_library("UUS", uus_lib)


## Debug-only toggle until a real equip/pickup system exists. Same pattern as
## DebugViewToggle.gd's V key: raw keycode check in _unhandled_input, no
## input-map action needed for a temporary dev toggle.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		var next_state := unarmed_state if current_hold_state == armed_state else armed_state
		hold_state.apply_state(next_state)
		current_hold_state = next_state


func _process(delta: float) -> void:
	tip.update_active_state(animation_tree, direction)
	root_motion(delta, true)
	handle_strafe_animation(delta)
	handle_gait(delta)
	tip.handle_trigger(animation_tree, cam_angle_diff, direction)
	tip.update_body_rotation(self, animation_tree)


## Smoothly blends the AnimationTree's Gait node toward jogging while [sprint] is
## held, walking when it's not. Doesn't touch movement speed directly - root
## motion already reads whatever pose Gait outputs, so blending toward the jog
## clips' larger per-frame translation is what actually speeds the body up.
func handle_gait(delta):
	var target_gait: float = 1.0 if Input.is_action_pressed("sprint") else 0.0
	gait_blend = move_toward(gait_blend, target_gait, gait_blend_speed * delta)
	animation_tree.set("parameters/Gait/blend_amount", gait_blend)


func _physics_process(delta: float) -> void:
	tip.update_timer(delta, direction != Vector3.ZERO)

	_handle_input_direction(delta)
	_handle_rotation(delta)
	if look_controller:
		cam_angle_diff = tip.compute_cam_angle(self, look_controller)

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


func handle_strafe_animation(delta):
	#handle strafe blend
	targetspeed = Vector2(input_dir.x, input_dir.y).normalized()
	currentspeed = currentspeed.move_toward(-targetspeed, strafe_acceleration * delta)
	strafe_input = Vector2(currentspeed.x, -currentspeed.y)
	animation_tree.set("parameters/WALK/blend_position", strafe_input)
	# JOG mirrors WALK's 9-point directional layout one-for-one (see the AnimationTree
	# resource), so it tracks the same input - only the Gait blend_amount (set in
	# handle_gait()) decides which one is actually audible in the final pose.
	animation_tree.set("parameters/JOG/blend_position", strafe_input)
