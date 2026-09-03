extends Node3D
## First-person look controller.
##
## POSITION still comes entirely from the Head bone. Camera3D remains a child of
## Model/GeneralSkeleton/HeadBoneAttachment3D and this script never writes its
## origin - the eye point rides the real animated/IK-solved bone, unfiltered.
##
## ROTATION now comes from raw look input instead of from the solved bone
## (Step 1 of the stabilization work). SpineCCDIK3D already overwrites the
## animation's head rotation on its way to SpineTargetWeaponAim, so the bone's
## rotation was only ever an approximation of this same input - one carrying the
## solver's residual error plus whatever rotational noise the animation adds.
## Reading the input directly removes that noise entirely and makes aim exact:
## where you point is now where the camera looks, not wherever CCDIK landed.
##
## This is the same split DayZ uses (DayZPlayerCamera1stPerson: position from
## the "Head" bone plus a fixed local offset, rotation from accumulated look
## angles) and the same one Unreal's bUsePawnControlRotation gives you.
##
## The body still aims through the existing IK chain exactly as before - this
## node drives TargetPivot every frame, unchanged in intent.

@export var target_pivot: Marker3D
@export var follow_target: Node3D

@export_group("Camera")
## The skeleton whose skeleton_updated signal we hang the basis write on.
@export var skeleton: Skeleton3D
## The render camera. Stays parented to HeadBoneAttachment3D; only its basis is
## written here, never its origin.
@export var camera: Camera3D
## Yaw baked into the camera basis. The rig's forward is world +Z, not Godot's
## default -Z, so the camera needs a half turn to face the direction Player.gd
## assumes (see angle_rotation()'s use of Vector3.BACK).
@export var camera_yaw_offset: float = PI

@export_group("Look Parameters")
@export var pitch_max: float = 80.0
@export var pitch_min: float = -60.0
@export var mouse_sensitivity: float = 0.002
@export var gamepad_sensitivity: float = 2.5
## Hard neck-turn limit, in degrees of cam_angle_diff (signed angle from body-
## forward to camera-forward - same value Player.gd::angle_rotation() computes
## and turn-in-place fires on). The head cannot look further from body-forward
## than this in either direction, same as a real neck's range of motion.
## Mirrors Player.gd::handle_turn_in_place()'s fire thresholds (60 / -70) - kept
## as separate constants here rather than reading them from Player.gd, since
## those are hardcoded literals there, not exported/shared state. If those
## thresholds ever change, update these to match.
@export var neck_clamp_positive_deg: float = 60.0
@export var neck_clamp_negative_deg: float = -70.0
## Landing the correction exactly on the threshold floated back a hair short
## of it every frame (confirmed live: cam_angle_diff stuck at -69.9999996...,
## never actually <= -70), so Player.gd's fire check never triggered from
## mouse-look alone - the clamp silently ate turn-in-place. This tiny
## overshoot margin makes the corrected value land just past the threshold
## instead of exactly on it, so the fire condition is met reliably.
@export var neck_fire_margin_deg: float = 0.1

@export_group("Weapon Aiming Parameter")
@export var target_pivot_x_offset: float = 2.45
## Exponential follow rate for the aim gimbal, in 1/seconds. Replaces the old
## constant-rate move_toward(aim_speed * delta), which rate-limited fast flicks
## and then hard-stopped on arrival - a pop at the end of every quick turn.
## Higher = snappier. Frame-rate independent via 1 - exp(-rate * delta).
@export var aim_damping: float = 25.0

var yaw: float = 0.0
var pitch: float = 0.0


func _ready() -> void:
	# top_level, exactly as NewTPSCamera.gd does it. This node is a child of
	# Player, so without it `rotation.y = yaw` produces a GLOBAL yaw of
	# player_yaw + yaw. Player.gd reads camera_target's GLOBAL yaw as
	# camera_rotation, so the body's rotation got counted twice and
	# cam_angle_diff could never be reduced by turn-in-place - every 45 deg TIP
	# step pushed the target further away, so it fired forever, monopolised the
	# AnimationTree, starved root motion and killed movement. top_level makes
	# yaw world-absolute, which is what Player.gd and TIP were always written
	# against. Position is irrelevant here: this node renders nothing and has
	# no children, only its basis is ever read.
	top_level = true
	_capture_mouse()
	if target_pivot:
		target_pivot.rotation_degrees = Vector3.ZERO
	if follow_target:
		yaw = follow_target.rotation.y
	# Connected in code rather than in the editor so this handler runs AFTER
	# BoneAttachment3D's own skeleton_updated handler: by the time we overwrite
	# the camera's basis, its parent has already been placed on the final solved
	# pose for this frame. Signal handlers fire in connection order and
	# HeadBoneAttachment3D connects during scene instantiation, ahead of _ready.
	if skeleton and not skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		skeleton.skeleton_updated.connect(_on_skeleton_updated)


