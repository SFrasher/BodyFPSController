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

## 'True' to enable Turn In Place. Re-enabled 2026-09-04 with the Hips delta-
## extraction fix below - the TIP clips carry no root motion track, so without
## this the body itself never turns, only the mesh (via the Hips bone). See
## _update_tip_body_rotation() and project notes' "Turn-in-place body rotation"
## section. Needs real play verification, not just tool-simulated testing -
## that's exactly what was skipped last time this was attempted.
@export var enable_tip: bool = true

## Data-driven armed/unarmed switch. See HoldStateConfig.gd and
## ik-and-player-conversion-map.md's "unarmed conversion" section for why
## these specific modifiers are the ones that get gated. Two states for now;
## torch (or anything else) is a third .tres later, no new code branches.
@export var armed_state: HoldStateConfig = preload("res://HoldStates/armed_state.tres")
@export var unarmed_state: HoldStateConfig = preload("res://HoldStates/unarmed_state.tres")
@export var current_hold_state: HoldStateConfig

## Gait switching between WALK and JOG. Hold [sprint] (already bound to Left Ctrl /
## joypad button 1 in the input map, previously unused) to jog; release for walk.
## Smoothed rather than snapped straight to 0/1 so the crossfade doesn't pop - the
## AnimationTree's new "Gait" Blend2 node (WALK on input 0, JOG on input 1) has
## sync = true, so Godot keeps both blend spaces advancing together even while one
## has zero weight, which is what keeps the transition from skating. See the
## Descent-scoped roadmap's "Phase 2 - jog core" for why this exists. Steady-state
## loop only for this pass - jog starts/stops/pivots are Phase 3, not wired yet.
@export var gait_blend_speed: float = 6.0
var gait_blend: float = 0.0

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

## Turn-in-place body rotation. The TIP clips (A_N_TurnInPlace_{L,R}-090) have
## no %GeneralSkeleton:Root track, so AnimationTree's root motion is zero for
## them - only the Hips bone (parented directly to Root) carries the real
## turn, as a full local rotation. Each frame the animation plays, this reads
## how much Hips actually rotated since last frame and applies that same
## delta to the body's real transform, then freezes Hips back to its pre-turn
## pose so the rotation only ever shows up once (on the body), not doubled
## onto the bone. Requires Player.process_priority above AnimationTree's
## default (0) so this reads/overwrites Hips AFTER animation applies this
## frame's pose, not before - set in _ready().
var tip_skeleton: Skeleton3D
var tip_hips_idx: int = -1
var tip_prev_raw_hips_rot: Quaternion = Quaternion.IDENTITY
var tip_frozen_hips_rot: Quaternion = Quaternion.IDENTITY
var tip_was_active: bool = false
## True only once the OneShot has reached full weight (past its fade-in,
## before its fade-out) and a tracking baseline has been captured there.
## Rotation deltas are only ever summed onto the body while this is true -
## see _update_tip_body_rotation()'s doc comment for why.
var tip_was_tracking: bool = false


func _ready() -> void:
	add_to_group("player")
	# Runs after AnimationTree's own (default-priority) update each frame - see
	# the tip_* vars' doc comment above.
	process_priority = 100
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()
	tip_skeleton = get_node_or_null("Model/GeneralSkeleton")
	if tip_skeleton:
		tip_hips_idx = tip_skeleton.find_bone("Hips")
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
	# Both the CCDIK target and the CopyTransformModifier reference point at
	# whichever pivot the state calls for - full pitch+yaw aim gimbal
	# (TargetPivot/SpineTargetWeaponAim) when armed, pitch-only
	# (PitchPivot/SpineTargetPitchOnly) when unarmed. Paths are relative to
	# each modifier's own node, matching what's baked into Player.tscn.
	var spine_target_path := NodePath("../../../PitchPivot/SpineTargetPitchOnly" if state.spine_pitch_only else "../../../TargetPivot/SpineTargetWeaponAim")
	if spine_ccdik_mod:
		spine_ccdik_mod.active = state.use_spine_aim_ik
		spine_ccdik_mod.set("settings/0/target_node", spine_target_path)
	if spine_copy_mod:
		spine_copy_mod.active = state.use_spine_aim_ik
		spine_copy_mod.set("settings/0/reference_node", spine_target_path)
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
	handle_gait(delta)
	handle_turn_in_place(delta)
	_update_tip_body_rotation()


