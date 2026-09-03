extends Camera3D
## Third-person debug views. Press V to cycle: FPS -> this (back chase view)
## -> DebugViewFront (front chase view) -> back to FPS. This node owns the
## cycle (not DebugViewFront) so there's exactly one place handling the V
## keypress - two nodes each independently toggling on the same key would
## double-cycle.
##
## Reads the FPS camera's own FINAL transform each frame -- after
## FPSCamera.gd has already written this frame's look rotation onto it -- and
## parks a simple chase-cam offset behind and above it, then looks at the eye
## point. Because it derives the view direction from that already-solved
## transform it inherits the exact look direction with no yaw/pitch
## convention guessing of its own. Purely additive: reads fps_view every
## frame, never writes to it or to anything Player.gd/FPSCamera.gd depend on,
## except toggling which camera is `current` on V.
##
## Deliberately not built on NewTPSCamera.gd/Camera -- that node handles its
## own look input and would double-count against FPSCamera's look state.
## This is a lightweight, read-only observer, not a second controller.

@export var fps_view: Camera3D
@export var front_view: Camera3D
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
	# Camera3D looks down -Z, so basis.z (+Z) points back out of the screen --
	# exactly "behind" the eye point.
	var chase_pos := eye_pos + eye_transform.basis.z * distance + Vector3.UP * height

	global_position = chase_pos
	look_at(eye_pos, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		if current:
			if front_view:
				front_view.make_current()
			else:
				fps_view.make_current()
		elif front_view and front_view.current:
			fps_view.make_current()
		else:
			make_current()