## Guarded the same way NewTPSCamera.gd's capture call was. On X11 the pointer
## grab fails when the window isn't focused (windowless / automated runs) and
## throws "NO GRAB", which halts the debugger for the whole session. In normal
## play the window is already focused, so this captures immediately and behaves
## exactly as the unguarded call did.
func _capture_mouse() -> void:
	if DisplayServer.window_is_focused():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_capture_mouse()


func _input(event: InputEvent) -> void:
	# Not gated on Input.get_mouse_mode() == CAPTURED: OS-level mouse grab can
	# fail to report as captured in some environments (headless/windowless
	# test runs) even though look input should still work. Pause-menu /
	# UI-focus gating should be handled separately (e.g. via get_tree().paused)
	# once that system exists, rather than by trusting the OS capture state.
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch += event.relative.y * mouse_sensitivity


func _process(delta: float) -> void:
	# Runs in _process, NOT _physics_process. AnimationTree.callback_mode_process
	# and Skeleton3D.modifier_callback_mode_process are both IDLE, so the whole
	# skeleton solves once per rendered frame. Driving the aim gimbal at the
	# 60 Hz physics rate made it a staircase that a per-frame solver chased,
	# quantizing the view to the physics tick - the head would sit still for
	# 2-3 frames above 60 fps and then jump.
	var gamepad_input := Vector2(Input.get_axis("lookright", "lookleft"), -Input.get_axis("lookdown", "lookup"))
	if gamepad_input.length() > 0.1:
		yaw += gamepad_input.x * gamepad_sensitivity * delta
		pitch += gamepad_input.y * gamepad_sensitivity * delta

	pitch = clamp(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

	# Hard neck-turn limit. Recomputed fresh every frame against follow_target's
	# CURRENT facing (not read from follow_target.cam_angle_diff, which is a
	# physics-frame-old value by the time this runs) using the exact same
	# formula Player.gd::angle_rotation() uses, so the sign convention matches
	# exactly and there's no independent drift between the two. Because it's
	# measured against the body's live facing, once turn-in-place starts
	# rotating the body via root motion, the ceiling on how far yaw can go keeps
	# advancing with it in real time - you can keep looking further the same
	# direction while the turn plays, you just can't outrun it.
	if follow_target:
		var forward_direction: Vector3 = follow_target.global_transform.basis.z.normalized()
		var cam_direction: Vector3 = Vector3.BACK.rotated(Vector3.UP, yaw)
		var neck_diff_deg := rad_to_deg(forward_direction.signed_angle_to(cam_direction, Vector3.UP))
		if neck_diff_deg > neck_clamp_positive_deg:
			yaw -= deg_to_rad(neck_diff_deg - (neck_clamp_positive_deg + neck_fire_margin_deg))
		elif neck_diff_deg < neck_clamp_negative_deg:
			yaw -= deg_to_rad(neck_diff_deg - (neck_clamp_negative_deg - neck_fire_margin_deg))

	# Player.gd still reads this node's yaw via camera_target.global_transform
	# .basis.get_euler().y for movement direction, body rotation and
	# cam_angle_diff. Keep it in sync every frame - raw yaw, matching
	# NewTPSCamera.gd's original convention.
	rotation.y = yaw

	# Drive the aim gimbal. The body (and the weapon, whose IK targets hang off
	# TargetPivot) still follows this through SpineCCDIK3D - only the camera has
	# stopped taking its rotation from the result.
	if target_pivot and follow_target:
		var t := 1.0 - exp(-aim_damping * delta)
		target_pivot.rotation_degrees.x = lerp(
			target_pivot.rotation_degrees.x,
			rad_to_deg(pitch) + target_pivot_x_offset,
			t
		)
		target_pivot.rotation_degrees.y = lerp(
			target_pivot.rotation_degrees.y,
			clampf(follow_target.cam_angle_diff, -90.0, 90.0),
			t
		)


func _on_skeleton_updated() -> void:
	# Rotation from input, position from the bone.
	#
	# Writing global_basis preserves the camera's global origin, which round
	# trips back to exactly its existing local offset - so the 0.1 forward eye
	# offset is untouched and the camera stays a literal child of the bone
	# attachment. Nothing here computes or invents a position.
	if camera:
		camera.global_basis = Basis.from_euler(Vector3(-pitch, yaw + camera_yaw_offset, 0.0))