## Smoothly blends the AnimationTree's Gait node toward jogging while [sprint] is
## held, walking when it's not. Doesn't touch movement speed directly - root
## motion already reads whatever pose Gait outputs, so blending toward the jog
## clips' larger per-frame translation is what actually speeds the body up.
func handle_gait(delta):
	var target_gait: float = 1.0 if Input.is_action_pressed("sprint") else 0.0
	gait_blend = move_toward(gait_blend, target_gait, gait_blend_speed * delta)
	animation_tree.set("parameters/Gait/blend_amount", gait_blend)


## See tip_* vars' doc comment above for the full explanation. Must run after
## AnimationTree has applied this frame's pose (Player.process_priority = 100
## guarantees that), so tip_skeleton.get_bone_pose_rotation() reads the
## animation's real, current-frame Hips rotation.
func _update_tip_body_rotation() -> void:
	if tip_hips_idx < 0 or tip_skeleton == null:
		return
	var tip_active: bool = animation_tree.get("parameters/TIP/active")
	if tip_active:
		var current_raw := tip_skeleton.get_bone_pose_rotation(tip_hips_idx)
		if not tip_was_active:
			# Turn just started this frame - capture the baseline, no delta yet.
			tip_frozen_hips_rot = current_raw
			tip_prev_raw_hips_rot = current_raw
			tip_was_tracking = false
		else:
			# AnimationNodeOneShot (mix_mode = BLEND) crossfades with whatever
			# is underneath (idle) during its fade_in/fade_out windows, so the
			# live skeleton pose there is a BLEND, not the raw clip - reading a
			# delta from it during either fade means capturing the fade's own
			# blend-toward-idle motion as if it were more turning. That's what
			# made the body visibly unwind back toward its start facing at the
			# end of every turn (found 2026-09-04 via frame-by-frame logging:
			# Hips' raw pose smoothly reverted to near-identity over exactly
			# fadeout_time while active was still true). Only sum the delta
			# while at full weight - past fade-in, before fade-out.
			var fade_in_remaining: float = animation_tree.get("parameters/TIP/fade_in_remaining")
			var fade_out_remaining: float = animation_tree.get("parameters/TIP/fade_out_remaining")
			var at_full_weight: bool = fade_in_remaining <= 0.0 and fade_out_remaining <= 0.0
			if at_full_weight:
				if tip_was_tracking:
					var delta_rot: Quaternion = tip_prev_raw_hips_rot.inverse() * current_raw
					# Hips carries real mocap weight-shift/bounce alongside the
					# turn - a full quaternion multiply would bake that tilt/
					# roll onto the body permanently. Swing-twist decompose
					# delta_rot around UP and apply only the twist (yaw)
					# component; the body should turn, not tip over.
					var twist_axis := Vector3(delta_rot.x, delta_rot.y, delta_rot.z).project(Vector3.UP)
					var twist := Quaternion(twist_axis.x, twist_axis.y, twist_axis.z, delta_rot.w).normalized()
					rotation.y += 2.0 * atan2(twist.y, twist.w)
				else:
					# Fade-in just finished - start tracking fresh from here so
					# the fade-in's own damped/blended motion isn't counted.
					pass
				tip_prev_raw_hips_rot = current_raw
				tip_was_tracking = true
			# else: fading in or out - don't track, don't update
			# tip_prev_raw_hips_rot (Hips stays frozen below regardless, so
			# there's nothing to desync when tracking resumes).
		tip_skeleton.set_bone_pose_rotation(tip_hips_idx, tip_frozen_hips_rot)
		tip_was_active = true
	else:
		tip_was_active = false
		tip_was_tracking = false


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
	# JOG mirrors WALK's 9-point directional layout one-for-one (see the AnimationTree
	# resource), so it tracks the same input - only the Gait blend_amount (set in
	# handle_gait()) decides which one is actually audible in the final pose.
	animation_tree.set("parameters/JOG/blend_position", strafe_input)


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
