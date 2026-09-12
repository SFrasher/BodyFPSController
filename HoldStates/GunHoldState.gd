extends Resource
class_name GunHoldState

## Self-contained hold state for holding the rifle: rigid FK on the right
## arm from the aim gimbal, IK grip on the left hand, spine aiming at the
## weapon-aim target, full finger-grip blend, gun mesh visible. Owns its
## own fields and its own apply() - CharacterRigger doesn't know or care
## what's inside this, it just calls apply(self) on whatever's assigned.

@export var finger_grip_blend: float = 1.0
@export var weapon_visible: bool = true

func apply(rigger: CharacterRigger) -> void:
	if rigger.weapon_r_upper_arm_mod:
		rigger.weapon_r_upper_arm_mod.active = true
	if rigger.weapon_r_hand_mod:
		rigger.weapon_r_hand_mod.active = true
	if rigger.lh_weapon_ik_mod:
		rigger.lh_weapon_ik_mod.active = true
	if rigger.lh_weapon_copy_mod:
		rigger.lh_weapon_copy_mod.active = true
	var aim_target := NodePath("../../../TargetPivot/SpineTargetWeaponAim")
	if rigger.spine_ccdik_mod:
		rigger.spine_ccdik_mod.active = true
		rigger.spine_ccdik_mod.set("settings/0/target_node", aim_target)
	if rigger.spine_copy_mod:
		rigger.spine_copy_mod.active = true
		rigger.spine_copy_mod.set("settings/0/reference_node", aim_target)
	if rigger.spine_twist_mod:
		rigger.spine_twist_mod.active = true
	if rigger.animation_tree:
		rigger.animation_tree.set("parameters/FingersBlend2/blend_amount", finger_grip_blend)
	if rigger.weapon_mesh_node:
		rigger.weapon_mesh_node.visible = weapon_visible
