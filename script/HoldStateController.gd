class_name HoldStateController
extends Node

## Owns the armed/unarmed hold-state system end to end: which state is
## active, the weapon/spine SkeletonModifier3D references, applying a
## HoldStateConfig's values onto them, and the debug B-key toggle. A real
## sibling node under Player in Player.tscn (not something Player.gd
## instantiates), so Player.gd doesn't need to know anything about hold
## state at all - it just needs to exist in the tree.
##
## animation_tree is pulled from the parent Player node at _ready() rather
## than given its own @export NodePath here - Player.gd already has a
## correctly-wired reference to it, and a Node-typed @export on a freshly
## added node needs a node_paths=PackedStringArray(...) header in the .tscn
## or it silently resolves to null (the exact bug that broke the old
## procedural crouch - see crouch-root-cause-and-solution-ranking.md).
## Reusing Player's own reference sidesteps that risk entirely.
##
## See HoldStateConfig.gd and ik-and-player-conversion-map.md's "unarmed
## conversion" section for why these are the right modifiers to gate.

@export var armed_state: HoldStateConfig = preload("res://HoldStates/armed_state.tres") # Armed stance config
@export var unarmed_state: HoldStateConfig = preload("res://HoldStates/unarmed_state.tres") # Unarmed stance config
@export var current_hold_state: HoldStateConfig # Currently active hold state

var weapon_r_upper_arm_mod: CopyTransformModifier3D # Right upper arm weapon modifier
var weapon_r_hand_mod: CopyTransformModifier3D # Right hand weapon modifier
var lh_weapon_ik_mod: TwoBoneIK3D # Left hand weapon IK solver
var lh_weapon_copy_mod: CopyTransformModifier3D # Left hand weapon copy modifier
var weapon_mesh_node: Node3D # Weapon mesh visibility control
var spine_ccdik_mod: CCDIK3D # Spine CCDIK aiming solver
var spine_copy_mod: CopyTransformModifier3D # Spine rotation copy modifier
var spine_twist_mod: BoneTwistDisperser3D # Spine twist disperser for aiming

var animation_tree: AnimationTree


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


## Debug-only toggle until a real equip/pickup system exists. Same pattern as
## DebugViewToggle.gd's V key: raw keycode check in _unhandled_input, no
## input-map action needed for a temporary dev toggle.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		var next_state := unarmed_state if current_hold_state == armed_state else armed_state
		apply_state(next_state)
		current_hold_state = next_state


## Applies a HoldStateConfig: gates the armed-only modifiers, sets the
## rifle-grip finger blend, and shows/hides the gun mesh. Disabling/enabling
## these (never deleting the nodes) is deliberate - both states stay
## reachable and both survive a scene save. See ik-and-player-conversion-
## map.md's "unarmed conversion" section for why these are the right nodes.
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
