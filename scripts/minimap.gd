extends Control

@export var world_radius := 190.0
@export var map_zoom := 1.0
@export var view_degrees := 118.0

var player_position := Vector3.ZERO
var player_heading := 0.0
var contacts: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(620.0, 50.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_zoom(value: float) -> void:
	map_zoom = clampf(value, 0.65, 1.8)
	queue_redraw()


func set_world_state(player: Node3D, enemy_nodes: Array, island_data: Array) -> void:
	if is_instance_valid(player):
		player_position = player.global_position
		if player.has_method("get_telemetry"):
			player_heading = float(player.get_telemetry().get("heading", player_heading))

	contacts.clear()
	for enemy in enemy_nodes:
		if not is_instance_valid(enemy) or enemy.get("is_sunk"):
			continue
		contacts.append({
			"position": enemy.global_position,
			"kind": "fort" if enemy.is_in_group("scenario_fort") else "enemy",
		})

	landmarks.clear()
	for island in island_data:
		landmarks.append(island)

	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var center := rect.get_center()
	var bar_y := center.y
	var left := 22.0
	var right := size.x - 22.0
	var half_width := (right - left) * 0.5

	draw_rect(rect, Color(0.01, 0.025, 0.03, 0.58), true)
	draw_line(Vector2(left, bar_y), Vector2(right, bar_y), Color(0.78, 0.86, 0.80, 0.45), 1.4)
	draw_line(Vector2(center.x, bar_y - 13.0), Vector2(center.x, bar_y + 16.0), Color(0.95, 0.92, 0.76, 0.95), 2.0)

	for heading in range(0, 360, 15):
		var diff := _angle_delta_degrees(float(heading), player_heading)
		if absf(diff) > view_degrees * 0.5:
			continue

		var x := center.x + diff / (view_degrees * 0.5) * half_width
		var major := heading % 45 == 0
		var tick_height := 13.0 if major else 6.0
		draw_line(Vector2(x, bar_y - tick_height), Vector2(x, bar_y + tick_height), Color(0.78, 0.86, 0.80, 0.42 if major else 0.22), 1.0)
		if heading % 90 == 0:
			draw_string(get_theme_default_font(), Vector2(x - 5.0, bar_y - 16.0), _cardinal_for_heading(heading), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.90, 0.96, 0.91, 0.86))

	for landmark in landmarks:
		var pos: Vector3 = landmark.get("position", Vector3.ZERO)
		_draw_marker_for_world_pos(pos, Color(0.72, 0.62, 0.40, 0.82), 4.0, center, half_width, bar_y + 13.0)

	for contact in contacts:
		var pos: Vector3 = contact.get("position", Vector3.ZERO)
		if String(contact.get("kind", "enemy")) == "fort":
			_draw_fort_marker(pos, center, half_width, bar_y + 12.0)
		else:
			_draw_marker_for_world_pos(pos, Color(0.90, 0.22, 0.16, 0.95), 5.0, center, half_width, bar_y + 12.0)


func _draw_fort_marker(world_pos: Vector3, center: Vector2, half_width: float, y: float) -> void:
	var marker := _marker_screen_position(world_pos, center, half_width, y)
	if marker == Vector2.INF:
		return
	var color := Color(1.0, 0.46, 0.18, 0.96)
	draw_rect(Rect2(marker + Vector2(-6.0, -3.0), Vector2(12.0, 7.0)), color, true)
	draw_rect(Rect2(marker + Vector2(-7.0, -7.0), Vector2(4.0, 5.0)), color, true)
	draw_rect(Rect2(marker + Vector2(3.0, -7.0), Vector2(4.0, 5.0)), color, true)
	draw_line(marker + Vector2(-8.0, 5.0), marker + Vector2(8.0, 5.0), color, 2.0)


func _marker_screen_position(world_pos: Vector3, center: Vector2, half_width: float, y: float) -> Vector2:
	var delta := world_pos - player_position
	delta.y = 0.0
	var distance := delta.length()
	var range := world_radius / map_zoom
	if distance <= 0.1 or distance > range:
		return Vector2.INF
	var bearing := fposmod(rad_to_deg(atan2(delta.x, delta.z)) + 360.0, 360.0)
	var diff := _angle_delta_degrees(bearing, player_heading)
	if absf(diff) > view_degrees * 0.5:
		return Vector2.INF
	return Vector2(center.x + diff / (view_degrees * 0.5) * half_width, y)


func _draw_marker_for_world_pos(world_pos: Vector3, color: Color, marker_size: float, center: Vector2, half_width: float, y: float) -> void:
	var delta := world_pos - player_position
	delta.y = 0.0
	var distance := delta.length()
	if distance <= 0.1:
		return

	var range := world_radius / map_zoom
	if distance > range:
		return

	var bearing := fposmod(rad_to_deg(atan2(delta.x, delta.z)) + 360.0, 360.0)
	var diff := _angle_delta_degrees(bearing, player_heading)
	if absf(diff) > view_degrees * 0.5:
		return

	var x := center.x + diff / (view_degrees * 0.5) * half_width
	var alpha := clampf(1.0 - distance / range * 0.55, 0.35, 1.0)
	var marker_color := Color(color.r, color.g, color.b, color.a * alpha)
	var points := PackedVector2Array([
		Vector2(x, y - marker_size),
		Vector2(x + marker_size, y),
		Vector2(x, y + marker_size),
		Vector2(x - marker_size, y),
	])
	draw_colored_polygon(points, marker_color)


func _angle_delta_degrees(target_heading: float, origin_heading: float) -> float:
	return fposmod(target_heading - origin_heading + 540.0, 360.0) - 180.0


func _cardinal_for_heading(heading: int) -> String:
	match heading:
		0:
			return "N"
		90:
			return "E"
		180:
			return "S"
		270:
			return "W"
	return ""
