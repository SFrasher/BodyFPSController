class_name CharacterRigger
extends Node

## Configures the character's rig for the current equipment/hold state:
## gates the weapon IK/copy-transform modifiers, switches the spine aim
## target, sets the finger-grip blend, and shows/hides the gun mesh.
## Sits alongside CharacterAnimator - that script decides the animated
## pose, this one configures what the rig does with it afterward.

@export var armed_state: HoldStateConfig = preload("res://HoldStates/armed_state.tres")
@export var unarmed_state: HoldStateConfig = preload("res://HoldStates/unarmed_state.tres")
@export var current_hold_state: HoldStateConfig

var animation_tree: AnimationTree

var weapon_r_upper_arm_mod: CopyTransformModifier3D
var weapon_r_hand_mod: CopyTransformModifier3D
var lh_weapon_ik_mod: TwoBoneIK3D
var lh_weapon_copy_mod: CopyTransformModifier3D
var weapon_mesh_node: Node3D
var spine_ccdik_mod: CCDIK3D
var spine_copy_mod: CopyTransformModifier3D
var spine_twist_mod: BoneTwistDisperser3D


func _ready() -> void:
	var player := get_parent()
	animation_tree = player.animation_tree
	weapon_r_upper_arm_mod = player.get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D")
	weapon_r_hand_mod = player.get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D2")
	lh_weapon_ik_mod = player.get_node_or_null("Model/GeneralSkeleton/LHTwoBoneIK3D")
	lh_weapon_copy_mod = player.get_node_or_null("Model/GeneralSkeleton/LHCopyTransformModifier3D2")
	weapon_mesh_node = player.get_node_or_null("Model/GeneralSkeleton/RShoulderBoneAttachment3D2/WeaponHolder/Gun")
	spine_ccdik_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineCCDIK3D")
	spine_copy_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineCopyTransformModifier3D")
	spine_twist_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineBoneTwistDisperser3D")
	var initial_state := current_hold_state if current_hold_state else unarmed_state
	apply_state(initial_state)
	current_hold_state = initial_state


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		var next_state := unarmed_state if current_hold_state == armed_state else armed_state
		apply_state(next_state)
		current_hold_state = next_state


func apply_state(state: HoldStateConfig) -> void:
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
