extends CanvasLayer

signal target_selected(world_position: Vector3)
signal closed

const MortarPlot := preload("res://scripts/mortar_plot.gd")

var _panel: PanelContainer
var _plot
var _status_label: Label
var _player_ship: Node3D
var _targets: Array[Node] = []
var _maximum_range := 168.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
	_build()
	visible = false


func open(player: Node3D, targets: Array[Node], maximum_range := 168.0) -> void:
	_player_ship = player
	_targets = targets
	_maximum_range = maximum_range
	visible = true
	refresh(player, targets)
	_plot.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func refresh(player: Node3D, targets: Array[Node]) -> void:
	_player_ship = player
	_targets = targets
	if _plot:
		_plot.set_world_state(player, targets, _maximum_range)
	if _status_label and is_instance_valid(player):
		var telemetry: Dictionary = player.get_telemetry() if player.has_method("get_telemetry") else {}
		var reload := float(telemetry.get("mortar_reload", 0.0))
		var shells := int(telemetry.get("mortar_shells", 0))
		_status_label.text = "%d SHELLS     READY" % shells if reload <= 0.05 else "%d SHELLS     RELOAD %.1fs" % [shells, reload]


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -446.0
	_panel.offset_right = -24.0
	_panel.offset_top = -266.0
	_panel.offset_bottom = 266.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.043, 0.97)
	style.border_color = Color(0.53, 0.67, 0.55, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "MORTAR PLOT"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.34))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_status_label = Label.new()
	_status_label.text = "BATTERY READY"
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.66, 0.84, 0.82))
	column.add_child(_status_label)

	_plot = MortarPlot.new()
	_plot.custom_minimum_size = Vector2(388.0, 410.0)
	_plot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plot.target_selected.connect(func(position: Vector3) -> void: target_selected.emit(position))
	_plot.cancel_requested.connect(close)
	column.add_child(_plot)
