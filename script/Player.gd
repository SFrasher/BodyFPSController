extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var animation_tree: AnimationTree
@export var camera_target: Node3D
var is_strafing: bool = true
var turn_speed: float = 8.0
var gravity = 9.8

#root motion parameter
var root_velocity = Vector3()
var root_motion_speed_multiplier: float = 1.0

### PLAYER DIRECTION
var input_dir: Vector2
var direction: Vector3

var currentspeed = Vector2.ZERO
var strafe_acceleration = 3
var targetspeed
var strafe_input:Vector2 = Vector2.ZERO
var camera_rotation: float = 0.0

## 'True' to enable Turn In Place. Off for now (2026-09-03) - the body
## never actually turns during TIP (the clips have no root motion track, only
## the mesh visually turns via the Hips bone), and fixing that properly
## turned into more of a rabbit hole than it was worth today. Parked rather
## than shipped half-broken; see project notes for what was tried.
@export var enable_tip: bool = false

## Data-driven armed/unarmed switch. See HoldStateConfig.gd and
## ik-and-player-conversion-map.md's "unarmed conversion" section for why
## these specific modifiers are the ones that get gated. Two states for now;
## torch (or anything else) is a third .tres later, no new code branches.
@export var armed_state: HoldStateConfig = preload("res://HoldStates/armed_state.tres")
@export var unarmed_state: HoldStateConfig = preload("res://HoldStates/unarmed_state.tres")
@export var current_hold_state: HoldStateConfig

var weapon_r_upper_arm_mod: CopyTransformModifier3D
var weapon_r_hand_mod: CopyTransformModifier3D
var lh_weapon_ik_mod: TwoBoneIK3D
var lh_weapon_copy_mod: CopyTransformModifier3D
var weapon_mesh_node: Node3D
var spine_ccdik_mod: CCDIK3D
var spine_copy_mod: CopyTransformModifier3D
var spine_twist_mod: BoneTwistDisperser3D
var cam_angle_diff = float()
var turn_in_place: bool = false
var tip_timer: float = 0.0
var tip_cool_down: float = 0.5


func _ready() -> void:
	add_to_group("player")
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()
	weapon_r_upper_arm_mod = get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D")
	weapon_r_hand_mod = get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D2")
	lh_weapon_ik_mod = get_node_or_null("Model/GeneralSkeleton/LHTwoBoneIK3D")
	lh_weapon_copy_mod = get_node_or_null("Model/GeneralSkeleton/LHCopyTransformModifier3D2")
	weapon_mesh_node = get_node_or_null("Model/GeneralSkeleton/RShoulderBoneAttachment3D2/WeaponHolder/Gun")
	spine_ccdik_mod = get_node_or_null("Model/GeneralSkeleton/SpineCCDIK3D")
	spine_copy_mod = get_node_or_null("Model/GeneralSkeleton/SpineCopyTransformModifier3D")
	spine_twist_mod = get_node_or_null("Model/GeneralSkeleton/SpineBoneTwistDisperser3D")
	_apply_hold_state(current_hold_state if current_hold_state else unarmed_state)


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


## Applies a HoldStateConfig: gates the armed-only modifiers, sets the
## rifle-grip finger blend, and shows/hides the gun mesh. Disabling/enabling
## these (never deleting the nodes) is deliberate - both states stay
## reachable and both survive a scene save. See ik-and-player-conversion-
## map.md's "unarmed conversion" section for why these are the right nodes.
func _apply_hold_state(state: HoldStateConfig) -> void:
	if state == null:
		return
	if weapon_r_upper_arm_mod:
		weapon_r_upper_arm_mod.active = state.use_right_arm_weapon_ik
	if weapon_r_hand_mod:
		weapon_r_hand_mod.active = state.use_right_arm_weapon_ik
	if lh_weapon_ik_mod:
		lh_weapon_ik_mod.active = state.use_left_arm_weapon_ik
	if lh_weapon_copy_mod:
		lh_weapon_copy_mod.active = state.use_left_arm_weapon_ik
	if spine_ccdik_mod:
		spine_ccdik_mod.active = state.use_spine_aim_ik
	if spine_copy_mod:
		spine_copy_mod.active = state.use_spine_aim_ik
	if spine_twist_mod:
		spine_twist_mod.active = state.use_spine_aim_ik
	animation_tree.set("parameters/FingersBlend2/blend_amount", state.finger_grip_blend)
	if weapon_mesh_node:
		weapon_mesh_node.visible = state.weapon_visible
	current_hold_state = state


