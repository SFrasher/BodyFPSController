extends Camera3D
## Third-person debug view, front-facing. Sibling to DebugView (back view) -
## cycling between FPS / back / front is owned by DebugViewToggle.gd's V
## handler, this node only positions itself; see that script for why.
##
## Same derivation as the back view: reads the FPS camera's own FINAL
## transform each frame and parks a chase-cam offset off it, then looks at
## the eye point - no yaw/pitch convention-guessing of its own. Only
## difference is which side of the eye point it parks on.

@export var fps_view: Camera3D
@export var distance: float = 3.0
@export var height: float = 0.35


func _ready() -> void:
	top_level = true
	current = false


func _process(_delta: float) -> void:
	if fps_view == null:
		return

	var eye_transform := fps_view.global_transform
	var eye_pos := eye_transform.origin
	# DebugViewToggle.gd's back view parks at +basis.z (Camera3D looks down
	# -Z, so +Z points back out of the screen - "behind" the eye). The front
	# view is the opposite side: -basis.z, in front of the face, still
	# looking back at the eye point so the character's front is on screen.
	var chase_pos := eye_pos - eye_transform.basis.z * distance + Vector3.UP * height

	global_position = chase_pos
	look_at(eye_pos, Vector3.UP)
