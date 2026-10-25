extends CanvasLayer

signal resume_requested
signal return_to_campaign_requested
signal settings_changed(settings: Dictionary)
signal quit_requested

const MinimapControl := preload("res://scripts/minimap.gd")

var _root: Control
var _health_bar: ProgressBar
var _ship_label: Label
var _speed_label: Label
var _sail_label: Label
var _wind_label: Label
var _reload_label: Label
var _battery_label: Label
var _shot_mode_label: Label
var _brace_label: Label
var _hazard_label: Label
var _enemy_label: Label
var _enemy_markers: Array[Control] = []
var _minimap: Control
var _aim_layer: Control
var _aim_label: Label
var _aim_hint_label: Label
var _aim_stage_label: Label
var _aim_focus_bar: ProgressBar
var _hit_marker_label: Label
var _hit_detail_label: Label
var _hit_marker_until := 0.0
var _threat_indicator: Label
var _threat_until := 0.0
var _combat_warning_panel: PanelContainer
var _combat_warning_title: Label
var _combat_warning_subtitle: Label
var _combat_warning_until := 0.0
var _combat_objective_panel: PanelContainer
var _combat_objective_title: Label
var _combat_objective_status: Label
var _combat_objective_action: Label
var _combat_objective_detail: Label
var _boarding_panel: PanelContainer
var _boarding_title: Label
var _boarding_subtitle: Label
var _boarding_progress_bar: ProgressBar
var _damage_flash: ColorRect
var _damage_flash_strength := 0.0
var _debug_panel: PanelContainer
var _debug_label: Label
var _pause_overlay: Control
var _return_button: Button
var _sensitivity_slider: HSlider
var _camera_distance_slider: HSlider
var _minimap_zoom_slider: HSlider
var _invert_y_check: CheckBox
var _fullscreen_check: CheckBox
var _banner_panel: PanelContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_until := 0.0
var _debug_visible := false
var _settings := {
	"mouse_sensitivity": 0.0032,
	"camera_distance": 18.5,
	"minimap_zoom": 1.0,
	"invert_y": false,
	"fullscreen": true,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if _banner_panel and _banner_until > 0.0 and now > _banner_until:
		_banner_panel.visible = false
		_banner_until = 0.0
	if _hit_marker_label and _hit_marker_until > 0.0:
		var hit_alpha := clampf((_hit_marker_until - now) / 0.45, 0.0, 1.0)
		_hit_marker_label.modulate.a = hit_alpha
		_hit_detail_label.modulate.a = hit_alpha
		if now > _hit_marker_until:
			_hit_marker_label.visible = false
			_hit_detail_label.visible = false
			_hit_marker_until = 0.0
	if _combat_warning_panel and _combat_warning_until > 0.0:
		_combat_warning_panel.modulate.a = clampf((_combat_warning_until - now) / 0.5, 0.0, 1.0)
		if now > _combat_warning_until:
			_combat_warning_panel.visible = false
			_combat_warning_until = 0.0
	if _threat_indicator and _threat_until > 0.0 and now > _threat_until:
		_threat_indicator.visible = false
		_threat_until = 0.0
	if _damage_flash:
		_damage_flash_strength = move_toward(_damage_flash_strength, 0.0, _delta * 2.6)
		_damage_flash.color.a = _damage_flash_strength
		_damage_flash.visible = _damage_flash_strength > 0.01


func set_stats(data: Dictionary, enemy_count: int, wind_direction: Vector3, wind_strength: float) -> void:
	if _health_bar == null:
		return

	var max_health := float(data.get("max_health", 100.0))
	var health := float(data.get("health", max_health))
	_health_bar.max_value = max_health
	_health_bar.value = health
	_ship_label.text = "%s  %d/%d" % [data.get("name", "Ship"), int(ceil(health)), int(max_health)]
	_speed_label.text = "%.1f kn   %s SAILS %d%%" % [
		float(data.get("speed", 0.0)),
		String(data.get("sail_state", "Battle")),
		int(float(data.get("sail", 0.0)) * 100.0),
	]
	_sail_label.text = "RIG %d%%" % int(float(data.get("sail_integrity", 100.0)))
	if _battery_label:
		var cannon_count := int(data.get("guns_per_side", int(data.get("base_cannons_per_side", 4)) * int(data.get("cannon_decks", 1))))
		var port_active := int(data.get("port_active_guns", cannon_count))
		var starboard_active := int(data.get("starboard_active_guns", cannon_count))
		_battery_label.text = "PORT %s    STARBOARD %s" % [
			_battery_pips(cannon_count, port_active, float(data.get("port_reload", 0.0))),
			_battery_pips(cannon_count, starboard_active, float(data.get("starboard_reload", 0.0))),
		]
	if _brace_label:
		var brace_active := bool(data.get("brace", false))
		var perfect_brace := bool(data.get("perfect_brace", false))
		_brace_label.visible = brace_active or float(data.get("brace_stamina", 1.0)) < 0.98
		_brace_label.text = "%s %d%%" % ["PERFECT BRACE" if perfect_brace else "BRACE", int(float(data.get("brace_stamina", 1.0)) * 100.0)]
		_brace_label.add_theme_color_override("font_color", Color(0.52, 1.0, 0.72) if perfect_brace else (Color(0.96, 0.72, 0.36) if brace_active else Color(0.76, 0.88, 0.86)))
	if _hazard_label:
		var repair_active := bool(data.get("repairing", false))
		_hazard_label.visible = repair_active or health < max_health * 0.72
		_hazard_label.text = "REPAIR  x%d" % int(data.get("repair_supplies", 0))
		_hazard_label.add_theme_color_override("font_color", Color(0.52, 1.0, 0.72) if repair_active else Color(0.76, 0.88, 0.86))
	_enemy_label.text = "Targets %d" % enemy_count
	_update_debug(data, enemy_count, wind_direction, wind_strength)


func _battery_pips(cannon_count: int, active_count: int, reload_time: float) -> String:
	var physical_total := maxi(cannon_count, 1)
	var physical_active := clampi(active_count, 0, physical_total)
	var total := mini(physical_total, 8)
	var active := total
	if physical_active < physical_total:
		active = clampi(int(floor(float(physical_active) / float(physical_total) * float(total))), 0, total - 1)
	var result := ""
	for index in range(total):
		if index >= active:
			result += "x"
		elif reload_time <= 0.05:
			result += "●"
		else:
			result += "○"
	return result


func set_world_state(player: Node3D, enemy_nodes: Array, island_data: Array) -> void:
	if _minimap and _minimap.has_method("set_world_state"):
		_minimap.set_world_state(player, enemy_nodes, island_data)
	_update_enemy_markers(player, enemy_nodes)


func set_aim_state(active: bool, side: int, ready: bool, focus := 0.0, has_mortar := false, mortar_reload := 0.0) -> void:
	if _aim_layer == null:
		return

	_aim_layer.visible = active
	if not active:
		return

	var side_text := "NO BROADSIDE"
	if side < 0:
		side_text = "PORT"
	elif side > 0:
		side_text = "STARBOARD"

	_aim_label.text = "+"
	_aim_stage_label.visible = false
	_aim_focus_bar.value = focus * 100.0
	_aim_hint_label.text = "%s  %s" % [side_text, "READY" if ready else "RELOADING"]
	var aim_color := Color(0.90, 0.96, 0.90)
	if side == 0:
		aim_color = Color(0.58, 0.64, 0.62)
	elif not ready:
		aim_color = Color(0.95, 0.54, 0.28)
	_aim_label.add_theme_color_override("font_color", aim_color)
	_aim_hint_label.add_theme_color_override("font_color", aim_color)
	var fill := _aim_focus_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color(1.0, 0.74, 0.25, 0.94) if focus >= 0.82 and ready else (Color(0.45, 0.86, 0.74, 0.88) if ready else Color(0.92, 0.40, 0.20, 0.82))


func show_banner(title: String, subtitle: String = "", duration: float = 3.0) -> void:
	if _banner_panel == null:
		return

	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_subtitle.visible = subtitle.length() > 0
	_banner_panel.visible = true
	_banner_until = Time.get_ticks_msec() * 0.001 + duration


func hide_banner() -> void:
	if _banner_panel:
		_banner_panel.visible = false
	_banner_until = 0.0


func show_hit_marker(report: Dictionary) -> void:
	if _hit_marker_label == null:
		return

	var zone := String(report.get("zone", "hull")).to_upper()
	var shot := String(report.get("shot_mode", "round")).to_upper()
	var angle := String(report.get("hit_angle", "solid")).to_upper()
	var angle_prefix := "" if angle == "SOLID" else "%s " % angle
	var damage_text := _format_actual_damage(report)
	var critical := bool(report.get("critical", false))
	_hit_marker_label.text = "X"
	_hit_detail_label.text = "%s%s %s  %s" % [angle_prefix, shot, zone, damage_text]
	if critical:
		_hit_detail_label.text = "CRITICAL %s%s %s  %s" % [angle_prefix, shot, zone, damage_text]
	_hit_marker_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42) if not critical else Color(1.0, 0.42, 0.20))
	_hit_detail_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42) if not critical else Color(1.0, 0.42, 0.20))
	_hit_marker_label.modulate.a = 1.0
	_hit_detail_label.modulate.a = 1.0
	_hit_marker_label.visible = true
	_hit_detail_label.visible = true
	_hit_marker_until = Time.get_ticks_msec() * 0.001 + (0.9 if critical else 0.7)


