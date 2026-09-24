class_name CharacterAnimator
extends Node3D

## Drives the character's animation: locomotion blending and turn-in-place.
## Sits alongside CharacterRigger, which configures the rig/equipment state
## the animation plays through. Sibling node under Player.

@export var gait_blend_speed: float = 6.0

var player: CharacterBody3D
@export var animation_tree: AnimationTree
@export var look_controller: Node3D
@export var movement: CharacterMovement

# Locomotion
var gait_blend: float = 0.0
var currentspeed = Vector2.ZERO
var strafe_acceleration = 3
var targetspeed
var strafe_input: Vector2 = Vector2.ZERO

# Turn in place
@export var tip_turn_angle_deg: float = 90.0 # Fixed turn amount - measured off the wired clips' own Hips rotation (stopgap until Root-motion rotation is added to the retargeting pipeline)
@export var tip_turn_rate_deg_s: float = 33.0 # Code-driven turn rate while TIP plays (placeholder, tune to feel)
var tip_cool_down: float = 0.5
var tip_timer: float = 0.0
var turn_in_place: bool = false
var tip_skeleton: Skeleton3D
var tip_hips_idx: int = -1
var tip_frozen_hips_rot: Quaternion = Quaternion.IDENTITY
var tip_was_active: bool = false
var tip_turn_sign: float = 0.0
var tip_target_rotation: float = 0.0


func _ready() -> void:
	player = get_parent()
	process_priority = 200
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()

	tip_skeleton = get_node_or_null("Model/GeneralSkeleton")
	if tip_skeleton:
		tip_hips_idx = tip_skeleton.find_bone("Hips")


func _register_uus_animation_library() -> void:
	var anim_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if anim_player.has_animation_library("UUS"):
		return
	var uus_lib := load("res://AnimLib/UUS.tres") as AnimationLibrary
	if uus_lib:
		anim_player.add_animation_library("UUS", uus_lib)


func _process(delta: float) -> void:
	update_active_state(movement.direction)
	handle_strafe_animation(delta)
	handle_gait(delta)
	if look_controller:
		handle_trigger(
			look_controller.cam_angle_diff,
			look_controller.neck_clamp_positive_deg,
			look_controller.neck_clamp_negative_deg,
			movement.direction
		)
	update_body_rotation(delta)


func handle_gait(delta):
	var target_gait: float = 1.0 if Input.is_action_pressed("sprint") else 0.0
	gait_blend = move_toward(gait_blend, target_gait, gait_blend_speed * delta)
	animation_tree.set("parameters/Gait/blend_amount", gait_blend)


func handle_strafe_animation(delta):
	targetspeed = Vector2(movement.input_dir.x, movement.input_dir.y).normalized()
	currentspeed = currentspeed.move_toward(-targetspeed, strafe_acceleration * delta)
	strafe_input = Vector2(currentspeed.x, -currentspeed.y)
	animation_tree.set("parameters/WALK/blend_position", strafe_input)
	animation_tree.set("parameters/JOG/blend_position", strafe_input)


func _physics_process(delta: float) -> void:
	update_timer(delta, movement.direction != Vector3.ZERO)


func update_timer(delta: float, has_input: bool) -> void:
	if has_input:
		tip_timer = 0.0
	else:
		tip_timer += delta


func update_active_state(direction: Vector3) -> void:
	turn_in_place = animation_tree.get("parameters/TIP/active") and !(direction != Vector3.ZERO)


func handle_trigger(cam_angle_diff: float, fire_positive_deg: float, fire_negative_deg: float, direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	else:
		if tip_timer > tip_cool_down and not turn_in_place:
			if cam_angle_diff >= fire_positive_deg:
				tip_turn_sign = 1.0
				animation_tree.set("parameters/TIP Transition/transition_request", "left")
				animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			elif cam_angle_diff <= fire_negative_deg:
				tip_turn_sign = -1.0
				animation_tree.set("parameters/TIP Transition/transition_request", "right")
				animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func update_body_rotation(delta: float) -> void:
	if tip_hips_idx < 0 or tip_skeleton == null:
		return
	var tip_active: bool = animation_tree.get("parameters/TIP/active")
	if tip_active:
		if not tip_was_active:
			tip_frozen_hips_rot = tip_skeleton.get_bone_pose_rotation(tip_hips_idx)
			tip_target_rotation = player.rotation.y + deg_to_rad(tip_turn_angle_deg) * tip_turn_sign
		else:
			player.rotation.y = move_toward(player.rotation.y, tip_target_rotation, deg_to_rad(tip_turn_rate_deg_s) * delta)
		tip_skeleton.set_bone_pose_rotation(tip_hips_idx, tip_frozen_hips_rot)
		tip_was_active = true
	else:
		tip_was_active = false
