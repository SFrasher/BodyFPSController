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

## Spine/Chest/UpperChest/Neck/Head aim chain: SpineCCDIK3D (bends toward a
## target), SpineCopyTransformModifier3D (rigidly overwrites UpperChest's
## rotation toward the same target), and SpineBoneTwistDisperser3D (spreads
## the twist CCDIK introduces back across the chain so it doesn't all pile up
## on one joint). On for both armed and unarmed now - see spine_pitch_only
## below for what target each state points these three at.
@export var use_spine_aim_ik: bool = false

## Which target the spine chain above aims at, when use_spine_aim_ik is on.
## false (armed): TargetPivot/SpineTargetWeaponAim, driven by FPSCamera.gd
## from both camera pitch AND yaw (clamped cam_angle_diff) - correct for
## aiming a weapon down sights, torso rotates to track the aim point.
## true (unarmed): PitchPivot/SpineTargetPitchOnly, driven by FPSCamera.gd
## from pitch ONLY - PitchPivot's yaw is never written so it always points
## straight along the body's own forward. With nothing to aim, following the
## full yaw-tracking target was what read as a stiff, off-facing torso
## fighting the UUS animation's own idle/walk sway (confirmed live 2026-09-
## 03, which is why this chain was disabled outright for unarmed at the
## time). Pitch-only keeps the intended "look up/down bends the spine"
## camera feel without that facing-direction fight.
@export var spine_pitch_only: bool = false
