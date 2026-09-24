class_name CharacterProcedurals
extends Node3D

## Configures the character's rig for whatever's in current_hold_state.
## Each hold state is a fully self-contained resource with its own fields
## and its own apply(procedurals) method - this script doesn't know what's
## inside any of them, it just calls apply(self) on whatever's assigned.
##
## null means no hold state. reset_to_default() restores the scene-authored
## defaults when switching away from a hold state back to nothing equipped.
##
## debug_cycle_states is a growable, inspector-editable test list the
## B-key cycles through until an equip/inventory system exists - it
## includes null so cycling can get back to "nothing equipped" too.

@export var current_hold_state: Resource
@export var debug_cycle_states: Array[Resource] = [null]
var debug_cycle_index: int = 0

@export var skeleton: Skeleton3D

var spine_ccdik_mod: CCDIK3D
var spine_copy_mod: CopyTransformModifier3D
var spine_twist_mod: BoneTwistDisperser3D

func _ready() -> void:
	if skeleton:
		spine_ccdik_mod = skeleton.get_node_or_null("SpineCCDIK3D")
		spine_copy_mod = skeleton.get_node_or_null("SpineCopyTransformModifier3D")
		spine_twist_mod = skeleton.get_node_or_null("SpineBoneTwistDisperser3D")
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
	var pitch_target := NodePath("../../../PitchPivot/SpineTargetPitchOnly")
	if spine_ccdik_mod:
		spine_ccdik_mod.active = true
		spine_ccdik_mod.set("settings/0/target_node", pitch_target)
	if spine_copy_mod:
		spine_copy_mod.active = true
		spine_copy_mod.set("settings/0/reference_node", pitch_target)
	if spine_twist_mod:
		spine_twist_mod.active = true