## Debug-only toggle until a real equip/pickup system exists. Same pattern as
## DebugViewToggle.gd's V key: raw keycode check in _unhandled_input, no
## input-map action needed for a temporary dev toggle.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		var next_state := unarmed_state if current_hold_state == armed_state else armed_state
		_apply_hold_state(next_state)


func _process(delta: float) -> void:
	turn_in_place = animation_tree.get("parameters/TIP/active") and !(direction != Vector3.ZERO)
	root_motion(delta, true)
	handle_strafe_animation(delta)
	handle_turn_in_place(delta)


func _physics_process(delta: float) -> void:
	if direction != Vector3.ZERO:
		tip_timer = 0.0
	else:
		tip_timer += delta

	_handle_input_direction(delta)
	_handle_rotation(delta)
	angle_rotation()

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	velocity = Vector3(root_velocity.x, velocity.y, root_velocity.z)
	move_and_slide()


func _handle_input_direction(_delta: float):
	input_dir = Input.get_vector("right", "left", "backward", "forward")
	direction = Vector3(input_dir.x, 0, input_dir.y)
	
	if camera_target:
		camera_rotation = camera_target.global_transform.basis.get_euler().y
		direction = direction.rotated(Vector3.UP, camera_rotation).normalized()

func _handle_rotation(delta):
	if not camera_target:
		return
	
	if direction != Vector3.ZERO:
		if is_strafing:
			rotation.y = lerp_angle(rotation.y, camera_rotation, delta * turn_speed)
		else:
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), turn_speed * delta)


func root_motion(delta, enabled: bool):
	if !enabled:
		return

	#root motion code
	var root_pos = animation_tree.get_root_motion_position()
	var current_rotation = (animation_tree.get_root_motion_rotation_accumulator().inverse() * get_quaternion())
	root_velocity = current_rotation * root_pos / delta * root_motion_speed_multiplier
	var root_rotation =  animation_tree.get_root_motion_rotation() *2.0
	set_quaternion(get_quaternion() * root_rotation)

func angle_rotation():
	camera_rotation = camera_target.global_transform.basis.get_euler().y
	var cam_direction = Vector3.BACK.rotated(Vector3.UP, camera_rotation)
	var forward_direction = global_transform.basis.z.normalized() 

	if is_strafing:
		cam_angle_diff = rad_to_deg(forward_direction.signed_angle_to(cam_direction, Vector3.UP))
	else:
		if direction != Vector3.ZERO:
			cam_angle_diff = 0.0
		else:
			if tip_timer > tip_cool_down:
				cam_angle_diff = rad_to_deg(forward_direction.signed_angle_to(cam_direction, Vector3.UP))


func handle_strafe_animation(delta):
	#handle strafe blend
	targetspeed = Vector2(input_dir.x, input_dir.y).normalized()
	currentspeed = currentspeed.move_toward(-targetspeed, strafe_acceleration * delta)
	strafe_input = Vector2(currentspeed.x, -currentspeed.y)
	animation_tree.set("parameters/WALK/blend_position", strafe_input)


func handle_turn_in_place(_delta):
	#Handle turn in place
	if !enable_tip:
		return

	if direction != Vector3.ZERO:
		animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	else:
		if tip_timer > tip_cool_down:
			if !turn_in_place:
				if cam_angle_diff >= 60:
					animation_tree.set("parameters/TIP Transition/transition_request", "left")
					animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

				elif cam_angle_diff <= -70:
					animation_tree.set("parameters/TIP Transition/transition_request", "right")
					animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
