extends CanvasLayer

const BattleScenarios := preload("res://scripts/battle_scenarios.gd")

signal campaign_requested
signal custom_battle_requested(config: Dictionary)
signal handling_lab_requested(config: Dictionary)
signal combat_sandbox_requested
signal quit_requested

const SHIP_TYPES := ["Sloop", "Brig", "Frigate", "Ship of the Line", "Man o' War"]
const ALLY_TYPES := ["Courier", "Raider", "Escort", "Frigate", "Ship of the Line", "Man o' War"]
const ENEMY_TYPES := ["Courier", "Raider", "Escort", "Frigate", "Blockade", "Ship of the Line", "Man o' War"]
const WEATHER_OPTIONS := ["Clear", "Overcast", "Storm"]
const TIME_OPTIONS := ["Day", "Sunset", "Night"]
const SEA_OPTIONS := ["Calm", "Rolling", "Rough", "High Seas"]

var _root: Control
var _main_panel: PanelContainer
var _battle_panel: PanelContainer
var _lab_panel: PanelContainer
var _player_type: OptionButton
var _scenario_selector: OptionButton
var _scenario_description: Label
var _scenario_ids: Array[String] = []
var _battle_weather: OptionButton
var _battle_time: OptionButton
var _battle_sea: OptionButton
var _lab_ship_type: OptionButton
var _lab_weather: OptionButton
var _lab_time: OptionButton
var _lab_sea: OptionButton
var _ally_counts: Dictionary = {}
var _enemy_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_menu()


func show_menu() -> void:
	visible = true
	_main_panel.visible = true
	_battle_panel.visible = false
	_lab_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.035, 0.055, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var horizon := ColorRect.new()
	horizon.set_anchors_preset(Control.PRESET_FULL_RECT)
	horizon.offset_top = 330.0
	horizon.color = Color(0.035, 0.19, 0.25, 0.74)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(horizon)

	_main_panel = _make_panel(Vector2(460.0, 650.0))
	_root.add_child(_main_panel)
	_build_main_panel(_main_panel)

	_battle_panel = _make_panel(Vector2(1120.0, 900.0))
	_root.add_child(_battle_panel)
	_build_battle_panel(_battle_panel)

	_lab_panel = _make_panel(Vector2(760.0, 520.0))
	_root.add_child(_lab_panel)
	_build_lab_panel(_lab_panel)


