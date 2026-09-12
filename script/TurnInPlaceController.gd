class_name TurnInPlaceController
extends RefCounted

## Turn-in-place logic, pulled out of Player.gd. Not a scene node - Player.gd
## instantiates and drives this directly (see Player.gd's `tip` var), so
## this split didn't require any Player.tscn changes.
##
## The TIP mocap clips (A_N_TurnInPlace_L-180/R-180, swapped to their 90deg
## variants) have no root-motion track, so AnimationTree contributes zero
## root motion while they play - only the Hips bone visibly turns. This
## reads how much Hips' rotation changed since last frame and applies that
## same delta (yaw only, swing-twist decomposed) to the actual body
## rotation, then holds Hips frozen at its pre-turn pose so the turn only
## ever shows up once. See project-notes.md's "Turn-in-place body rotation"
## section for the full history/reasoning, including why accumulation must
## be gated on TIP being at full weight (not mid-fade).
##
## cam_angle_diff is deliberately NOT owned here - it stays a var directly
## on Player.gd because LookController.gd reads it externally as
## body.cam_angle_diff for its neck-turn clamp.

var tip_cool_down: float = 0.5 # Minimum time between turn-in-place triggers
var tip_timer: float = 0.0 # Turn-in-place cooldown timer
var turn_in_place: bool = false # Turn-in-place animation active

var tip_skeleton: Skeleton3D # GeneralSkeleton node; reads/writes Hips rotation for turn-in-place
var tip_hips_idx: int = -1 # Bone index of Hips; -1 if not found
var tip_prev_raw_hips_rot: Quaternion = Quaternion.IDENTITY # Hips rotation from previous frame
var tip_frozen_hips_rot: Quaternion = Quaternion.IDENTITY # Hips rotation to hold while turn-in-place plays
var tip_was_active: bool = false # Whether turn-in-place was active last frame
var tip_was_tracking: bool = false # Whether we're actively tracking Hips rotation deltas


## Resolves the skeleton/bone-index references. Call once from Player.gd's
## _ready().
func setup(player: Node) -> void:
	tip_skeleton = player.get_node_or_null("Model/GeneralSkeleton")
	if tip_skeleton:
		tip_hips_idx = tip_skeleton.find_bone("Hips")


## Call every _physics_process with whether there's current movement input.
func update_timer(delta: float, has_input: bool) -> void:
	if has_input:
		tip_timer = 0.0
	else:
		tip_timer += delta


## Call once per _process, before handle_trigger()/update_body_rotation().
func update_active_state(animation_tree: AnimationTree, direction: Vector3) -> void:
	turn_in_place = animation_tree.get("parameters/TIP/active") and !(direction != Vector3.ZERO)


func handle_trigger(animation_tree: AnimationTree, cam_angle_diff: float, fire_positive_deg: float, fire_negative_deg: float, direction: Vector3) -> void:
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


## Must run after AnimationTree has applied this frame's pose
## (Player.process_priority = 100 guarantees that for _process), so
## tip_skeleton.get_bone_pose_rotation() reads the animation's real,
## current-frame Hips rotation.
func update_body_rotation(player: Node3D, animation_tree: AnimationTree) -> void:
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
			# blend-toward-idle motion as if it were more turning. Only sum
			# the delta while at full weight - past fade-in, before fade-out.
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
					player.rotation.y += 2.0 * atan2(twist.y, twist.w)
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