func show_damage_warning(report: Dictionary) -> void:
	var zone := String(report.get("zone", "hull")).to_upper()
	var shot := String(report.get("shot_mode", "round")).to_upper()
	var angle := String(report.get("hit_angle", "solid")).to_upper()
	var angle_prefix := "" if angle == "SOLID" else "%s " % angle
	var damage_text := _format_actual_damage(report)
	var prefix := "PERFECT BRACE " if bool(report.get("perfect_brace", false)) else ("BRACED " if bool(report.get("braced", false)) else "")
	show_combat_warning("%s IMPACT" % zone, "%s%s%s  %s" % [prefix, angle_prefix, shot, damage_text], 1.25)
	var flash_strength := 0.10 if bool(report.get("perfect_brace", false)) else (0.26 if bool(report.get("critical", false)) else 0.16)
	_damage_flash_strength = maxf(_damage_flash_strength, flash_strength)


func show_directional_threat(world_position: Vector3) -> void:
	show_directional_hazard(world_position, "INCOMING BROADSIDE")


func show_directional_hazard(world_position: Vector3, label := "ROGUE WAVE") -> void:
	if _threat_indicator == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var screen_position := camera.unproject_position(world_position)
	var threat_from_left := screen_position.x < viewport_width * 0.5
	_threat_indicator.text = "<<< %s" % label if threat_from_left else "%s >>>" % label
	_threat_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if threat_from_left else HORIZONTAL_ALIGNMENT_RIGHT
	_threat_indicator.anchor_left = 0.0 if threat_from_left else 1.0
	_threat_indicator.anchor_right = 0.0 if threat_from_left else 1.0
	_threat_indicator.offset_left = 24.0 if threat_from_left else -344.0
	_threat_indicator.offset_right = 344.0 if threat_from_left else -24.0
	_threat_indicator.visible = true
	_threat_until = Time.get_ticks_msec() * 0.001 + 1.35


