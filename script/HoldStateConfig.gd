extends Resource
class_name HoldStateConfig

## Data-driven hold state (armed, unarmed, and later torch/etc.) - switching
## states means swapping which resource is assigned, not adding another
## branch to a growing if/else chain in Player.gd. See
## "ik-and-player-conversion-map.md" for why these specific modifiers are the
## ones that need gating: the right arm is rigidly FK'd to the aim gimbal and
## the left arm IKs to a grip point on the gun - both meaningless with no
## weapon equipped, so unarmed turns them off and lets the UUS animation
## drive the arms directly instead.

## Human-readable label, shown nowhere yet but useful in the inspector/debug.
@export var state_name: String = ""

## Right arm: WeaponCopyTransformModifier3D + 3D2 (rigid FK from the aim
## gimbal onto the upper arm, then the hand). On for armed, off for unarmed.
@export var use_right_arm_weapon_ik: bool = false

## Left arm: LHTwoBoneIK3D + LHCopyTransformModifier3D2 (IK reach to the
## gun's grip point, then a rotation snap for the grip). On for armed, off
## for unarmed.
@export var use_left_arm_weapon_ik: bool = false

## AnimationTree parameter "FingersBlend2/blend_amount" - layers the
## rifle-grip finger pose on top of whatever the hand is doing. 1.0 for
## armed, 0.0 for unarmed (no grip to shape the fingers around).
@export_range(0.0, 1.0) var finger_grip_blend: float = 0.0

## Visibility of the gun mesh (Model/GeneralSkeleton/RShoulderBoneAttachment3D2/
## WeaponHolder/Gun). Cosmetic only - hides the mesh once the arm holding it
## is free to swing naturally instead of gripping it.
@export var weapon_visible: bool = false

## Spine/Chest/UpperChest/Neck/Head aim chain: SpineCCDIK3D (bends toward
## TargetPivot/SpineTargetWeaponAim), SpineCopyTransformModifier3D (rigidly
## overwrites UpperChest's rotation toward the same target), and
## SpineBoneTwistDisperser3D (spreads the twist CCDIK introduces back across
## the chain so it doesn't all pile up on one joint). FPSCamera.gd drives
## TargetPivot from camera pitch/yaw every frame, unconditionally - so with
## this on, the torso is always leaning/twisting toward wherever the camera
## looks. That's correct for aiming a weapon down sights, but with nothing to
## aim, it just reads as a stiff, off-facing torso fighting the UUS animation's
## own idle/walk sway. On for armed, off for unarmed - confirmed live (2026-
## 09-03): with these three off, the unarmed torso and head sit exactly where
## the animation puts them, facing straight, no residual twist.
@export var use_spine_aim_ik: bool = false
