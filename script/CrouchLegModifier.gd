extends SkeletonModifier3D
## Procedural crouch layer. Placed as the FIRST child under GeneralSkeleton
## (before LLegTwoBoneIK3D/RLegTwoBoneIK3D) so it runs before them in the
## modifier chain each frame: it captures each foot's current animated global
## pose into the two foot-target nodes, then lowers Hips by `crouch_amount`.
## The two leg TwoBoneIK3D modifiers (later in the chain) then solve the knee
## bend to hold the feet at the just-captured, un-lowered target positions -
## producing a genuine crouched walk (legs keep stepping through the normal
## gait cycle, just bent and lowered) rather than a canned crouch pose.
##
## Driven entirely by Player.gd, which owns the crouch toggle input and the
## smoothed crouch_amount value (see Player.gd's handle_crouch()). This node
## and the two leg IK modifiers are only left `.active` while actually
## crouched - see Player.gd's _update_crouch_modifiers().
##
## Hips is written via set_bone_pose_position() (LOCAL pose), not a global
## pose override - confirmed live in Play Scene that a global pose override
## on Hips does not propagate to the rendered/skinned pose here, while a
## direct local pose write does. Root (Hips' parent bone) sits at identity
## in this rig, so local Y and skeleton-space/world Y coincide.

@export var left_foot_target: Node3D
@export var right_foot_target: Node3D

@export var hips_bone_name: String = "Hips"
@export var left_foot_bone_name: String = "LeftFoot"
@export var right_foot_bone_name: String = "RightFoot"

## Meters to lower Hips this frame. Set every frame by Player.gd.
var crouch_amount: float = 0.0


## Resolves the two foot-target markers if they weren't assigned in the
## Inspector. They never actually were, which left BOTH capture branches in
## _process_modification() unreachable (`if left_foot_target:` on a null) -
## so the targets stayed frozen at their editor-placed rest-pose positions
## and the two leg TwoBoneIK3D nodes held the feet there every frame. That is
## what produced the rigid legs and feet that never left the ground while
## walking crouched, while the crouched *pose* still looked correct, because
## the Hips lowering sits below those branches and was never affected. It also
## explains why crouched idle looked fine: standing still, a frozen target and
## a live one are the same thing.
##
## Resolved here in script rather than wired into Player.tscn on purpose -
## same relative paths the leg TwoBoneIK3D nodes already use for their own
## target_node, and it keeps this scene file untouched (see the project
## notes' standing lesson about preferring script wiring over scene wiring for
## pure data references on Player.tscn).
func _ready() -> void:
	if left_foot_target == null:
		left_foot_target = get_node_or_null("../../../LeftFootTarget")
	if right_foot_target == null:
		right_foot_target = get_node_or_null("../../../RightFootTarget")
	if left_foot_target == null or right_foot_target == null:
		push_error("CrouchLegModifier: foot target(s) not found - the crouch leg IK will pin the feet to a fixed position. Assign left_foot_target/right_foot_target.")


func _process_modification() -> void:
	var skel := get_skeleton()
	if not skel:
		return

	var l_idx := skel.find_bone(left_foot_bone_name)
	var r_idx := skel.find_bone(right_foot_bone_name)

	# Capture BEFORE touching Hips, so the target reflects this frame's
	# natural animated foot position, not one already affected by our own
	# offset.
	if left_foot_target:
		left_foot_target.global_transform = skel.global_transform * skel.get_bone_global_pose(l_idx)
	if right_foot_target:
		right_foot_target.global_transform = skel.global_transform * skel.get_bone_global_pose(r_idx)

	if crouch_amount != 0.0:
		var hips_idx := skel.find_bone(hips_bone_name)
		var hips_local := skel.get_bone_pose_position(hips_idx)
		hips_local.y -= crouch_amount
		skel.set_bone_pose_position(hips_idx, hips_local)