func _format_actual_damage(report: Dictionary) -> String:
	var parts: Array[String] = []
	var hull := float(report.get("health_damage", 0.0))
	var sails := float(report.get("sail_damage", 0.0))
	var rudder := float(report.get("rudder_damage", 0.0))
	var guns := float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	if hull >= 0.5:
		parts.append("Hull %.0f" % hull)
	if sails >= 0.5:
		parts.append("Sails %.0f" % sails)
	if guns >= 0.5:
		parts.append("Guns %.0f" % guns)
	if rudder >= 0.5:
		parts.append("Rudder %.0f" % rudder)
	var disabled_cannons := int(report.get("disabled_cannons", 0))
	if disabled_cannons > 0:
		parts.append("%d cannon disabled" % disabled_cannons)
	if parts.is_empty():
		return "No structural damage"
	return " | ".join(parts)


func show_combat_warning(title: String, subtitle: String = "", duration: float = 1.4) -> void:
	if _combat_warning_panel == null:
		return

	_combat_warning_title.text = title
	_combat_warning_subtitle.text = subtitle
	_combat_warning_subtitle.visible = subtitle.length() > 0
	_combat_warning_panel.visible = true
	_combat_warning_panel.modulate.a = 1.0
	_combat_warning_until = Time.get_ticks_msec() * 0.001 + duration


func show_boarding_prompt(active: bool, target_name: String = "", distance: float = 0.0, progress: float = 0.0, status: String = "", title: String = "BOARDING OPPORTUNITY") -> void:
	if _boarding_panel == null:
		return

	_boarding_panel.visible = active
	if not active:
		return
	_boarding_title.text = title
	_boarding_subtitle.text = "%s  %.0fm\n%s" % [target_name, distance, status]
	if _boarding_progress_bar:
		_boarding_progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func set_return_destination(label: String) -> void:
	if _return_button:
		_return_button.text = label