func _make_panel(panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -panel_size * 0.5
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.072, 0.98)
	style.border_color = Color(0.62, 0.48, 0.24, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_main_panel(panel: PanelContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := _label("SABLE WAKE", 38, Color(0.94, 0.76, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("Age of Sail", 17, Color(0.64, 0.78, 0.78))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 48.0
	box.add_child(spacer)

	var campaign := _button("Start Campaign")
	campaign.pressed.connect(func() -> void: campaign_requested.emit())
	box.add_child(campaign)
	var custom := _button("Create Custom Battle")
	custom.pressed.connect(_show_battle_builder)
	box.add_child(custom)
	var handling_lab := _button("Ship Handling Lab")
	handling_lab.pressed.connect(_show_lab_builder)
	box.add_child(handling_lab)
	var combat_sandbox := _button("Combat Sandbox")
	combat_sandbox.pressed.connect(func() -> void: combat_sandbox_requested.emit())
	box.add_child(combat_sandbox)
	var quit := _button("Quit")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit)

	var note := _label("Build fleets, compare naval roles and enter combat immediately.", 13, Color(0.60, 0.66, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)


func _build_battle_panel(panel: PanelContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _label("CUSTOM BATTLE", 30, Color(0.94, 0.76, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("Choose your command ship and assemble both fleets.", 14, Color(0.67, 0.78, 0.77))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var scenario_row := HBoxContainer.new()
	scenario_row.custom_minimum_size.y = 56.0
	scenario_row.add_theme_constant_override("separation", 14)
	box.add_child(scenario_row)
	_scenario_selector = OptionButton.new()
	_scenario_selector.custom_minimum_size = Vector2(300.0, 46.0)
	for scenario in BattleScenarios.all():
		_scenario_ids.append(String(scenario.get("id", "fleet_trial")))
		_scenario_selector.add_item(String(scenario.get("title", "Battle")))
	scenario_row.add_child(_scenario_selector)
	_scenario_description = _label("Build both fleets freely and test any matchup.", 13, Color(0.67, 0.73, 0.69))
	_scenario_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scenario_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scenario_row.add_child(_scenario_description)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)

	var command_column := _section("YOUR COMMAND")
	columns.add_child(command_column)
	_player_type = OptionButton.new()
	_player_type.custom_minimum_size = Vector2(220.0, 42.0)
	for type_name in SHIP_TYPES:
		_player_type.add_item(type_name)
	_player_type.select(1)
	command_column.add_child(_player_type)
	command_column.add_child(_info_card("Sloop", "Low, narrow and extremely quick."))
	command_column.add_child(_info_card("Brig", "Compact two-masted all-rounder."))
	command_column.add_child(_info_card("Frigate", "Long, elegant and aggressive."))
	command_column.add_child(_info_card("Ship of the Line", "Towering three-deck battle fortress."))
	command_column.add_child(_info_card("Man o' War", "Four-deck flagship with a heavy mortar."))

	var ally_column := _section("ALLIED FLEET")
	columns.add_child(ally_column)
	for type_name in ALLY_TYPES:
		var row := _count_row(type_name, 0, 4)
		ally_column.add_child(row.control)
		_ally_counts[type_name] = row.spin
	ally_column.add_child(_role_note("Raider", "Flanks and attacks sails."))
	ally_column.add_child(_role_note("Escort", "Screens your command ship."))
	ally_column.add_child(_role_note("Frigate", "Fast line fighter with a long broadside."))
	ally_column.add_child(_role_note("Ship of the Line", "Closes in and trades crushing broadsides."))
	ally_column.add_child(_role_note("Man o' War", "Anchors the line with four gun decks."))

	var enemy_column := _section("ENEMY FLEET")
	columns.add_child(enemy_column)
	for type_name in ENEMY_TYPES:
		var default_count := 1 if type_name == "Raider" else 0
		var row := _count_row(type_name, default_count, 6)
		enemy_column.add_child(row.control)
		_enemy_counts[type_name] = row.spin
	enemy_column.add_child(_role_note("Courier", "Escapes instead of dueling."))
	enemy_column.add_child(_role_note("Frigate", "Runs down lighter ships and controls range."))
	enemy_column.add_child(_role_note("Blockade", "Holds a firing line."))
	enemy_column.add_child(_role_note("Man o' War", "Bombards formations before closing."))

	var conditions := _condition_strip("BATTLE CONDITIONS")
	box.add_child(conditions.control)
	_battle_weather = _condition_selector(conditions.row, "Weather", WEATHER_OPTIONS, 0)
	_battle_time = _condition_selector(conditions.row, "Time", TIME_OPTIONS, 0)
	_battle_sea = _condition_selector(conditions.row, "Sea", SEA_OPTIONS, 1)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var back := _button("Back")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_show_main_panel)
	actions.add_child(back)
	var launch := _button("Launch Battle")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch.pressed.connect(_launch_custom_battle)
	actions.add_child(launch)
	_scenario_selector.item_selected.connect(_on_scenario_selected)


func _build_lab_panel(panel: PanelContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := _label("SHIP HANDLING LAB", 30, Color(0.94, 0.76, 0.38))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("Test the same ship, wind and sea model used in battle.", 14, Color(0.67, 0.78, 0.77))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var ship_section := _section("TEST SHIP")
	ship_section.custom_minimum_size.x = 0.0
	box.add_child(ship_section)
	_lab_ship_type = OptionButton.new()
	_lab_ship_type.custom_minimum_size = Vector2(320.0, 46.0)
	_lab_ship_type.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for type_name in ["Brig", "Frigate", "Ship of the Line", "Man o' War"]:
		_lab_ship_type.add_item(type_name)
	ship_section.add_child(_lab_ship_type)

	var conditions := _condition_strip("TEST CONDITIONS")
	box.add_child(conditions.control)
	_lab_weather = _condition_selector(conditions.row, "Weather", WEATHER_OPTIONS, 0)
	_lab_time = _condition_selector(conditions.row, "Time", TIME_OPTIONS, 0)
	_lab_sea = _condition_selector(conditions.row, "Sea", SEA_OPTIONS, 1)

	var note := _label("Conditions affect visibility, light, wind force, wave height and physical buoyancy.", 13, Color(0.60, 0.68, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var back := _button("Back")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_show_main_panel)
	actions.add_child(back)
	var launch := _button("Enter Lab")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch.pressed.connect(_launch_handling_lab)
	actions.add_child(launch)


func _condition_strip(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.08, 0.96)
	style.border_color = Color(0.34, 0.30, 0.20, 0.95)
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := _label(title, 15, Color(0.91, 0.72, 0.34))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	return {"control": panel, "row": row}


func _condition_selector(parent: HBoxContainer, title: String, options: Array, default_index: int) -> OptionButton:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var heading := _label(title, 12, Color(0.65, 0.72, 0.69))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(180.0, 40.0)
	for option in options:
		selector.add_item(String(option))
	selector.select(default_index)
	box.add_child(selector)
	parent.add_child(box)
	return selector


func _section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 270.0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	var heading := _label(title, 18, Color(0.91, 0.72, 0.34))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var rule := HSeparator.new()
	box.add_child(rule)
	return box


func _count_row(title: String, value: int, maximum: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 42.0
	var label := _label(title, 15, Color(0.86, 0.88, 0.82))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size.x = 82.0
	row.add_child(spin)
	return {"control": row, "spin": spin}


func _info_card(title: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.09, 0.9)
	style.border_color = Color(0.30, 0.28, 0.20)
	style.set_border_width_all(1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var text := _label("%s\n%s" % [title, body], 13, Color(0.73, 0.75, 0.69))
	panel.add_child(text)
	return panel


func _role_note(title: String, body: String) -> Label:
	var note := _label("%s: %s" % [title, body], 12, Color(0.56, 0.64, 0.62))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return note


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 50.0
	button.add_theme_font_size_override("font_size", 17)
	return button


func _show_battle_builder() -> void:
	_main_panel.visible = false
	_battle_panel.visible = true
	_lab_panel.visible = false


func _on_scenario_selected(index: int) -> void:
	if index < 0 or index >= _scenario_ids.size():
		return
	_apply_scenario_to_builder(BattleScenarios.get_definition(_scenario_ids[index]))


func _apply_scenario_to_builder(scenario: Dictionary) -> void:
	_scenario_description.text = String(scenario.get("brief", ""))
	_select_option_text(_player_type, String(scenario.get("player_type", "Brig")))
	for type_name in ALLY_TYPES:
		(_ally_counts[type_name] as SpinBox).value = int((scenario.get("allies", {}) as Dictionary).get(type_name, 0))
	for type_name in ENEMY_TYPES:
		(_enemy_counts[type_name] as SpinBox).value = int((scenario.get("enemies", {}) as Dictionary).get(type_name, 0))
	_select_option_text(_battle_weather, String(scenario.get("weather", "Clear")))
	_select_option_text(_battle_time, String(scenario.get("time_of_day", "Day")))
	_select_option_text(_battle_sea, String(scenario.get("sea_condition", "Rolling")))


func _select_option_text(selector: OptionButton, wanted: String) -> void:
	for index in range(selector.item_count):
		if selector.get_item_text(index) == wanted:
			selector.select(index)
			return


func _show_lab_builder() -> void:
	_main_panel.visible = false
	_battle_panel.visible = false
	_lab_panel.visible = true


func _show_main_panel() -> void:
	_main_panel.visible = true
	_battle_panel.visible = false
	_lab_panel.visible = false


func _launch_custom_battle() -> void:
	var allies := {}
	var enemies := {}
	for type_name in ALLY_TYPES:
		allies[type_name] = int((_ally_counts[type_name] as SpinBox).value)
	for type_name in ENEMY_TYPES:
		enemies[type_name] = int((_enemy_counts[type_name] as SpinBox).value)
	var enemy_total := 0
	for count in enemies.values():
		enemy_total += int(count)
	if enemy_total <= 0:
		enemies["Raider"] = 1
	var scenario_id := _scenario_ids[_scenario_selector.selected] if _scenario_selector.selected >= 0 and _scenario_selector.selected < _scenario_ids.size() else "fleet_trial"
	var scenario := BattleScenarios.get_definition(scenario_id)
	var config := {
		"scenario_id": scenario_id,
		"player_type": SHIP_TYPES[_player_type.selected],
		"allies": allies,
		"enemies": enemies,
		"weather": WEATHER_OPTIONS[_battle_weather.selected],
		"time_of_day": TIME_OPTIONS[_battle_time.selected],
		"sea_condition": SEA_OPTIONS[_battle_sea.selected],
	}
	for key in ["title", "brief", "objective", "objective_title", "objective_detail", "formation", "player_spawn", "player_rotation", "fort", "fort_position", "forts", "control_points", "scenario_islands", "reinforcements", "max_active_ships"]:
		if scenario.has(key):
			config[key] = scenario[key]
	custom_battle_requested.emit(config)


func _launch_handling_lab() -> void:
	handling_lab_requested.emit({
		"player_type": _lab_ship_type.get_item_text(_lab_ship_type.selected),
		"weather": WEATHER_OPTIONS[_lab_weather.selected],
		"time_of_day": TIME_OPTIONS[_lab_time.selected],
		"sea_condition": SEA_OPTIONS[_lab_sea.selected],
	})
