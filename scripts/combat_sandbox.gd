extends CanvasLayer
class_name CombatSandbox

var game: Node
var _panel: PanelContainer
var _target_selector: OptionButton
var _targets: Array[Node] = []
var _status: Label
var _ai_button: Button
var _weather: OptionButton
var _time: OptionButton
var _sea: OptionButton
var _refresh_timer := 0.0
var _ai_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	_build_ui()


func open(owner_game: Node) -> void:
	game = owner_game
	visible = true
	_ai_active = false
	_refresh_targets()
	_call_action("set_ai", null, false)
	_set_panel_input(true)
	_set_status("Laboratory ready. Select a target, then trigger a combat state.")


func close() -> void:
	visible = false
	_set_panel_input(false)


func _process(delta: float) -> void:
	if not visible or not is_instance_valid(game):
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.6
		_refresh_targets()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		_panel.visible = not _panel.visible
		_set_panel_input(_panel.visible)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -366.0
	_panel.offset_top = 24.0
	_panel.offset_right = -18.0
	_panel.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.050, 0.055, 0.96)
	style.border_color = Color(0.62, 0.48, 0.24, 0.92)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	_panel.add_child(column)
	var title := _label("COMBAT SANDBOX", 22, Color(0.94, 0.76, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := _label("F6 hides the controls", 12, Color(0.58, 0.68, 0.68))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_add_heading(content, "TARGET")
	_target_selector = OptionButton.new()
	_target_selector.custom_minimum_size.y = 42.0
	content.add_child(_target_selector)
	_add_button_grid(content, [
		["Light hit", "target_light_hit"], ["Heavy salvo", "target_heavy_hit"],
		["Rig impact", "target_rig_hit"], ["Disable guns", "target_gun_hit"],
		["Boarding ready", "target_boarding_ready"], ["Start boarding", "start_boarding"],
		["Foundering", "target_foundering"], ["Sink now", "target_sink"],
	])

	_add_heading(content, "WEAPONS & SHIP")
	_add_button_grid(content, [
		["Auto broadside", "player_broadside"], ["Incoming salvo", "incoming_salvo"],
		["Mortar strike", "mortar_strike"], ["Reload all", "reload_all"],
		["Damage player", "damage_player"], ["Repair player", "repair_player"],
		["Full restore", "restore_player"], ["Rogue wave", "rogue_wave"],
	])

	_add_heading(content, "FORT & BATTLEFIELD")
	_add_button_grid(content, [
		["Expose fort", "expose_fort"], ["Capture fort", "capture_fort"],
		["Reset laboratory", "reset_lab"], ["Clear projectiles", "clear_projectiles"],
	])
	_ai_button = _button("Enable live AI")
	_ai_button.pressed.connect(_toggle_ai)
	content.add_child(_ai_button)

	_add_heading(content, "ENVIRONMENT")
	_weather = _selector(["Clear", "Overcast", "Storm"], 0)
	_time = _selector(["Day", "Sunset", "Night"], 0)
	_sea = _selector(["Calm", "Rolling", "Rough", "High Seas"], 1)
	content.add_child(_labeled_control("Weather", _weather))
	content.add_child(_labeled_control("Time", _time))
	content.add_child(_labeled_control("Sea", _sea))
	var apply_environment := _button("Apply conditions")
	apply_environment.pressed.connect(_apply_environment)
	content.add_child(apply_environment)

	_status = _label("", 12, Color(0.72, 0.82, 0.78))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 46.0
	column.add_child(_status)


func _add_heading(parent: VBoxContainer, text: String) -> void:
	var heading := _label(text, 14, Color(0.91, 0.72, 0.34))
	parent.add_child(heading)
	parent.add_child(HSeparator.new())


func _add_button_grid(parent: VBoxContainer, definitions: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for definition in definitions:
		var action := String(definition[1])
		var button := _button(String(definition[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _trigger(action))
		grid.add_child(button)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 38.0)
	button.add_theme_font_size_override("font_size", 13)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _selector(options: Array, selected: int) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(190.0, 36.0)
	for option in options:
		selector.add_item(String(option))
	selector.select(selected)
	return selector


func _labeled_control(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _label(text, 13, Color(0.78, 0.80, 0.74))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row


func _trigger(action: String) -> void:
	var target := _selected_target()
	var result: Variant = _call_action(action, target)
	_set_status(String(result) if result is String else action.capitalize())
	_refresh_timer = 0.0


func _call_action(action: String, target: Node = null, value: Variant = null) -> Variant:
	if not is_instance_valid(game) or not game.has_method("combat_sandbox_action"):
		return "Sandbox controller is unavailable."
	return game.call("combat_sandbox_action", action, target, value)


func _toggle_ai() -> void:
	_ai_active = not _ai_active
	_call_action("set_ai", null, _ai_active)
	_ai_button.text = "Freeze live AI" if _ai_active else "Enable live AI"
	_set_status("Ships are fighting normally." if _ai_active else "AI frozen; targets remain test dummies.")


func _apply_environment() -> void:
	if is_instance_valid(game) and game.has_method("apply_combat_sandbox_environment"):
		game.call("apply_combat_sandbox_environment", _weather.get_item_text(_weather.selected), _time.get_item_text(_time.selected), _sea.get_item_text(_sea.selected))
		_set_status("Conditions applied immediately.")


func _refresh_targets() -> void:
	if not is_instance_valid(game) or not game.has_method("get_combat_sandbox_targets"):
		return
	var selected_id := _selected_target().get_instance_id() if is_instance_valid(_selected_target()) else 0
	var next_targets: Array = game.call("get_combat_sandbox_targets")
	var changed := next_targets.size() != _targets.size()
	if not changed:
		for index in range(next_targets.size()):
			if next_targets[index] != _targets[index]:
				changed = true
				break
	if not changed:
		return
	_targets.clear()
	_target_selector.clear()
	var next_selection := 0
	for node in next_targets:
		if not is_instance_valid(node):
			continue
		_targets.append(node)
		var state := "SUNK" if bool(node.get("is_sunk")) else ("DISABLED" if bool(node.get("is_incapacitated")) else "READY")
		_target_selector.add_item("%s  [%s]" % [String(node.get("display_name")), state])
		if node.get_instance_id() == selected_id:
			next_selection = _targets.size() - 1
	if not _targets.is_empty():
		_target_selector.select(next_selection)


func _selected_target() -> Node:
	if _target_selector == null or _targets.is_empty():
		return null
	var index := clampi(_target_selector.selected, 0, _targets.size() - 1)
	return _targets[index] if is_instance_valid(_targets[index]) else null


func _set_panel_input(panel_open: bool) -> void:
	if not is_instance_valid(game):
		return
	if game.has_method("set_combat_sandbox_panel_open"):
		game.call("set_combat_sandbox_panel_open", panel_open)


func _set_status(text: String) -> void:
	if _status:
		_status.text = text