func set_combat_objective(data: Dictionary) -> void:
	if _combat_objective_panel == null:
		return

	_combat_objective_panel.visible = true
	var tone := String(data.get("tone", "neutral"))
	var accent := Color(0.78, 0.90, 0.86)
	var panel_color := Color(0.02, 0.035, 0.045, 0.76)
	if tone == "danger":
		accent = Color(1.0, 0.46, 0.28)
		panel_color = Color(0.12, 0.035, 0.025, 0.80)
	elif tone == "capture":
		accent = Color(1.0, 0.82, 0.38)
		panel_color = Color(0.10, 0.075, 0.025, 0.80)
	elif tone == "complete":
		accent = Color(0.48, 1.0, 0.66)
		panel_color = Color(0.02, 0.08, 0.045, 0.80)
	elif tone == "attack":
		accent = Color(0.55, 0.82, 1.0)
		panel_color = Color(0.02, 0.05, 0.075, 0.78)

	_combat_objective_panel.add_theme_stylebox_override("panel", _panel_style(panel_color))
	_combat_objective_title.text = String(data.get("title", "Tactical Orders"))
	_combat_objective_title.add_theme_color_override("font_color", accent)
	_combat_objective_status.text = String(data.get("status", ""))
	_combat_objective_action.text = String(data.get("action", ""))
	_combat_objective_action.visible = not _combat_objective_action.text.is_empty()
	_combat_objective_action.add_theme_color_override("font_color", accent)
	_combat_objective_detail.text = String(data.get("detail", ""))
	_combat_objective_detail.visible = false


func toggle_debug() -> void:
	_debug_visible = not _debug_visible
	if _debug_panel:
		_debug_panel.visible = _debug_visible


func show_pause_menu(open: bool) -> void:
	if _pause_overlay:
		_pause_overlay.visible = open


func apply_settings(settings: Dictionary) -> void:
	for key in settings.keys():
		_settings[key] = settings[key]

	if _minimap and _minimap.has_method("set_zoom"):
		_minimap.set_zoom(float(_settings.get("minimap_zoom", 1.0)))


func _build() -> void:
	var root := Control.new()
	_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)

	var vertical := VBoxContainer.new()
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vertical)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertical.add_child(top)

	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.72)))
	top.add_child(stat_panel)

	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 5)
	stat_panel.add_child(stat_box)

	_ship_label = _make_label("Sable Wake", 16)
	stat_box.add_child(_ship_label)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(260.0, 16.0)
	_health_bar.show_percentage = false
	stat_box.add_child(_health_bar)

	_speed_label = _make_label("Speed 0.0 kn", 13)
	_sail_label = _make_label("Battle Sails 38%\nRig 100%", 13)
	_reload_label = _make_label("Port 0.0s  Starboard 0.0s", 13)
	_reload_label.visible = false
	_battery_label = _make_label("P ●●●●    S ●●●●", 13)
	_battery_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	_shot_mode_label = _make_label("Broadside: Round shot", 12)
	_shot_mode_label.visible = false
	_brace_label = _make_label("Brace 100%  [Space]", 12)
	_hazard_label = _make_label("Repair kits 3  [Hold R]", 12)
	stat_box.add_child(_speed_label)
	stat_box.add_child(_sail_label)
	stat_box.add_child(_reload_label)
	stat_box.add_child(_battery_label)
	stat_box.add_child(_shot_mode_label)
	stat_box.add_child(_brace_label)
	stat_box.add_child(_hazard_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var mission_panel := PanelContainer.new()
	mission_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.64)))
	top.add_child(mission_panel)

	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 5)
	mission_panel.add_child(mission_box)

	_enemy_label = _make_label("Targets 3", 16)
	_wind_label = _make_label("Wind E 1.0x", 13)
	_wind_label.visible = false
	mission_box.add_child(_enemy_label)
	mission_box.add_child(_wind_label)

	var minimap_panel := PanelContainer.new()
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.62)))
	minimap_panel.anchor_left = 0.5
	minimap_panel.anchor_right = 0.5
	minimap_panel.anchor_top = 0.0
	minimap_panel.anchor_bottom = 0.0
	minimap_panel.offset_left = -330.0
	minimap_panel.offset_right = 330.0
	minimap_panel.offset_top = 18.0
	minimap_panel.offset_bottom = 76.0
	root.add_child(minimap_panel)

	_minimap = MinimapControl.new()
	minimap_panel.add_child(_minimap)

	_debug_panel = PanelContainer.new()
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.visible = false
	_debug_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.72)))
	_debug_panel.anchor_left = 0.0
	_debug_panel.anchor_right = 0.0
	_debug_panel.anchor_top = 1.0
	_debug_panel.anchor_bottom = 1.0
	_debug_panel.offset_left = 18.0
	_debug_panel.offset_right = 360.0
	_debug_panel.offset_top = -156.0
	_debug_panel.offset_bottom = -18.0
	root.add_child(_debug_panel)

	_debug_label = _make_label("", 12)
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_panel.add_child(_debug_label)

	_create_aim_layer(root)
	_create_enemy_marker_pool(root)
	_create_combat_feedback(root)
	_create_combat_objective(root)
	_create_boarding_prompt(root)
	_create_pause_menu(root)

	var vertical_spacer := Control.new()
	vertical_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical.add_child(vertical_spacer)

	_banner_panel = PanelContainer.new()
	_banner_panel.visible = false
	_banner_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.76)))
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_top = 0.82
	_banner_panel.anchor_bottom = 0.82
	_banner_panel.offset_left = -260.0
	_banner_panel.offset_right = 260.0
	_banner_panel.offset_top = -36.0
	_banner_panel.offset_bottom = 36.0
	root.add_child(_banner_panel)

	var banner_box := VBoxContainer.new()
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_panel.add_child(banner_box)

	_banner_title = _make_label("", 19)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _make_label("", 13)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(_banner_title)
	banner_box.add_child(_banner_subtitle)


