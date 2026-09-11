class_name HoldStateController
extends RefCounted

## Owns the weapon/spine SkeletonModifier3D references for the armed/unarmed
## hold-state system and applies a HoldStateConfig resource's values onto
## them. This is a plain object, not a scene node - Player.gd instantiates
## and drives it directly (see Player.gd's `hold_state` var), so pulling
## this logic out of Player.gd didn't require any Player.tscn changes.
## See HoldStateConfig.gd and ik-and-player-conversion-map.md's "unarmed
## conversion" section for why these are the right nodes to gate.

var weapon_r_upper_arm_mod: CopyTransformModifier3D # Right upper arm weapon modifier
var weapon_r_hand_mod: CopyTransformModifier3D # Right hand weapon modifier
var lh_weapon_ik_mod: TwoBoneIK3D # Left hand weapon IK solver
var lh_weapon_copy_mod: CopyTransformModifier3D # Left hand weapon copy modifier
var weapon_mesh_node: Node3D # Weapon mesh visibility control
var spine_ccdik_mod: CCDIK3D # Spine CCDIK aiming solver
var spine_copy_mod: CopyTransformModifier3D # Spine rotation copy modifier
var spine_twist_mod: BoneTwistDisperser3D # Spine twist disperser for aiming

var animation_tree: AnimationTree


## Resolves all the modifier node references relative to the player node.
## Call once from Player.gd's _ready(), before apply_state().
func setup(player: Node, tree: AnimationTree) -> void:
	animation_tree = tree
	weapon_r_upper_arm_mod = player.get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D")
	weapon_r_hand_mod = player.get_node_or_null("Model/GeneralSkeleton/WeaponCopyTransformModifier3D2")
	lh_weapon_ik_mod = player.get_node_or_null("Model/GeneralSkeleton/LHTwoBoneIK3D")
	lh_weapon_copy_mod = player.get_node_or_null("Model/GeneralSkeleton/LHCopyTransformModifier3D2")
	weapon_mesh_node = player.get_node_or_null("Model/GeneralSkeleton/RShoulderBoneAttachment3D2/WeaponHolder/Gun")
	spine_ccdik_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineCCDIK3D")
	spine_copy_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineCopyTransformModifier3D")
	spine_twist_mod = player.get_node_or_null("Model/GeneralSkeleton/SpineBoneTwistDisperser3D")


## Applies a HoldStateConfig: gates the armed-only modifiers, sets the
## rifle-grip finger blend, and shows/hides the gun mesh. Disabling/enabling
## these (never deleting the nodes) is deliberate - both states stay
## reachable and both survive a scene save. See ik-and-player-conversion-
## map.md's "unarmed conversion" section for why these are the right nodes.
## Player.gd owns `current_hold_state` (it's exported there for the
## Inspector) - this function only applies values, it doesn't track state.
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
