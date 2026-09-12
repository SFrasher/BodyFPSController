class_name LocomotionAnimator
extends Node

## Drives AnimationTree/AnimationPlayer from the movement state Player.gd
## exposes (direction, input_dir, rotation) - the animation-facing half of a
## GMC-style split: Player.gd is pure movement/collision/physics and knows
## nothing about this node; this one reads Player's public state and drives
## the mesh. A sibling node under Player, same pattern LookController.gd/
## Camera/DebugView already use - they read Player's state independently
## too, Player.gd never calls into any of them.
##
## animation_tree and look_controller are pulled from the parent Player node
## at _ready() rather than given their own @export NodePaths here - a
## Node-typed @export on a freshly added node needs a
## node_paths=PackedStringArray(...) header in the .tscn or it silently
## resolves to null (the exact bug that broke the old procedural crouch -
## see crouch-root-cause-and-solution-ranking.md). Reusing Player's already-
## correct references sidesteps that risk entirely.

@export var gait_blend_speed: float = 6.0 # How fast gait transitions between walk/jog

var player: CharacterBody3D
var animation_tree: AnimationTree

var gait_blend: float = 0.0 # Current gait blend amount (0=walk, 1=jog)

var currentspeed = Vector2.ZERO # Current animation blend space values (X/Y); lerps toward targetspeed to smooth animation transitions
var strafe_acceleration = 3 # Controls how quickly currentspeed reaches targetspeed; prevents animation pops when input direction changes suddenly
var targetspeed # Desired animation blend space values we're accelerating toward based on player input direction
var strafe_input: Vector2 = Vector2.ZERO # Normalized player input (-1 to 1 on each axis); fed into animation tree after camera rotation

## Turn In Place.
var tip := TurnInPlaceController.new()


func _ready() -> void:
	player = get_parent()
	animation_tree = player.animation_tree
	# Runs after both AnimationTree's own (default-priority) update and
	# Player's (priority 100) physics/rotation update each tick - see
	# TurnInPlaceController's doc comment and _physics_process() below for
	# why that ordering matters.
	process_priority = 200
	animation_tree.set("parameters/TIP TimeScale/scale", 1.4)
	_register_uus_animation_library()
	tip.setup(player)


## Registers the baked UUS animation library on AnimationPlayer at runtime
## instead of baking the reference into Player.tscn. Player.tscn's live IK
## modifiers bake current bone pose into the scene on every editor save, so
## data-only wiring like this is kept out of the scene file on purpose.
func _register_uus_animation_library() -> void:
	var anim_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		return
	if anim_player.has_animation_library("UUS"):
		return
	var uus_lib := load("res://AnimLib/UUS.tres") as AnimationLibrary
	if uus_lib:
		anim_player.add_animation_library("UUS", uus_lib)


func _process(delta: float) -> void:
	tip.update_active_state(animation_tree, player.direction)
	handle_strafe_animation(delta)
	handle_gait(delta)
	if player.look_controller:
		tip.handle_trigger(
			animation_tree,
			player.look_controller.cam_angle_diff,
			player.look_controller.neck_clamp_positive_deg,
			player.look_controller.neck_clamp_negative_deg,
			player.direction
		)
	tip.update_body_rotation(player, animation_tree)


## Smoothly blends the AnimationTree's Gait node toward jogging while [sprint] is
## held, walking when it's not. Doesn't touch movement speed directly - root
## motion already reads whatever pose Gait outputs, so blending toward the jog
## clips' larger per-frame translation is what actually speeds the body up.
func handle_gait(delta):
	var target_gait: float = 1.0 if Input.is_action_pressed("sprint") else 0.0
	gait_blend = move_toward(gait_blend, target_gait, gait_blend_speed * delta)
	animation_tree.set("parameters/Gait/blend_amount", gait_blend)


func handle_strafe_animation(delta):
	#handle strafe blend
	targetspeed = Vector2(player.input_dir.x, player.input_dir.y).normalized()
	currentspeed = currentspeed.move_toward(-targetspeed, strafe_acceleration * delta)
	strafe_input = Vector2(currentspeed.x, -currentspeed.y)
	animation_tree.set("parameters/WALK/blend_position", strafe_input)
	# JOG mirrors WALK's 9-point directional layout one-for-one (see the AnimationTree
	# resource), so it tracks the same input - only the Gait blend_amount (set in
	# handle_gait()) decides which one is actually audible in the final pose.
	animation_tree.set("parameters/JOG/blend_position", strafe_input)


func _physics_process(delta: float) -> void:
	tip.update_timer(delta, player.direction != Vector3.ZERO)