func _create_aim_layer(root: Control) -> void:
	_aim_layer = Control.new()
	_aim_layer.visible = false
	_aim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_layer.anchor_left = 0.5
	_aim_layer.anchor_right = 0.5
	_aim_layer.anchor_top = 0.5
	_aim_layer.anchor_bottom = 0.5
	_aim_layer.offset_left = -150.0
	_aim_layer.offset_right = 150.0
	_aim_layer.offset_top = -48.0
	_aim_layer.offset_bottom = 92.0
	root.add_child(_aim_layer)

	_aim_label = _make_label("+", 34)
	_aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_label.anchor_left = 0.0
	_aim_label.anchor_right = 1.0
	_aim_label.anchor_top = 0.0
	_aim_label.anchor_bottom = 0.0
	_aim_label.offset_top = -6.0
	_aim_label.offset_bottom = 34.0
	_aim_layer.add_child(_aim_label)

	_aim_stage_label = _make_label("SPREAD", 13)
	_aim_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_stage_label.anchor_right = 1.0
	_aim_stage_label.offset_top = 36.0
	_aim_stage_label.offset_bottom = 56.0
	_aim_layer.add_child(_aim_stage_label)

	_aim_focus_bar = ProgressBar.new()
	_aim_focus_bar.show_percentage = false
	_aim_focus_bar.min_value = 0.0
	_aim_focus_bar.max_value = 100.0
	_aim_focus_bar.anchor_left = 0.5
	_aim_focus_bar.anchor_right = 0.5
	_aim_focus_bar.offset_left = -92.0
	_aim_focus_bar.offset_right = 92.0
	_aim_focus_bar.offset_top = 58.0
	_aim_focus_bar.offset_bottom = 64.0
	var focus_background := StyleBoxFlat.new()
	focus_background.bg_color = Color(0.01, 0.02, 0.025, 0.82)
	focus_background.set_corner_radius_all(2)
	var focus_fill := StyleBoxFlat.new()
	focus_fill.bg_color = Color(0.45, 0.86, 0.74, 0.88)
	focus_fill.set_corner_radius_all(2)
	_aim_focus_bar.add_theme_stylebox_override("background", focus_background)
	_aim_focus_bar.add_theme_stylebox_override("fill", focus_fill)
	_aim_layer.add_child(_aim_focus_bar)

	_aim_hint_label = _make_label("", 12)
	_aim_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_hint_label.anchor_left = 0.0
	_aim_hint_label.anchor_right = 1.0
	_aim_hint_label.anchor_top = 0.0
	_aim_hint_label.anchor_bottom = 0.0
	_aim_hint_label.offset_top = 70.0
	_aim_hint_label.offset_bottom = 90.0
	_aim_layer.add_child(_aim_hint_label)


func _create_enemy_marker_pool(root: Control) -> void:
	for i in range(6):
		var marker := PanelContainer.new()
		marker.name = "EnemyMarker%d" % i
		marker.visible = false
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.custom_minimum_size = Vector2(124.0, 34.0)
		marker.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.025, 0.028, 0.46)))
		root.add_child(marker)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		marker.add_child(box)

		var name_label := _make_label("Enemy", 11)
		name_label.name = "NameLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)

		var health := ProgressBar.new()
		health.name = "HealthBar"
		health.custom_minimum_size = Vector2(104.0, 5.0)
		health.show_percentage = false
		health.max_value = 100.0
		box.add_child(health)

		var state_label := _make_label("", 9)
		state_label.name = "StateLabel"
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(state_label)

		_enemy_markers.append(marker)


