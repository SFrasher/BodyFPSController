extends Camera3D
## Third-person debug views. Press V to cycle: FPS -> this (back chase view)
## -> DebugViewFront (front chase view) -> back to FPS. This node owns the
## cycle (not DebugViewFront) so there's exactly one place handling the V
## keypress - two nodes each independently toggling on the same key would
## double-cycle.
##
## Position/rotation: plain child of Player, fixed transform set once in
## the editor viewport. Player only ever rotates on yaw (turning to face
## movement/look direction, including turn-in-place), so a static child of
## it already swings correctly with body turns - no script needed for that,
## same as any other child node in this scene. This camera only exists to
## watch the character's body from outside; it was never meant to track
## exact look pitch, so it doesn't try to.

@export var fps_view: Camera3D
@export var front_view: Camera3D


func _ready() -> void:
	current = false


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
