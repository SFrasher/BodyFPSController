class_name CharacterAnimator
extends Node

## Drives the character's animation: locomotion blending and turn-in-place.
## Sits alongside CharacterRigger, which configures the rig/equipment state
## the animation plays through. Sibling node under Player.

@export var gait_blend_speed: float = 6.0

var player: CharacterBody3D
var animation_tree: AnimationTree

# Locomotion
var gait_blend: float = 0.0
var currentspeed = Vector2.ZERO
var strafe_acceleration = 3
var targetspeed
var strafe_input: Vector2 = Vector2.ZERO

# Turn in place
var tip_cool_down: float = 0.5
var tip_timer: float = 0.0
var turn_in_place: bool = false
var tip_skeleton: Skeleton3D
var tip_hips_idx: int = -1
var tip_prev_raw_hips_rot: Quaternion = Quaternion.IDENTITY
var tip_frozen_hips_rot: Quaternion = Quaternion.IDENTITY
var tip_was_active: bool = false
var tip_was_tracking: bool = false


func _ready() -> void:
	player = get_parent()
	animation_tree = player.animation_tree
	process_priority = 200
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()

	tip_skeleton = player.get_node_or_null("Model/GeneralSkeleton")
	if tip_skeleton:
		tip_hips_idx = tip_skeleton.find_bone("Hips")


func _register_uus_animation_library() -> void:
	var anim_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if anim_player.has_animation_library("UUS"):
		return
	var uus_lib := load("res://AnimLib/UUS.tres") as AnimationLibrary
	if uus_lib:
		anim_player.add_animation_library("UUS", uus_lib)


func _process(delta: float) -> void:
	update_active_state(player.direction)
	handle_strafe_animation(delta)
	handle_gait(delta)
	if player.look_controller:
		handle_trigger(
			player.look_controller.cam_angle_diff,
			player.look_controller.neck_clamp_positive_deg,
			player.look_controller.neck_clamp_negative_deg,
			player.direction
		)
	update_body_rotation()


func handle_gait(delta):
	var target_gait: float = 1.0 if Input.is_action_pressed("sprint") else 0.0
	gait_blend = move_toward(gait_blend, target_gait, gait_blend_speed * delta)
	animation_tree.set("parameters/Gait/blend_amount", gait_blend)


func handle_strafe_animation(delta):
	targetspeed = Vector2(player.input_dir.x, player.input_dir.y).normalized()
	currentspeed = currentspeed.move_toward(-targetspeed, strafe_acceleration * delta)
	strafe_input = Vector2(currentspeed.x, -currentspeed.y)
	animation_tree.set("parameters/WALK/blend_position", strafe_input)
	animation_tree.set("parameters/JOG/blend_position", strafe_input)


func _physics_process(delta: float) -> void:
	update_timer(delta, player.direction != Vector3.ZERO)


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
				animation_tree.set("parameters/TIP Transition/transition_request", "left")
				animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			elif cam_angle_diff <= fire_negative_deg:
				animation_tree.set("parameters/TIP Transition/transition_request", "right")
				animation_tree.set("parameters/TIP/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func update_body_rotation() -> void:
	if tip_hips_idx < 0 or tip_skeleton == null:
		return
	var tip_active: bool = animation_tree.get("parameters/TIP/active")
	if tip_active:
		var current_raw := tip_skeleton.get_bone_pose_rotation(tip_hips_idx)
		if not tip_was_active:
			tip_frozen_hips_rot = current_raw
			tip_prev_raw_hips_rot = current_raw
			tip_was_tracking = false
		else:
			var fade_in_remaining: float = animation_tree.get("parameters/TIP/fade_in_remaining")
			var fade_out_remaining: float = animation_tree.get("parameters/TIP/fade_out_remaining")
			var at_full_weight: bool = fade_in_remaining <= 0.0 and fade_out_remaining <= 0.0
			if at_full_weight:
				if tip_was_tracking:
					var delta_rot: Quaternion = tip_prev_raw_hips_rot.inverse() * current_raw
					var twist_axis := Vector3(delta_rot.x, delta_rot.y, delta_rot.z).project(Vector3.UP)
					var twist := Quaternion(twist_axis.x, twist_axis.y, twist_axis.z, delta_rot.w).normalized()
					player.rotation.y += 2.0 * atan2(twist.y, twist.w)
				tip_prev_raw_hips_rot = current_raw
				tip_was_tracking = true
		tip_skeleton.set_bone_pose_rotation(tip_hips_idx, tip_frozen_hips_rot)
		tip_was_active = true
	else:
		tip_was_active = false
		tip_was_tracking = false