func _create_combat_objective(root: Control) -> void:
	_combat_objective_panel = PanelContainer.new()
	_combat_objective_panel.name = "CombatObjective"
	_combat_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.76)))
	_combat_objective_panel.anchor_left = 1.0
	_combat_objective_panel.anchor_right = 1.0
	_combat_objective_panel.anchor_top = 0.26
	_combat_objective_panel.anchor_bottom = 0.26
	_combat_objective_panel.offset_left = -322.0
	_combat_objective_panel.offset_right = -18.0
	_combat_objective_panel.offset_top = 0.0
	_combat_objective_panel.offset_bottom = 76.0
	root.add_child(_combat_objective_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_combat_objective_panel.add_child(box)

	_combat_objective_title = _make_label("Tactical Orders", 16)
	_combat_objective_status = _make_label("Find a firing angle.", 11)
	_combat_objective_action = _make_label("Close distance and choose a broadside.", 13)
	_combat_objective_detail = _make_label("", 10)
	_combat_objective_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_objective_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_objective_detail.visible = false
	box.add_child(_combat_objective_title)
	box.add_child(_combat_objective_status)
	box.add_child(_combat_objective_action)
	box.add_child(_combat_objective_detail)


func _update_enemy_markers(player: Node3D, enemy_nodes: Array) -> void:
	if _root == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_hide_enemy_markers()
		return

	var marker_index := 0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for enemy in enemy_nodes:
		if marker_index >= _enemy_markers.size():
			break
		if not is_instance_valid(enemy) or bool(enemy.get("is_sunk")):
			continue

		var marker: Control = _enemy_markers[marker_index]
		var hull_class := String(enemy.get("hull_class"))
		var marker_height := 6.0
		match hull_class:
			"Frigate": marker_height = 8.5
			"Ship of the Line": marker_height = 10.8
			"Man o' War": marker_height = 12.6
		var world_pos: Vector3 = enemy.global_position + Vector3.UP * marker_height
		if camera.is_position_behind(world_pos):
			marker.visible = false
			marker_index += 1
			continue

		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		var on_screen: bool = screen_pos.x > 12.0 and screen_pos.x < viewport_size.x - 12.0 and screen_pos.y > 86.0 and screen_pos.y < viewport_size.y - 96.0
		var distance: float = player.global_position.distance_to(enemy.global_position) if is_instance_valid(player) else 0.0
		marker.visible = on_screen and distance < 190.0
		if marker.visible:
			_update_enemy_marker_content(marker, enemy, distance)
			marker.position = screen_pos - Vector2(62.0, 42.0)
		marker_index += 1

	for i in range(marker_index, _enemy_markers.size()):
		_enemy_markers[i].visible = false


func _hide_enemy_markers() -> void:
	for marker in _enemy_markers:
		marker.visible = false


func _update_enemy_marker_content(marker: Control, enemy: Node, distance: float) -> void:
	var telemetry: Dictionary = {}
	if enemy.has_method("get_telemetry"):
		telemetry = enemy.get_telemetry()
	var name_label := marker.find_child("NameLabel", true, false) as Label
	var health_bar := marker.find_child("HealthBar", true, false) as ProgressBar
	var state_label := marker.find_child("StateLabel", true, false) as Label
	var health := float(telemetry.get("health", enemy.get("health") if enemy.get("health") != null else 0.0))
	var max_health := maxf(float(telemetry.get("max_health", enemy.get("max_health") if enemy.get("max_health") != null else 100.0)), 1.0)
	if name_label:
		name_label.text = "%s  %.0fm" % [String(telemetry.get("name", enemy.name)), distance]
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if state_label:
		state_label.text = _enemy_state_text(enemy, telemetry)
		state_label.visible = not state_label.text.is_empty()
		state_label.add_theme_color_override("font_color", _enemy_state_color(enemy, telemetry))


func _enemy_state_text(enemy: Node, telemetry: Dictionary) -> String:
	if bool(enemy.get("is_incapacitated")):
		return ""
	var sail := float(telemetry.get("sail_integrity", 100.0))
	var rudder := float(telemetry.get("rudder_integrity", 100.0))
	var port_cannon := float(telemetry.get("port_cannon_integrity", 100.0))
	var starboard_cannon := float(telemetry.get("starboard_cannon_integrity", 100.0))
	var damage_icons: Array[String] = []
	if sail < 35.0:
		damage_icons.append("SAILS")
	if rudder < 35.0:
		damage_icons.append("RUDDER")
	if maxf(port_cannon, starboard_cannon) < 35.0:
		damage_icons.append("GUNS")
	return " / ".join(damage_icons)


func _enemy_state_color(enemy: Node, telemetry: Dictionary) -> Color:
	if enemy.has_method("get_ai_state_name") and String(enemy.get_ai_state_name()) == "broadside":
		return Color(1.0, 0.50, 0.28)
	var health := float(telemetry.get("health", enemy.get("health") if enemy.get("health") != null else 100.0))
	var max_health := maxf(float(telemetry.get("max_health", enemy.get("max_health") if enemy.get("max_health") != null else 100.0)), 1.0)
	if health / max_health < 0.35:
		return Color(1.0, 0.36, 0.26)
	return Color(0.80, 0.92, 0.88)


func _create_combat_feedback(root: Control) -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.name = "DamageFlash"
	_damage_flash.visible = false
	_damage_flash.color = Color(0.85, 0.08, 0.02, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_damage_flash)

	_hit_marker_label = _make_label("X", 30)
	_hit_marker_label.name = "HitMarker"
	_hit_marker_label.visible = false
	_hit_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_marker_label.anchor_left = 0.5
	_hit_marker_label.anchor_right = 0.5
	_hit_marker_label.anchor_top = 0.5
	_hit_marker_label.anchor_bottom = 0.5
	_hit_marker_label.offset_left = -40.0
	_hit_marker_label.offset_right = 40.0
	_hit_marker_label.offset_top = -74.0
	_hit_marker_label.offset_bottom = -30.0
	root.add_child(_hit_marker_label)

	_hit_detail_label = _make_label("", 13)
	_hit_detail_label.name = "HitMarkerDetail"
	_hit_detail_label.visible = false
	_hit_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_detail_label.anchor_left = 0.5
	_hit_detail_label.anchor_right = 0.5
	_hit_detail_label.anchor_top = 0.5
	_hit_detail_label.anchor_bottom = 0.5
	_hit_detail_label.offset_left = -100.0
	_hit_detail_label.offset_right = 100.0
	_hit_detail_label.offset_top = -34.0
	_hit_detail_label.offset_bottom = -8.0
	root.add_child(_hit_detail_label)

	_threat_indicator = _make_label("", 18)
	_threat_indicator.name = "ThreatIndicator"
	_threat_indicator.visible = false
	_threat_indicator.anchor_top = 0.5
	_threat_indicator.anchor_bottom = 0.5
	_threat_indicator.offset_top = -18.0
	_threat_indicator.offset_bottom = 18.0
	_threat_indicator.add_theme_color_override("font_color", Color(1.0, 0.30, 0.18))
	root.add_child(_threat_indicator)

	_combat_warning_panel = PanelContainer.new()
	_combat_warning_panel.name = "CombatWarning"
	_combat_warning_panel.visible = false
	_combat_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_warning_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.20, 0.035, 0.025, 0.78)))
	_combat_warning_panel.anchor_left = 0.5
	_combat_warning_panel.anchor_right = 0.5
	_combat_warning_panel.anchor_top = 0.0
	_combat_warning_panel.anchor_bottom = 0.0
	_combat_warning_panel.offset_left = -210.0
	_combat_warning_panel.offset_right = 210.0
	_combat_warning_panel.offset_top = 90.0
	_combat_warning_panel.offset_bottom = 148.0
	root.add_child(_combat_warning_panel)

	var warning_box := VBoxContainer.new()
	warning_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_combat_warning_panel.add_child(warning_box)

	_combat_warning_title = _make_label("", 17)
	_combat_warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_warning_title.add_theme_color_override("font_color", Color(1.0, 0.58, 0.35))
	_combat_warning_subtitle = _make_label("", 12)
	_combat_warning_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_warning_subtitle.add_theme_color_override("font_color", Color(0.98, 0.86, 0.76))
	warning_box.add_child(_combat_warning_title)
	warning_box.add_child(_combat_warning_subtitle)


