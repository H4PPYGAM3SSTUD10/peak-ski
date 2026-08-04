## pause_menu.gd
## Esc-toggled pause overlay: Resume / Restart Run / Quit.
##
## The UI is built in code rather than authored in a .tscn — layout stays in one
## readable place and there is no hand-written scene markup to get wrong.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps receiving input while the rest of
## the tree is paused. Everything else in the game uses the default (pausable)
## mode, so the skier, camera and race timer all freeze on their own.

extends CanvasLayer

## Pause key. P rather than Esc: on Windows, Esc while the mouse is captured is
## frequently swallowed by the window before the game sees it, which made the
## pause toggle feel unreliable.
const PAUSE_KEY := KEY_P

var _root : Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 10
	_build_ui()
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	_add_button(box, "Resume",      _on_resume)
	_add_button(box, "Restart Run", _on_restart)
	_add_button(box, "Quit",        _on_quit)

	var hint := Label.new()
	hint.text = "P to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


func _add_button(parent: Node, label: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(280, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(handler)
	parent.add_child(b)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Read the key directly rather than via an InputMap action, so the menu
	# cannot be broken by the project's input configuration. Matched on
	# physical_keycode so it works regardless of keyboard layout.
	if event is InputEventKey and event.pressed and not event.echo:
		var key : int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == PAUSE_KEY:
			_set_paused(not get_tree().paused)
			get_viewport().set_input_as_handled()


# ── Actions ───────────────────────────────────────────────────────────────────

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_root.visible     = paused
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	)


func _on_resume() -> void:
	_set_paused(false)


func _on_restart() -> void:
	_set_paused(false)
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()
