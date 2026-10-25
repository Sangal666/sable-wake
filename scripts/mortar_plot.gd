extends Control

signal target_selected(world_position: Vector3)
signal cancel_requested

var player_ship: Node3D
var targets: Array[Node] = []
var maximum_range := 168.0
var _hovered_target: Node3D
var _cursor_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)


func set_world_state(player: Node3D, enemy_nodes: Array[Node], mortar_range: float) -> void:
	player_ship = player
	targets = enemy_nodes
	maximum_range = mortar_range
	queue_redraw()


func _process(_delta: float) -> void:
	_hovered_target = _find_target_at(_cursor_position)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_position = event.position
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var world_position := _map_to_world(event.position)
			var selected := _find_target_at(event.position)
			if selected:
				world_position = selected.global_position
			target_selected.emit(world_position)
			accept_event()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.018, 0.055, 0.070, 0.98))
	var center := size * 0.5
	var plot_radius := maxf(minf(size.x, size.y) * 0.46, 1.0)
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		draw_arc(center, plot_radius * fraction, 0.0, TAU, 64, Color(0.32, 0.63, 0.65, 0.22), 1.0)
	draw_line(Vector2(center.x, center.y - plot_radius), Vector2(center.x, center.y + plot_radius), Color(0.32, 0.63, 0.65, 0.18), 1.0)
	draw_line(Vector2(center.x - plot_radius, center.y), Vector2(center.x + plot_radius, center.y), Color(0.32, 0.63, 0.65, 0.18), 1.0)
	if not is_instance_valid(player_ship):
		return
	var forward := -player_ship.global_transform.basis.z.normalized()
	var heading := Vector2(forward.x, forward.z).normalized()
	var right := Vector2(-heading.y, heading.x)
	var bow := center + heading * 11.0
	var stern_left := center - heading * 8.0 + right * 6.0
	var stern_right := center - heading * 8.0 - right * 6.0
	draw_colored_polygon(PackedVector2Array([bow, stern_left, stern_right]), Color(0.40, 0.86, 0.92))
	for candidate in targets:
		if not is_instance_valid(candidate) or candidate.get("is_sunk") == true or candidate.get("is_surrendered") == true:
			continue
		var target := candidate as Node3D
		if target == null:
			continue
		var point := _world_to_map(target.global_position)
		var distance := player_ship.global_position.distance_to(target.global_position)
		if distance > maximum_range * 1.05:
			if target.is_in_group("scenario_fort"):
				_draw_distant_fort_target(target, center, plot_radius)
			continue
		var hovered := target == _hovered_target
		var color := Color(1.0, 0.36, 0.22) if not hovered else Color(1.0, 0.78, 0.26)
		if target.is_in_group("scenario_fort"):
			_draw_fort_target(point, color, hovered, String(target.get("display_name")))
		else:
			draw_circle(point, 8.0 if hovered else 6.0, color)
			draw_arc(point, 13.0 if hovered else 10.0, 0.0, TAU, 24, Color(color, 0.72), 2.0)
		var velocity: Vector3 = target.get("velocity") if target.get("velocity") is Vector3 else Vector3.ZERO
		if velocity.length_squared() > 0.2:
			var direction := Vector2(velocity.x, velocity.z).normalized()
			draw_line(point, point + direction * 18.0, Color(color, 0.55), 2.0)
	var cursor_color := Color(1.0, 0.77, 0.28, 0.82)
	draw_arc(_cursor_position, 10.0, 0.0, TAU, 24, cursor_color, 1.5)
	draw_line(_cursor_position - Vector2(15.0, 0.0), _cursor_position + Vector2(15.0, 0.0), cursor_color, 1.0)
	draw_line(_cursor_position - Vector2(0.0, 15.0), _cursor_position + Vector2(0.0, 15.0), cursor_color, 1.0)


func _draw_fort_target(point: Vector2, color: Color, hovered: bool, fort_name: String) -> void:
	var scale := 1.18 if hovered else 1.0
	draw_rect(Rect2(point + Vector2(-8.0, -4.0) * scale, Vector2(16.0, 10.0) * scale), color, true)
	draw_rect(Rect2(point + Vector2(-10.0, -9.0) * scale, Vector2(5.0, 7.0) * scale), color, true)
	draw_rect(Rect2(point + Vector2(5.0, -9.0) * scale, Vector2(5.0, 7.0) * scale), color, true)
	draw_arc(point, 16.0 if hovered else 14.0, 0.0, TAU, 28, Color(color, 0.72), 2.0)
	draw_string(get_theme_default_font(), point + Vector2(-3.5, 4.0), "F", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.06, 0.03, 0.02, 0.95))
	if hovered:
		var label := fort_name if not fort_name.is_empty() else "FORT"
		draw_string(get_theme_default_font(), point + Vector2(16.0, -11.0), label, HORIZONTAL_ALIGNMENT_LEFT, 128.0, 11, Color(1.0, 0.82, 0.48, 0.95))


func _draw_distant_fort_target(target: Node3D, center: Vector2, plot_radius: float) -> void:
	var offset := target.global_position - player_ship.global_position
	var direction := Vector2(offset.x, offset.z).normalized()
	if direction.length_squared() < 0.5:
		return
	var point := center + direction * plot_radius * 0.91
	var color := Color(0.78, 0.34, 0.16, 0.58)
	_draw_fort_target(point, color, false, "")
	draw_line(point - direction * 19.0, point - direction * 12.0, color, 2.0)


func _world_to_map(world_position: Vector3) -> Vector2:
	var center := size * 0.5
	if not is_instance_valid(player_ship):
		return center
	var delta := world_position - player_ship.global_position
	var scale := minf(size.x, size.y) * 0.46 / maxf(maximum_range, 1.0)
	return center + Vector2(delta.x, delta.z) * scale


func _map_to_world(map_position: Vector2) -> Vector3:
	if not is_instance_valid(player_ship):
		return Vector3.ZERO
	var center := size * 0.5
	var scale := minf(size.x, size.y) * 0.46 / maxf(maximum_range, 1.0)
	var offset := (map_position - center) / maxf(scale, 0.001)
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return player_ship.global_position + Vector3(offset.x, 0.0, offset.y)


func _find_target_at(map_position: Vector2) -> Node3D:
	if not is_instance_valid(player_ship):
		return null
	var best: Node3D
	var best_distance := 19.0
	for candidate in targets:
		if not is_instance_valid(candidate) or candidate.get("is_sunk") == true or candidate.get("is_surrendered") == true:
			continue
		var target := candidate as Node3D
		if target == null or player_ship.global_position.distance_to(target.global_position) > maximum_range:
			continue
		var distance := map_position.distance_to(_world_to_map(target.global_position))
		if distance < best_distance:
			best = target
			best_distance = distance
	return best