func _create_boarding_prompt(root: Control) -> void:
	_boarding_panel = PanelContainer.new()
	_boarding_panel.name = "BoardingPrompt"
	_boarding_panel.visible = false
	_boarding_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boarding_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.045, 0.025, 0.78)))
	_boarding_panel.anchor_left = 0.5
	_boarding_panel.anchor_right = 0.5
	_boarding_panel.anchor_top = 0.70
	_boarding_panel.anchor_bottom = 0.70
	_boarding_panel.offset_left = -220.0
	_boarding_panel.offset_right = 220.0
	_boarding_panel.offset_top = -48.0
	_boarding_panel.offset_bottom = 48.0
	root.add_child(_boarding_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_boarding_panel.add_child(box)

	_boarding_title = _make_label("", 16)
	_boarding_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boarding_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.44))
	_boarding_subtitle = _make_label("", 12)
	_boarding_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boarding_subtitle.add_theme_color_override("font_color", Color(0.94, 0.90, 0.78))
	_boarding_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boarding_progress_bar = ProgressBar.new()
	_boarding_progress_bar.min_value = 0.0
	_boarding_progress_bar.max_value = 100.0
	_boarding_progress_bar.value = 0.0
	_boarding_progress_bar.show_percentage = false
	_boarding_progress_bar.custom_minimum_size = Vector2(400.0, 10.0)
	box.add_child(_boarding_title)
	box.add_child(_boarding_subtitle)
	box.add_child(_boarding_progress_bar)


