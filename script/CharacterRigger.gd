class_name CharacterRigger
extends Node

## Configures the character's rig for whatever's in current_hold_state.
## Each hold state is a fully self-contained resource with its own fields
## and its own apply(rigger) method - this script doesn't know what's
## inside any of them, it just calls apply(self) on whatever's assigned.
##
## null means no hold state. The rig's own scene-authored defaults (no
## weapon IK, spine on the plain pitch-only target, no finger grip, gun
## hidden) already ARE "unarmed" - there's no dedicated unarmed asset,
## reset_to_default() below just restores those defaults when switching
## away from a hold state back to nothing equipped.
##
## debug_cycle_states is a growable, inspector-editable test list the
## B-key cycles through until an equip/inventory system exists - it
## includes null so cycling can get back to "nothing equipped" too.

@export var current_hold_state: Resource
@export var debug_cycle_states: Array[Resource] = [
	null,
	preload("res://HoldStates/gun_hold_state.tres"),
]
var debug_cycle_index: int = 0

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
	if current_hold_state and current_hold_state.has_method("apply"):
		current_hold_state.apply(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		if debug_cycle_states.is_empty():
			return
		debug_cycle_index = (debug_cycle_index + 1) % debug_cycle_states.size()
		equip(debug_cycle_states[debug_cycle_index])

## The one entry point anything - the test keybind now, an equip/inventory
## system later - uses to switch hold state.
func equip(state: Resource) -> void:
	current_hold_state = state
	if state and state.has_method("apply"):
		state.apply(self)
	else:
		reset_to_default()

func reset_to_default() -> void:
	if weapon_r_upper_arm_mod:
		weapon_r_upper_arm_mod.active = false
	if weapon_r_hand_mod:
		weapon_r_hand_mod.active = false
	if lh_weapon_ik_mod:
		lh_weapon_ik_mod.active = false
	if lh_weapon_copy_mod:
		lh_weapon_copy_mod.active = false
	var pitch_target := NodePath("../../../PitchPivot/SpineTargetPitchOnly")
	if spine_ccdik_mod:
		spine_ccdik_mod.active = true
		spine_ccdik_mod.set("settings/0/target_node", pitch_target)
	if spine_copy_mod:
		spine_copy_mod.active = true
		spine_copy_mod.set("settings/0/reference_node", pitch_target)
	if spine_twist_mod:
		spine_twist_mod.active = true
	if animation_tree:
		animation_tree.set("parameters/FingersBlend2/blend_amount", 0.0)
	if weapon_mesh_node:
		weapon_mesh_node.visible = false