func _create_pause_menu(root: Control) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_pause_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.48)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.045, 0.92)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_right = 210.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	_pause_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _make_label("Sable Wake", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume_button)

	_return_button = Button.new()
	_return_button.text = "Return to Campaign"
	_return_button.pressed.connect(func() -> void: return_to_campaign_requested.emit())
	box.add_child(_return_button)

	box.add_child(_make_section_label("Settings"))
	_sensitivity_slider = _add_slider_setting(box, "Mouse", 0.0012, 0.007, float(_settings.get("mouse_sensitivity", 0.0032)))
	_camera_distance_slider = _add_slider_setting(box, "Camera", 13.0, 26.0, float(_settings.get("camera_distance", 18.5)))
	_minimap_zoom_slider = _add_slider_setting(box, "Compass", 0.65, 1.8, float(_settings.get("minimap_zoom", 1.0)))

	_invert_y_check = CheckBox.new()
	_invert_y_check.text = "Invert Y"
	_invert_y_check.button_pressed = bool(_settings.get("invert_y", false))
	_invert_y_check.toggled.connect(func(value: bool) -> void:
		_settings["invert_y"] = value
		settings_changed.emit(_settings.duplicate())
	)
	box.add_child(_invert_y_check)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.button_pressed = bool(_settings.get("fullscreen", true))
	_fullscreen_check.toggled.connect(func(value: bool) -> void:
		_settings["fullscreen"] = value
		settings_changed.emit(_settings.duplicate())
	)
	box.add_child(_fullscreen_check)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)

	_sensitivity_slider.value_changed.connect(func(value: float) -> void:
		_settings["mouse_sensitivity"] = value
		settings_changed.emit(_settings.duplicate())
	)
	_camera_distance_slider.value_changed.connect(func(value: float) -> void:
		_settings["camera_distance"] = value
		settings_changed.emit(_settings.duplicate())
	)
	_minimap_zoom_slider.value_changed.connect(func(value: float) -> void:
		_settings["minimap_zoom"] = value
		apply_settings(_settings)
		settings_changed.emit(_settings.duplicate())
	)


func _add_slider_setting(parent: Control, label_text: String, min_value: float, max_value: float, value: float) -> HSlider:
	var label := _make_label(label_text, 12)
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.0001
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)
	return slider


func _make_section_label(text: String) -> Label:
	var label := _make_label(text, 15)
	label.add_theme_color_override("font_color", Color(0.72, 0.88, 0.84))
	return label


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.94))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.68, 0.82, 0.78, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _update_debug(data: Dictionary, enemy_count: int, wind_direction: Vector3, wind_strength: float) -> void:
	if not _debug_visible or _debug_label == null:
		return

	var pos: Vector3 = data.get("position", Vector3.ZERO)
	_debug_label.text = "\n".join([
		"DEBUG F3",
		"FPS %d" % Engine.get_frames_per_second(),
		"Speed %.2f / %.2f" % [float(data.get("speed", 0.0)), float(data.get("target_speed", 0.0))],
		"Sail %.0f%%  Wind %.0f%% %s %.1fx" % [
			float(data.get("sail", 0.0)) * 100.0,
			float(data.get("wind_efficiency", 0.0)) * 100.0,
			_bearing_name(wind_direction),
			wind_strength,
		],
		"Rudder %.2f -> %.2f" % [float(data.get("rudder", 0.0)), float(data.get("target_rudder", 0.0))],
		"Damage Sail %.0f Rudder %.0f PCan %.0f SCan %.0f" % [
			float(data.get("sail_integrity", 100.0)),
			float(data.get("rudder_integrity", 100.0)),
			float(data.get("port_cannon_integrity", 100.0)),
			float(data.get("starboard_cannon_integrity", 100.0)),
		],
		"Crew shock %.2f" % float(data.get("crew_shock", 0.0)),
		"Impact recoil %.2f  Push %.2f" % [float(data.get("impact_recoil", 0.0)), float(data.get("impact_push", 0.0))],
		"Heading %.1f  Enemies %d" % [float(data.get("heading", 0.0)), enemy_count],
		"Reload P %.2f  S %.2f" % [float(data.get("port_reload", 0.0)), float(data.get("starboard_reload", 0.0))],
		"Pos %.1f %.1f %.1f" % [pos.x, pos.y, pos.z],
	])


func _bearing_name(direction: Vector3) -> String:
	var angle := fposmod(rad_to_deg(atan2(direction.x, direction.z)) + 360.0, 360.0)
	if angle < 22.5 or angle >= 337.5:
		return "N"
	if angle < 67.5:
		return "NE"
	if angle < 112.5:
		return "E"
	if angle < 157.5:
		return "SE"
	if angle < 202.5:
		return "S"
	if angle < 247.5:
		return "SW"
	if angle < 292.5:
		return "W"
	return "NW"
