extends CanvasLayer

signal deploy_requested(region: Dictionary)
signal close_requested

class MapCanvas:
	extends Control

	var owner_ui: CanvasLayer

	func _draw() -> void:
		if owner_ui == null:
			return

		var rect := get_rect()
		var size := rect.size
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.12, 0.16))
		_draw_ocean(size)
		_draw_land(size)
		_draw_faction_waters(size)
		_draw_regional_effects(size)
		_draw_routes(size)
		_draw_party_routes(size)
		_draw_terrain(size)
		_draw_harbor_ships(size)
		_draw_sea_opportunities(size)
		_draw_parties(size)
		_draw_player_party(size)
		_draw_locations(size)
		_draw_decision_markers(size)

	func _gui_input(event: InputEvent) -> void:
		if owner_ui == null:
			return
		if event is InputEventMouseMotion:
			owner_ui.call("_set_hover_from_point", event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			owner_ui.call("_handle_map_click", event.position, event.double_click)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			owner_ui.call("_set_player_target_from_point", event.position)

	func _draw_ocean(size: Vector2) -> void:
		for i in range(22):
			var t := float(i) / 21.0
			var color := Color(0.02 + t * 0.02, 0.18 + t * 0.05, 0.24 + t * 0.10)
			draw_rect(Rect2(0.0, size.y * t, size.x, size.y / 20.0 + 2.0), color)
		for i in range(42):
			var y := fposmod(float(i) * 47.0, size.y)
			var x0 := fposmod(float(i) * 113.0, size.x)
			var points := PackedVector2Array()
			for s in range(10):
				points.append(Vector2(fposmod(x0 + float(s) * 38.0, size.x), y + sin(float(s) * 0.85 + float(i)) * 6.0))
			draw_polyline(points, Color(0.22, 0.55, 0.62, 0.20), 1.0)

	func _draw_faction_waters(size: Vector2) -> void:
		for region in owner_ui.get("_sea_regions"):
			var points := PackedVector2Array()
			for p in region.get("points", []):
				points.append(Vector2(float(p.x) * size.x, float(p.y) * size.y))
			if points.size() < 3:
				continue
			var color: Color = region.get("color", Color.WHITE)
			var pressure := int(owner_ui.call("_sea_region_pressure", region))
			var relation := int(owner_ui.call("_sea_region_relation", region))
			var focused := bool(owner_ui.call("_is_sea_region_focus", region))
			var locked := not bool(owner_ui.call("is_region_id_unlocked", String(region.get("id", region.get("name", ""))).to_lower().replace(" ", "_")))
			var pressure_alpha := clampf(float(pressure) / 100.0, 0.0, 1.0)
			var fill_alpha := 0.030 + pressure_alpha * 0.050 if focused else 0.008 + pressure_alpha * 0.018
			var line_alpha := 0.24 + pressure_alpha * 0.34 if focused else 0.070 + pressure_alpha * 0.13
			if locked:
				fill_alpha = 0.030
				line_alpha = 0.18
			draw_colored_polygon(points, Color(color.r, color.g, color.b, fill_alpha))
			var outline := PackedVector2Array()
			for point in points:
				outline.append(point)
			outline.append(points[0])
			draw_polyline(outline, Color(color.r, color.g, color.b, line_alpha), 2.3 if focused else (1.7 if pressure >= 70 else 1.0))
			var center := Vector2.ZERO
			for point in points:
				center += point
			center /= float(points.size())
			if pressure >= 58 or focused:
				for i in range(3):
					var a: Vector2 = points[(i * 2) % points.size()]
					var b: Vector2 = points[(i * 2 + 3) % points.size()]
					draw_line(a.lerp(center, 0.24), b.lerp(center, 0.18), Color(color.r, color.g, color.b, 0.10 + pressure_alpha * 0.12), 1.0)
				var relation_text := "+%d" % relation if relation >= 0 else "%d" % relation
				draw_string(get_theme_default_font(), center + Vector2(-72.0, -18.0), String(region.get("name", "Waters")), HORIZONTAL_ALIGNMENT_LEFT, 210.0, 14.0, Color(color.r, color.g, color.b, 0.60 + pressure_alpha * 0.25))
				var control_label := String(owner_ui.call("_warfront_control_label", String(region.get("faction", "Independent")), pressure, int(owner_ui.call("_sea_region_power", region)))).to_upper()
				draw_string(get_theme_default_font(), center + Vector2(-72.0, -3.0), "%s  P%d  R%s" % [control_label, pressure, relation_text], HORIZONTAL_ALIGNMENT_LEFT, 210.0, 12.0, Color(0.92, 0.90, 0.78, 0.54 + pressure_alpha * 0.22))
			if locked:
				for i in range(6):
					var a: Vector2 = points[i % points.size()]
					var b: Vector2 = points[(i + 2) % points.size()]
					draw_line(a.lerp(b, 0.25), a.lerp(b, 0.75), Color(0.82, 0.78, 1.0, 0.13), 1.0)


	func _draw_regional_effects(size: Vector2) -> void:
		var effects: Array = owner_ui.get("_regional_effects")
		for effect in effects:
			var pos: Vector2 = effect.get("position", Vector2.ZERO) * size
			var color: Color = effect.get("color", Color(0.58, 1.0, 0.70))
			var radius := float(effect.get("radius", 0.12)) * minf(size.x, size.y)
			draw_arc(pos, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.46), 2.6)
			draw_arc(pos, radius * 0.66, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.24), 1.4)
			draw_line(pos + Vector2(-radius * 0.55, 0.0), pos + Vector2(radius * 0.55, 0.0), Color(color.r, color.g, color.b, 0.22), 1.0)
			draw_line(pos + Vector2(0.0, -radius * 0.55), pos + Vector2(0.0, radius * 0.55), Color(color.r, color.g, color.b, 0.22), 1.0)
			draw_rect(Rect2(pos + Vector2(14.0, -48.0), Vector2(148.0, 30.0)), Color(0.0, 0.0, 0.0, 0.50))
			draw_string(get_theme_default_font(), pos + Vector2(20.0, -31.0), String(effect.get("name", "Regional effect")), HORIZONTAL_ALIGNMENT_LEFT, 140.0, 12.0, Color(color.r, color.g, color.b, 0.94))
			draw_string(get_theme_default_font(), pos + Vector2(20.0, -18.0), String(effect.get("read", "")), HORIZONTAL_ALIGNMENT_LEFT, 140.0, 10.0, Color(0.92, 0.90, 0.78, 0.76))

	func _draw_land(size: Vector2) -> void:
		for land in owner_ui.get("_landmasses"):
			var points := PackedVector2Array()
			for p in land.get("points", []):
				points.append(Vector2(float(p.x) * size.x, float(p.y) * size.y))
			if points.size() < 3:
				continue
			var outline := PackedVector2Array()
			for point in points:
				outline.append(point)
			outline.append(points[0])
			for coast in range(5, 0, -1):
				draw_polyline(outline, Color(0.18, 0.78, 0.82, 0.05 + float(coast) * 0.035), float(coast) * 2.0)
			draw_colored_polygon(points, land.get("color", Color(0.22, 0.34, 0.18)))
			draw_polyline(outline, Color(0.60, 0.88, 0.86, 0.55), 3.0)
			draw_polyline(outline, Color(0.07, 0.04, 0.025, 0.55), 1.0)

	func _draw_routes(size: Vector2) -> void:
		for route in owner_ui.get("_sea_routes"):
			var points := PackedVector2Array()
			for p in route:
				points.append(Vector2(float(p.x) * size.x, float(p.y) * size.y))
			if points.size() > 1:
				draw_polyline(points, Color(0.90, 0.78, 0.46, 0.075), 1.0)

	func _draw_party_routes(size: Vector2) -> void:
		var parties: Array = owner_ui.get("_parties")
		var selected_party := int(owner_ui.get("_selected_party_index"))
		for i in range(parties.size()):
			var party: Dictionary = parties[i]
			var is_focus := i == selected_party or bool(owner_ui.call("is_contract_target", String(party.get("name", ""))))
			if not is_focus:
				continue
			var route: Array = party.get("route", [])
			if route.size() < 2:
				continue
			var color: Color = party.get("color", Color.WHITE)
			var points := PackedVector2Array()
			for p in route:
				points.append(Vector2(float(p.x) * size.x, float(p.y) * size.y))
			points.append(Vector2(float(route[0].x) * size.x, float(route[0].y) * size.y))
			draw_polyline(points, Color(color.r, color.g, color.b, 0.26), 1.2)

	func _draw_terrain(size: Vector2) -> void:
		for p in owner_ui.get("_forest_points"):
			var pos := Vector2(float(p.x) * size.x, float(p.y) * size.y)
			draw_circle(pos, 2.0, Color(0.06, 0.17, 0.07, 0.72))
			draw_circle(pos + Vector2(2.0, -1.0), 1.5, Color(0.11, 0.25, 0.10, 0.72))
		for p in owner_ui.get("_reef_points"):
			var pos := Vector2(float(p.x) * size.x, float(p.y) * size.y)
			draw_line(pos + Vector2(-4.0, 3.0), pos + Vector2(4.0, -3.0), Color(0.77, 0.86, 0.78, 0.32), 1.0)
		for p in owner_ui.get("_mountain_points"):
			var pos := Vector2(float(p.x) * size.x, float(p.y) * size.y)
			var tri := PackedVector2Array([pos + Vector2(-7.0, 6.0), pos + Vector2(0.0, -7.0), pos + Vector2(7.0, 6.0)])
			draw_colored_polygon(tri, Color(0.30, 0.30, 0.27, 0.78))
			draw_line(pos + Vector2(-1.5, -4.0), pos + Vector2(2.0, 3.0), Color(0.82, 0.82, 0.74, 0.62), 1.0)

	func _draw_harbor_ships(size: Vector2) -> void:
		for ship in owner_ui.get("_harbor_ships"):
			var pos: Vector2 = ship.get("position", Vector2.ZERO) * size
			var direction: Vector2 = ship.get("direction", Vector2.RIGHT)
			var color: Color = ship.get("color", Color(0.90, 0.88, 0.76))
			if direction.length_squared() <= 0.001:
				direction = Vector2.RIGHT
			direction = direction.normalized()
			var side := Vector2(-direction.y, direction.x)
			draw_circle(pos + Vector2(0.0, 5.0), 8.0, Color(0.0, 0.0, 0.0, 0.34))
			draw_colored_polygon(PackedVector2Array([
				pos + direction * 15.0,
				pos - direction * 11.0 + side * 6.5,
				pos - direction * 8.0,
				pos - direction * 11.0 - side * 6.5,
			]), Color(0.18, 0.09, 0.035))
			draw_line(pos, pos + Vector2(0.0, -24.0), Color(0.10, 0.07, 0.04), 2.0)
			draw_rect(Rect2(pos + Vector2(0.0, -24.0), Vector2(23.0, 13.0)), color)
			draw_arc(pos, 17.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.72), 2.0)

	func _draw_sea_opportunities(size: Vector2) -> void:
		var opportunities: Array = owner_ui.get("_sea_opportunities")
		for i in range(opportunities.size()):
			var opportunity: Dictionary = opportunities[i]
			var pos: Vector2 = opportunity.get("position", Vector2.ZERO) * size
			var color: Color = owner_ui.call("_opportunity_color", String(opportunity.get("type", "salvage")))
			var selected := i == int(owner_ui.get("_selected_opportunity_index"))
			var radius := 16.0 if selected else 12.0
			draw_arc(pos, radius, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.92), 2.5)
			draw_arc(pos, radius + 8.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.28), 1.5)
			draw_line(pos + Vector2(-8.0, 0.0), pos + Vector2(8.0, 0.0), Color(color.r, color.g, color.b, 0.75), 1.6)
			draw_line(pos + Vector2(0.0, -8.0), pos + Vector2(0.0, 8.0), Color(color.r, color.g, color.b, 0.75), 1.6)
			if selected:
				draw_string(get_theme_default_font(), pos + Vector2(14.0, -10.0), String(opportunity.get("name", "Sea event")), HORIZONTAL_ALIGNMENT_LEFT, 220.0, 14.0, Color(color.r, color.g, color.b, 0.92))

	func _draw_parties(size: Vector2) -> void:
		var parties: Array = owner_ui.get("_parties")
		for i in range(parties.size()):
			var party: Dictionary = parties[i]
			var pos: Vector2 = party.get("position", Vector2.ZERO) * size
			var color: Color = party.get("color", Color.WHITE)
			var direction: Vector2 = party.get("direction", Vector2.RIGHT)
			var highlighted := i == int(owner_ui.get("_selected_party_index")) or i == int(owner_ui.get("_hover_party_index"))
			var close_contact := i == int(owner_ui.get("_nearby_encounter_index"))
			var relation_state: Dictionary = owner_ui.call("_get_party_relation_state", party)
			var stance := String(relation_state.get("effective_stance", party.get("stance", "neutral")))
			var intent := String(party.get("intent", stance))
			var distance_to_player := (owner_ui.get("_player_position") as Vector2).distance_to(party.get("position", Vector2.ZERO))
			if direction.length_squared() <= 0.001:
				direction = Vector2.RIGHT
			direction = direction.normalized()
			var side := Vector2(-direction.y, direction.x)
			if highlighted or close_contact or distance_to_player <= PARTY_DETECTION_DISTANCE:
				var forward := pos + direction * 28.0
				draw_line(pos, forward, Color(color.r, color.g, color.b, 0.52), 2.0)
				draw_colored_polygon(PackedVector2Array([
					forward + direction * 8.0,
					forward - direction * 7.0 + side * 5.0,
					forward - direction * 7.0 - side * 5.0,
				]), Color(color.r, color.g, color.b, 0.54))
			draw_circle(pos + Vector2(0.0, 5.0), 7.0, Color(0.0, 0.0, 0.0, 0.38))
			draw_colored_polygon(PackedVector2Array([
				pos + direction * 12.0,
				pos - direction * 9.0 + side * 5.0,
				pos - direction * 6.0,
				pos - direction * 9.0 - side * 5.0,
			]), Color(0.12, 0.08, 0.04))
			draw_line(pos, pos + Vector2(0.0, -24.0), Color(0.10, 0.07, 0.04), 2.0)
			draw_rect(Rect2(pos + Vector2(0.0, -24.0), Vector2(22.0, 13.0)), color)
			draw_line(pos + Vector2(2.0, -18.0), pos + Vector2(20.0, -18.0), Color(1.0, 1.0, 1.0, 0.18), 1.0)
			if highlighted or close_contact or distance_to_player <= PARTY_DETECTION_DISTANCE * 0.78:
				var badge_color := Color(1.0, 0.36, 0.24) if stance == "chase" else (Color(1.0, 0.82, 0.34) if stance == "shadow" else (Color(0.52, 0.82, 1.0) if stance == "flee" else Color(0.86, 0.90, 0.78)))
				draw_rect(Rect2(pos + Vector2(-42.0, -48.0), Vector2(84.0, 18.0)), Color(0.0, 0.0, 0.0, 0.48))
				draw_string(get_theme_default_font(), pos + Vector2(-38.0, -34.0), "%s / %d" % [stance.to_upper(), int(party.get("strength", 0))], HORIZONTAL_ALIGNMENT_LEFT, 96.0, 11.0, badge_color)
				draw_string(get_theme_default_font(), pos + Vector2(-52.0, 25.0), intent, HORIZONTAL_ALIGNMENT_CENTER, 104.0, 11.0, Color(0.92, 0.90, 0.78, 0.78))
			if highlighted:
				draw_arc(pos, 18.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.45, 0.90), 2.0)
				draw_arc(pos, PARTY_DETECTION_DISTANCE * minf(size.x, size.y), 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.18), 1.0)
			if bool(owner_ui.call("is_contract_target", String(party.get("name", "")))):
				draw_arc(pos, 27.0, 0.0, TAU, 36, Color(1.0, 0.72, 0.18, 0.95), 3.0)
				draw_line(pos + Vector2(-18.0, -18.0), pos + Vector2(18.0, 18.0), Color(1.0, 0.72, 0.18, 0.65), 1.5)
			if i == int(owner_ui.get("_nearby_encounter_index")):
				draw_arc(pos, 24.0, 0.0, TAU, 32, Color(1.0, 0.28, 0.18, 0.85), 2.5)

	func _draw_player_course(size: Vector2, pos: Vector2, target: Vector2) -> void:
		if pos.distance_to(target) <= 5.0:
			return
		var route_color: Color = owner_ui.call("_campaign_route_color")
		var route_status := String(owner_ui.call("_campaign_route_status"))
		var direction := (target - pos).normalized()
		var side := Vector2(-direction.y, direction.x)
		draw_line(pos, target, Color(route_color.r, route_color.g, route_color.b, 0.10), 12.0)
		draw_line(pos, target, Color(route_color.r, route_color.g, route_color.b, 0.30), 5.0)
		draw_line(pos, target, Color(1.0, 0.96, 0.78, 0.78), 1.4)
		var distance := pos.distance_to(target)
		var marks := clampi(int(distance / 115.0), 1, 6)
		for i in range(1, marks + 1):
			var t := float(i) / float(marks + 1)
			var mark := pos.lerp(target, t)
			var arrow := PackedVector2Array([
				mark + direction * 13.0,
				mark - direction * 8.0 + side * 6.0,
				mark - direction * 3.0,
				mark - direction * 8.0 - side * 6.0,
			])
			draw_colored_polygon(arrow, Color(route_color.r, route_color.g, route_color.b, 0.70))
		draw_arc(target, 18.0, 0.0, TAU, 36, Color(route_color.r, route_color.g, route_color.b, 0.82), 2.2)
		draw_arc(target, 30.0, 0.0, TAU, 42, Color(route_color.r, route_color.g, route_color.b, 0.26), 1.6)
		var target_label := String(owner_ui.call("_campaign_target_label"))
		if not target_label.is_empty():
			draw_string(get_theme_default_font(), target + Vector2(14.0, -22.0), target_label, HORIZONTAL_ALIGNMENT_LEFT, 280.0, 13.0, Color(1.0, 0.94, 0.64, 0.92))
		if not route_status.is_empty():
			draw_string(get_theme_default_font(), target + Vector2(14.0, -7.0), route_status, HORIZONTAL_ALIGNMENT_LEFT, 280.0, 12.0, Color(0.92, 0.90, 0.78, 0.76))


	func _draw_player_party(size: Vector2) -> void:
		var pos: Vector2 = owner_ui.get("_player_position") * size
		var target: Vector2 = owner_ui.get("_player_target") * size
		var selected_location: Dictionary = owner_ui.call("get_selected_region")
		var selected_pos: Vector2 = selected_location.get("position", Vector2.ZERO) * size
		var enter_radius := float(owner_ui.call("_get_location_enter_radius", selected_location)) * minf(size.x, size.y)
		var selected_distance := (owner_ui.get("_player_position") as Vector2).distance_to(selected_location.get("position", Vector2.ZERO))
		if selected_distance <= float(owner_ui.call("_get_location_enter_radius", selected_location)) * 1.65:
			draw_arc(selected_pos, enter_radius, 0.0, TAU, 36, Color(1.0, 0.86, 0.45, 0.18), 1.3)
		_draw_player_course(size, pos, target)
		draw_circle(pos + Vector2(0.0, 5.0), 6.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_line(pos, pos + Vector2(0.0, -28.0), Color(0.08, 0.05, 0.02), 2.5)
		draw_rect(Rect2(pos + Vector2(0.0, -28.0), Vector2(24.0, 14.0)), Color(0.88, 0.92, 0.82))
		var direction: Vector2 = owner_ui.get("_player_direction")
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([
			pos + direction * 14.0,
			pos - direction * 11.0 + side * 6.0,
			pos - direction * 7.0,
			pos - direction * 11.0 - side * 6.0,
		]), Color(0.16, 0.09, 0.035))
		draw_arc(pos, 14.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.45), 2.0)

	func _draw_locations(size: Vector2) -> void:
		for i in range(owner_ui.get("_locations").size()):
			var location: Dictionary = owner_ui.get("_locations")[i]
			var pos: Vector2 = location.get("position", Vector2.ZERO) * size
			var color: Color = location.get("color", Color.WHITE)
			var selected := i == int(owner_ui.get("_selected_index"))
			var locked := not bool(owner_ui.call("is_region_id_unlocked", String(location.get("id", ""))))
			var radius := 7.0 if selected else 5.0
			if location.get("kind", "port") == "fort":
				draw_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), Color(0.18, 0.16, 0.13))
				draw_rect(Rect2(pos - Vector2(radius - 2.0, radius - 2.0), Vector2((radius - 2.0) * 2.0, (radius - 2.0) * 2.0)), color)
			else:
				draw_circle(pos, radius + 2.0, Color(0.0, 0.0, 0.0, 0.45))
				draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.45 if locked else 1.0))
			if locked:
				draw_arc(pos, 18.0, 0.0, TAU, 30, Color(0.76, 0.64, 1.0, 0.75), 2.0)
			if bool(owner_ui.call("is_contract_location_target", String(location.get("id", "")))):
				draw_arc(pos, 24.0, 0.0, TAU, 34, Color(1.0, 0.72, 0.18, 0.95), 2.5)
				draw_line(pos + Vector2(-16.0, 0.0), pos + Vector2(16.0, 0.0), Color(1.0, 0.72, 0.18, 0.75), 1.5)
			if selected:
				draw_arc(pos, 15.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.45), 2.0)
			if String(location.get("kind", "port")) == "port" or String(location.get("kind", "port")) == "fort":
				var should_show_badge := selected or bool(owner_ui.call("is_contract_location_target", String(location.get("id", "")))) or (owner_ui.get("_player_position") as Vector2).distance_to(location.get("position", Vector2.ZERO)) <= 0.13
				if should_show_badge:
					_draw_settlement_badge(location, pos, color)


	func _draw_settlement_badge(location: Dictionary, pos: Vector2, color: Color) -> void:
		var state: Dictionary = owner_ui.call("_get_settlement_state", location)
		var security := int(state.get("security", 50))
		var prosperity := int(state.get("prosperity", 50))
		var access := String(state.get("access_label", "open"))
		var access_color := Color(1.0, 0.36, 0.26) if access == "closed" else (Color(1.0, 0.78, 0.32) if access == "restricted" else Color(0.52, 1.0, 0.62))
		var security_color := Color(0.46, 0.78, 1.0) if security >= 62 else (Color(1.0, 0.78, 0.32) if security >= 38 else Color(1.0, 0.38, 0.24))
		var prosperity_color := Color(0.54, 1.0, 0.66) if prosperity >= 62 else (Color(1.0, 0.82, 0.36) if prosperity >= 38 else Color(1.0, 0.45, 0.30))
		var badge_pos := pos + Vector2(15.0, -40.0)
		draw_rect(Rect2(badge_pos, Vector2(102.0, 34.0)), Color(0.0, 0.0, 0.0, 0.52))
		draw_line(badge_pos + Vector2(0.0, 0.0), badge_pos + Vector2(102.0, 0.0), Color(color.r, color.g, color.b, 0.58), 1.2)
		draw_string(get_theme_default_font(), badge_pos + Vector2(6.0, 12.0), access.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 92.0, 11.0, access_color)
		draw_string(get_theme_default_font(), badge_pos + Vector2(6.0, 28.0), "SEC %d  PRO %d" % [security, prosperity], HORIZONTAL_ALIGNMENT_LEFT, 96.0, 11.0, Color(0.88, 0.88, 0.78, 0.82))
		draw_rect(Rect2(badge_pos + Vector2(48.0, 20.0), Vector2(clampf(float(security) / 100.0, 0.0, 1.0) * 22.0, 3.0)), security_color)
		draw_rect(Rect2(badge_pos + Vector2(84.0, 20.0), Vector2(clampf(float(prosperity) / 100.0, 0.0, 1.0) * 14.0, 3.0)), prosperity_color)

	func _draw_decision_markers(size: Vector2) -> void:
		var markers: Array = owner_ui.call("_campaign_decision_markers")
		for marker in markers:
			var pos: Vector2 = marker.get("position", Vector2.ZERO) * size
			var color: Color = marker.get("color", Color(1.0, 0.86, 0.42))
			var label := String(marker.get("label", "NEXT"))
			var radius := float(marker.get("radius", 30.0))
			draw_arc(pos, radius, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.84), 2.8)
			draw_arc(pos, radius + 11.0, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.22), 1.8)
			draw_line(pos + Vector2(-radius, 0.0), pos + Vector2(radius, 0.0), Color(color.r, color.g, color.b, 0.34), 1.0)
			draw_line(pos + Vector2(0.0, -radius), pos + Vector2(0.0, radius), Color(color.r, color.g, color.b, 0.34), 1.0)
			draw_rect(Rect2(pos + Vector2(14.0, -34.0), Vector2(104.0, 22.0)), Color(0.0, 0.0, 0.0, 0.56))
			draw_string(get_theme_default_font(), pos + Vector2(20.0, -18.0), label, HORIZONTAL_ALIGNMENT_LEFT, 96.0, 12.0, Color(color.r, color.g, color.b, 0.94))


const FACTION_CROWN := Color(0.96, 0.78, 0.25)
const FACTION_IRON := Color(0.70, 0.74, 0.78)
const FACTION_FREE := Color(0.35, 0.70, 1.0)
const FACTION_VERDANT := Color(0.22, 0.86, 0.42)
const FACTION_RAIDER := Color(0.95, 0.28, 0.20)
const FACTION_MERIDIAN := Color(0.76, 0.64, 1.0)
const ENTER_DISTANCE_PORT := 0.052
const ENTER_DISTANCE_FORT := 0.058
const ENTER_DISTANCE_SEA := 0.082
const ENCOUNTER_DISTANCE := 0.030
const OPPORTUNITY_DISTANCE := 0.052
const PARTY_DETECTION_DISTANCE := 0.115
const PARTY_CHASE_DISTANCE := 0.090
const PARTY_FLEE_DISTANCE := 0.075

var _map_canvas: MapCanvas
var _location_labels: Array[Label] = []
var _party_labels: Array[Label] = []
var _bottom_buttons := {}
var _tooltip_panel: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _selected_panel: PanelContainer
var _selected_title: Label
var _selected_body: Label
var _ship_ledger_panel: PanelContainer
var _ship_ledger_title: Label
var _ship_ledger_body: Label
var _course_panel: PanelContainer
var _course_title: Label
var _course_body: Label
var _world_events_panel: PanelContainer
var _world_events_title: Label
var _world_events_body: Label
var _warfront_panel: PanelContainer
var _warfront_title: Label
var _warfront_body: Label
var _captains_desk_panel: PanelContainer
var _captains_desk_title: Label
var _captains_desk_body: Label
var _map_legend_panel: PanelContainer
var _map_legend_title: Label
var _map_legend_body: Label
var _info_panel: PanelContainer
var _info_title: Label
var _info_body: Label
var _info_scroll: ScrollContainer
var _info_content: VBoxContainer
var _service_buttons := {}
var _interaction_panel: PanelContainer
var _interaction_title: Label
var _interaction_body: Label
var _interaction_scroll: ScrollContainer
var _interaction_content: VBoxContainer
var _interaction_buttons := {}
var _interaction_notice := ""
var _hud_suppressed := false
var _pending_after_action_report := ""
var _pending_after_action_title := ""
var _locked_encounter_party_name := ""
var _pending_opportunity_reward := {}
var _date_label: Label
var _control_label: Label
var _selected_index := 0
var _hover_index := -1
var _hover_party_index := -1
var _selected_party_index := -1
var _selected_opportunity_index := -1
var _active_panel_section := ""
var _can_close := false
var _player_position := Vector2(0.53, 0.70)
var _player_target := Vector2(0.53, 0.70)
var _player_direction := Vector2.RIGHT
var _player_speed := 0.058
var _campaign_day := 3.0
var _last_wage_day := 3
var _nearest_location_distance := 999.0
var _nearby_encounter_index := -1
var _pressure_timer := 0.0
var _fatigue_timer := 0.0
var _active_pressure_faction := ""
var _encounter_log: Array[String] = []
var _defeated_parties: Array[Dictionary] = []
var _cargo_hold := {
	"timber": 14,
	"canvas": 8,
	"powder": 11,
	"cannon_parts": 3,
	"silver": 42,
	"contraband": 0,
}
var _ship_condition := {
	"hull": 100,
	"repair_supplies": 3,
	"morale": 58,
	"sailors": 42,
	"gunners": 18,
	"carpenters": 6,
}
var _captain_renown := 12
var _faction_reputation := {
	"Crown Dominion": -8,
	"Free Captains": 18,
	"Ironwake Compact": 0,
	"Independent": 6,
	"Unclaimed": -14,
	"Uncharted": -22,
}
var _faction_power := {
	"Crown Dominion": 82,
	"Free Captains": 58,
	"Ironwake Compact": 64,
	"Independent": 46,
	"Unclaimed": 34,
	"Uncharted": 28,
}
var _political_log: Array[String] = []
var _settlement_modifiers := {}
var _active_region_operation: Dictionary = {}
var _regional_effects: Array[Dictionary] = []
var _active_contracts: Array[Dictionary] = []
var _completed_contracts: Array[Dictionary] = []
var _contract_sequence := 0
var _discovered_regions := {
	"pale_meridian": false,
}
var _harbor_ships := [
	{"name": "Sable Wake Anchorage", "position": Vector2(0.56, 0.69), "direction": Vector2(1.0, -0.16), "color": Color(0.88, 0.92, 0.82)},
]

var _sea_opportunities := [
	{"id": "wreck_batabano", "name": "Drifting Wreck", "type": "salvage", "position": Vector2(0.49, 0.58), "risk": "low", "reward": "timber, canvas and parts", "description": "A broken hull rolls in the swell. Salvage crews can strip useful repair materials."},
	{"id": "survivors_windward", "name": "Survivor Boats", "type": "rescue", "position": Vector2(0.70, 0.56), "risk": "medium", "reward": "crew and morale", "description": "Small boats wave torn shirts near a contested lane. Rescue may add crew but costs time."},
	{"id": "smoke_blackreef", "name": "Smoke on the Shoals", "type": "mystery", "position": Vector2(0.39, 0.77), "risk": "dangerous", "reward": "silver, contraband or trouble", "description": "A thin black column rises behind the reefs. It could be salvage, smugglers, or a trap."},
]

var _locations := [
	{"id": "port_royal", "name": "Port Royal", "kind": "port", "position": Vector2(0.53, 0.70), "faction": "Free Captains", "color": FACTION_FREE, "mood": "Privateer haven", "description": "Starter harbor with repairs, tavern leads and light patrol contracts."},
	{"id": "havana", "name": "Havana", "kind": "port", "position": Vector2(0.43, 0.46), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Treasure fleet port", "description": "Heavy escorts, rich prizes and expensive shipwrights."},
	{"id": "nassau", "name": "Nassau", "kind": "port", "position": Vector2(0.66, 0.34), "faction": "Free Captains", "color": FACTION_FREE, "mood": "Pirate republic", "description": "Black market repairs, rumors and rival captains."},
	{"id": "santo_domingo", "name": "Santo Domingo", "kind": "port", "position": Vector2(0.82, 0.70), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Old fortress coast", "description": "Fort guns, merchant traffic and dangerous patrol lanes."},
	{"id": "tortuga", "name": "Tortuga", "kind": "port", "position": Vector2(0.73, 0.60), "faction": "Free Captains", "color": FACTION_RAIDER, "mood": "Raider anchorage", "description": "High-risk taverns, bounty hunters and cheap repairs."},
	{"id": "veracruz", "name": "Veracruz", "kind": "port", "position": Vector2(0.09, 0.56), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Mainland silver port", "description": "Treasure convoys leave under strong escort."},
	{"id": "campeche", "name": "Campeche", "kind": "port", "position": Vector2(0.23, 0.62), "faction": "Ironwake Compact", "color": FACTION_IRON, "mood": "Shallow bay", "description": "Smugglers, reefs and disciplined checkpoint ships."},
	{"id": "belize", "name": "Belize", "kind": "port", "position": Vector2(0.30, 0.73), "faction": "Independent", "color": Color(0.88, 0.92, 0.82), "mood": "Cutters and mangroves", "description": "Neutral repair yards and low-profile contracts."},
	{"id": "key_west", "name": "Key West", "kind": "fort", "position": Vector2(0.50, 0.32), "faction": "Ironwake Compact", "color": FACTION_IRON, "mood": "Checkpoint strait", "description": "Fast patrols inspect cargo crossing the Florida shallows."},
	{"id": "grand_bahama", "name": "Grand Bahama", "kind": "port", "position": Vector2(0.62, 0.24), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Northern patrol dock", "description": "Safe harbor under strict military watch."},
	{"id": "santiago", "name": "Santiago", "kind": "port", "position": Vector2(0.64, 0.59), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Mountain coast", "description": "Convoy staging point at the mouth of the Windward Passage."},
	{"id": "san_juan", "name": "San Juan", "kind": "fort", "position": Vector2(0.92, 0.70), "faction": "Crown Dominion", "color": FACTION_CROWN, "mood": "Eastern fortress", "description": "Late-route stronghold with broadside batteries."},
	{"id": "windward_passage", "name": "Windward Passage", "kind": "sea", "position": Vector2(0.68, 0.64), "faction": "Trade Route", "color": Color(0.95, 0.78, 0.42), "mood": "Choked convoy lane", "description": "A narrow sea road where escorts, smugglers and raiders collide."},
	{"id": "gulf_batabano", "name": "Gulf of Batabano", "kind": "sea", "position": Vector2(0.47, 0.54), "faction": "Independent", "color": Color(0.64, 0.92, 0.94), "mood": "Starter waters", "description": "Open patrol water between Cuba and Port Royal."},
	{"id": "blackreef", "name": "Blackreef Wrecks", "kind": "sea", "position": Vector2(0.35, 0.83), "faction": "Unclaimed", "color": FACTION_RAIDER, "mood": "Wreck field", "description": "Sharp reefs, salvage lights and ambush channels."},
	{"id": "pale_meridian", "name": "Pale Meridian", "kind": "sea", "position": Vector2(0.90, 0.20), "faction": "Uncharted", "color": FACTION_MERIDIAN, "mood": "Locked fog", "description": "Late-campaign unknown water with strange currents and rumors."},
]

var _parties := [
	{"name": "Crown treasure fleet", "faction": "Crown Dominion", "role": "Treasure convoy", "stance": "flee", "cargo": "silver bars", "position": Vector2(0.14, 0.58), "route": [Vector2(0.09, 0.56), Vector2(0.23, 0.62), Vector2(0.43, 0.46), Vector2(0.64, 0.59)], "route_index": 1, "speed": 0.044, "strength": 126, "color": FACTION_CROWN},
	{"name": "Havana escort", "faction": "Crown Dominion", "role": "Escort squadron", "stance": "shadow", "cargo": "naval orders", "position": Vector2(0.44, 0.48), "route": [Vector2(0.43, 0.46), Vector2(0.47, 0.54), Vector2(0.50, 0.32)], "route_index": 0, "speed": 0.058, "strength": 84, "color": FACTION_CROWN},
	{"name": "Nassau free captains", "faction": "Free Captains", "role": "Privateer band", "stance": "neutral", "cargo": "letters of marque", "position": Vector2(0.64, 0.36), "route": [Vector2(0.66, 0.34), Vector2(0.62, 0.24), Vector2(0.73, 0.60), Vector2(0.53, 0.70)], "route_index": 0, "speed": 0.078, "strength": 67, "color": FACTION_FREE},
	{"name": "Tortuga raiders", "faction": "Free Captains", "role": "Raider flotilla", "stance": "chase", "cargo": "stolen rum", "position": Vector2(0.72, 0.62), "route": [Vector2(0.73, 0.60), Vector2(0.68, 0.64), Vector2(0.53, 0.70), Vector2(0.35, 0.83)], "route_index": 1, "speed": 0.072, "strength": 91, "color": FACTION_RAIDER},
	{"name": "Ironwake patrol", "faction": "Ironwake Compact", "role": "Checkpoint patrol", "stance": "shadow", "cargo": "inspection seals", "position": Vector2(0.49, 0.34), "route": [Vector2(0.50, 0.32), Vector2(0.47, 0.54), Vector2(0.23, 0.62), Vector2(0.30, 0.73)], "route_index": 0, "speed": 0.062, "strength": 74, "color": FACTION_IRON},
	{"name": "Belize smugglers", "faction": "Independent", "role": "Smuggler party", "stance": "flee", "cargo": "contraband timber", "position": Vector2(0.31, 0.73), "route": [Vector2(0.30, 0.73), Vector2(0.35, 0.83), Vector2(0.53, 0.70), Vector2(0.47, 0.54)], "route_index": 2, "speed": 0.082, "strength": 38, "color": Color(0.88, 0.92, 0.82)},
	{"name": "Port Royal hunters", "faction": "Free Captains", "role": "Bounty hunters", "stance": "chase", "cargo": "bounty writs", "position": Vector2(0.56, 0.69), "route": [Vector2(0.53, 0.70), Vector2(0.68, 0.64), Vector2(0.82, 0.70), Vector2(0.92, 0.70)], "route_index": 1, "speed": 0.066, "strength": 58, "color": FACTION_FREE},
	{"name": "Bahama courier", "faction": "Crown Dominion", "role": "Fast courier", "stance": "flee", "cargo": "sealed dispatch", "position": Vector2(0.63, 0.26), "route": [Vector2(0.62, 0.24), Vector2(0.66, 0.34), Vector2(0.50, 0.32), Vector2(0.43, 0.46)], "route_index": 1, "speed": 0.095, "strength": 26, "color": FACTION_CROWN},
	{"name": "Santo Domingo patrol", "faction": "Crown Dominion", "role": "Fort patrol", "stance": "shadow", "cargo": "powder kegs", "position": Vector2(0.80, 0.69), "route": [Vector2(0.82, 0.70), Vector2(0.73, 0.60), Vector2(0.68, 0.64), Vector2(0.64, 0.59)], "route_index": 0, "speed": 0.060, "strength": 82, "color": FACTION_CROWN},
	{"name": "Meridian scouts", "faction": "Uncharted", "role": "Fog scouts", "stance": "avoid", "cargo": "strange charts", "position": Vector2(0.84, 0.30), "route": [Vector2(0.90, 0.20), Vector2(0.66, 0.34), Vector2(0.62, 0.24)], "route_index": 0, "speed": 0.052, "strength": 44, "color": FACTION_MERIDIAN},
	{"name": "Blackreef salvagers", "faction": "Unclaimed", "role": "Salvage crew", "stance": "neutral", "cargo": "wreck scrap", "position": Vector2(0.36, 0.80), "route": [Vector2(0.35, 0.83), Vector2(0.30, 0.73), Vector2(0.53, 0.70)], "route_index": 0, "speed": 0.050, "strength": 52, "color": FACTION_RAIDER},
	{"name": "San Juan courier", "faction": "Crown Dominion", "role": "Military courier", "stance": "flee", "cargo": "fort payroll", "position": Vector2(0.89, 0.70), "route": [Vector2(0.92, 0.70), Vector2(0.82, 0.70), Vector2(0.73, 0.60)], "route_index": 1, "speed": 0.088, "strength": 31, "color": FACTION_CROWN},
	{"name": "Dutch spice convoy", "faction": "Ironwake Compact", "role": "Merchant convoy", "stance": "flee", "cargo": "spice crates", "position": Vector2(0.19, 0.66), "route": [Vector2(0.23, 0.62), Vector2(0.30, 0.73), Vector2(0.47, 0.54), Vector2(0.50, 0.32)], "route_index": 2, "speed": 0.054, "strength": 96, "color": FACTION_IRON},
	{"name": "Windward blockade", "faction": "Crown Dominion", "role": "Blockade line", "stance": "chase", "cargo": "military stores", "position": Vector2(0.69, 0.63), "route": [Vector2(0.68, 0.64), Vector2(0.64, 0.59), Vector2(0.82, 0.70), Vector2(0.73, 0.60)], "route_index": 1, "speed": 0.048, "strength": 138, "color": FACTION_CROWN},
	{"name": "Reef runner flotilla", "faction": "Unclaimed", "role": "Fast raiders", "stance": "chase", "cargo": "reef loot", "position": Vector2(0.40, 0.78), "route": [Vector2(0.35, 0.83), Vector2(0.53, 0.70), Vector2(0.47, 0.54), Vector2(0.30, 0.73)], "route_index": 0, "speed": 0.098, "strength": 34, "color": FACTION_RAIDER},
	{"name": "Free captain council", "faction": "Free Captains", "role": "Council fleet", "stance": "neutral", "cargo": "captain votes", "position": Vector2(0.57, 0.72), "route": [Vector2(0.53, 0.70), Vector2(0.73, 0.60), Vector2(0.66, 0.34), Vector2(0.62, 0.24)], "route_index": 0, "speed": 0.060, "strength": 112, "color": FACTION_FREE},
	{"name": "Mainland salt traders", "faction": "Independent", "role": "Coastal traders", "stance": "flee", "cargo": "salt and hides", "position": Vector2(0.07, 0.50), "route": [Vector2(0.09, 0.56), Vector2(0.23, 0.62), Vector2(0.30, 0.73)], "route_index": 0, "speed": 0.047, "strength": 41, "color": Color(0.88, 0.92, 0.82)},
	{"name": "Pale Meridian omen", "faction": "Uncharted", "role": "Unknown fleet", "stance": "avoid", "cargo": "unreadable relics", "position": Vector2(0.91, 0.24), "route": [Vector2(0.90, 0.20), Vector2(0.84, 0.30), Vector2(0.78, 0.48), Vector2(0.98, 0.40)], "route_index": 1, "speed": 0.038, "strength": 73, "color": FACTION_MERIDIAN},
]

var _sea_regions := [
	{"name": "Dominion Main", "faction": "Crown Dominion", "color": FACTION_CROWN, "points": [Vector2(0.02, 0.42), Vector2(0.45, 0.36), Vector2(0.58, 0.48), Vector2(0.55, 0.66), Vector2(0.16, 0.72), Vector2(0.03, 0.62)]},
	{"name": "Free Captain Coast", "faction": "Free Captains", "color": FACTION_FREE, "points": [Vector2(0.50, 0.28), Vector2(0.72, 0.30), Vector2(0.78, 0.60), Vector2(0.55, 0.76), Vector2(0.44, 0.55)]},
	{"name": "Ironwake Shoals", "faction": "Ironwake Compact", "color": FACTION_IRON, "points": [Vector2(0.20, 0.54), Vector2(0.52, 0.30), Vector2(0.56, 0.55), Vector2(0.33, 0.80), Vector2(0.16, 0.74)]},
	{"name": "Blackreef Freewater", "faction": "Unclaimed", "color": FACTION_RAIDER, "points": [Vector2(0.25, 0.72), Vector2(0.50, 0.70), Vector2(0.54, 0.90), Vector2(0.18, 0.90)]},
	{"name": "Pale Meridian", "faction": "Uncharted", "color": FACTION_MERIDIAN, "points": [Vector2(0.72, 0.08), Vector2(0.98, 0.08), Vector2(0.98, 0.40), Vector2(0.78, 0.48), Vector2(0.64, 0.28)]},
]

var _landmasses := [
	{
		"color": Color(0.25, 0.37, 0.19),
		"points": [
			Vector2(0.00, 0.02), Vector2(0.34, 0.00), Vector2(0.50, 0.05), Vector2(0.61, 0.10),
			Vector2(0.60, 0.20), Vector2(0.56, 0.30), Vector2(0.49, 0.34), Vector2(0.39, 0.27),
			Vector2(0.26, 0.20), Vector2(0.12, 0.22), Vector2(0.00, 0.28)
		]
	},
	{
		"color": Color(0.28, 0.39, 0.18),
		"points": [
			Vector2(0.00, 0.42), Vector2(0.12, 0.45), Vector2(0.23, 0.55), Vector2(0.32, 0.67),
			Vector2(0.29, 0.82), Vector2(0.16, 0.88), Vector2(0.00, 0.82)
		]
	},
	{
		"color": Color(0.30, 0.42, 0.20),
		"points": [
			Vector2(0.36, 0.45), Vector2(0.46, 0.42), Vector2(0.57, 0.47), Vector2(0.68, 0.57),
			Vector2(0.64, 0.63), Vector2(0.52, 0.58), Vector2(0.40, 0.53), Vector2(0.34, 0.49)
		]
	},
	{
		"color": Color(0.27, 0.38, 0.20),
		"points": [
			Vector2(0.49, 0.68), Vector2(0.57, 0.66), Vector2(0.62, 0.72), Vector2(0.55, 0.76),
			Vector2(0.47, 0.74)
		]
	},
	{
		"color": Color(0.29, 0.39, 0.19),
		"points": [
			Vector2(0.70, 0.62), Vector2(0.82, 0.61), Vector2(0.91, 0.69), Vector2(0.84, 0.78),
			Vector2(0.73, 0.72)
		]
	},
	{
		"color": Color(0.31, 0.41, 0.20),
		"points": [
			Vector2(0.88, 0.68), Vector2(0.98, 0.68), Vector2(1.00, 0.76), Vector2(0.92, 0.80)
		]
	},
	{
		"color": Color(0.25, 0.37, 0.18),
		"points": [
			Vector2(0.61, 0.22), Vector2(0.67, 0.23), Vector2(0.68, 0.29), Vector2(0.62, 0.31),
			Vector2(0.58, 0.27)
		]
	},
	{
		"color": Color(0.26, 0.38, 0.18),
		"points": [
			Vector2(0.66, 0.35), Vector2(0.72, 0.37), Vector2(0.71, 0.42), Vector2(0.64, 0.42)
		]
	},
]

var _sea_routes := [
	[Vector2(0.09, 0.56), Vector2(0.23, 0.62), Vector2(0.43, 0.46), Vector2(0.64, 0.59), Vector2(0.82, 0.70), Vector2(0.92, 0.70)],
	[Vector2(0.53, 0.70), Vector2(0.68, 0.64), Vector2(0.73, 0.60), Vector2(0.82, 0.70)],
	[Vector2(0.43, 0.46), Vector2(0.50, 0.32), Vector2(0.62, 0.24), Vector2(0.66, 0.34)],
	[Vector2(0.30, 0.73), Vector2(0.35, 0.83), Vector2(0.53, 0.70), Vector2(0.47, 0.54)],
	[Vector2(0.66, 0.34), Vector2(0.90, 0.20)],
]

var _forest_points: Array[Vector2] = []
var _reef_points: Array[Vector2] = []
var _mountain_points: Array[Vector2] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_terrain_points()
	_build()
	_set_selected_index(0)
	hide_map()


func _process(_delta: float) -> void:
	if not visible:
		return

	_update_regional_effects()
	_update_campaign_movement(_delta)
	_update_ship_ledger_panel()
	_update_world_events_panel()
	_update_warfront_panel()
	_update_captains_desk_panel()
	_update_map_legend_panel()
	if Input.is_action_just_pressed("map_previous"):
		_set_selected_index(_selected_index - 1)
	elif Input.is_action_just_pressed("map_next"):
		_set_selected_index(_selected_index + 1)
	elif Input.is_action_just_pressed("map_confirm"):
		_try_deploy_selected_region()
	elif _can_close and Input.is_action_just_pressed("campaign_map"):
		close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if _interaction_panel != null and _interaction_panel.visible:
				_hide_interaction_panel()
			elif _info_panel != null and _info_panel.visible:
				_info_panel.visible = false
			elif _can_close:
				close_requested.emit()
			get_viewport().set_input_as_handled()


func show_map(can_close: bool) -> void:
	_can_close = can_close
	visible = true
	_set_campaign_hud_suppressed(false)
	_control_label.text = "WASD/Arrows free travel   Left-click route/select   Party click reports   Enter near a port/sea to sail%s" % ("   M close" if can_close else "")
	if _active_panel_section.is_empty():
		_show_bottom_panel("Camp")
	_update_ship_ledger_panel()
	_update_course_panel()
	_update_world_events_panel()
	_update_warfront_panel()
	_update_captains_desk_panel()
	_update_map_legend_panel()
	_map_canvas.queue_redraw()
	_position_world_labels()
	_show_pending_after_action_report()


func hide_map() -> void:
	visible = false
	if _tooltip_panel:
		_tooltip_panel.visible = false


func get_selected_region() -> Dictionary:
	return _locations[_selected_index]


func get_player_position() -> Vector2:
	return _player_position


func get_player_target() -> Vector2:
	return _player_target


func get_party_count() -> int:
	return _parties.size()


func get_harbor_ship_count() -> int:
	return _harbor_ships.size()


func get_party_snapshot() -> Array:
	var snapshot := []
	for party in _parties:
		snapshot.append(party.duplicate(true))
	return snapshot


func has_open_panel() -> bool:
	return _info_panel != null and _info_panel.visible


func get_open_panel_section() -> String:
	return _active_panel_section


func can_enter_selected_region() -> bool:
	return _is_location_enterable(get_selected_region())


func can_enter_selected_party() -> bool:
	return _selected_party_index >= 0 and _selected_party_index == _nearby_encounter_index


func get_nearby_encounter() -> Dictionary:
	if _nearby_encounter_index < 0 or _nearby_encounter_index >= _parties.size():
		return {}
	return _parties[_nearby_encounter_index].duplicate(true)


func get_encounter_count() -> int:
	return _encounter_log.size()


func get_defeated_party_count() -> int:
	return _defeated_parties.size()


func get_cargo_snapshot() -> Dictionary:
	return _cargo_hold.duplicate(true)


func get_ship_condition() -> Dictionary:
	return _ship_condition.duplicate(true)


func get_market_snapshot() -> Dictionary:
	return _get_market_snapshot()


func get_reputation_snapshot() -> Dictionary:
	return _faction_reputation.duplicate(true)


func get_renown() -> int:
	return _captain_renown


func get_contract_snapshot() -> Array:
	var snapshot := []
	for contract in _active_contracts:
		snapshot.append(contract.duplicate(true))
	return snapshot


func get_completed_contract_snapshot() -> Array:
	var snapshot := []
	for contract in _completed_contracts:
		snapshot.append(contract.duplicate(true))
	return snapshot


func is_contract_target(party_name: String) -> bool:
	for contract in _active_contracts:
		if String(contract.get("status", "active")) == "active" and String(contract.get("target", "")) == party_name:
			return true
	return false


func is_contract_location_target(location_id: String) -> bool:
	for contract in _active_contracts:
		if String(contract.get("status", "active")) == "active" and String(contract.get("type", "hunt")) == "delivery" and String(contract.get("target_id", "")) == location_id:
			return true
	return false


func can_enter_selected_opportunity() -> bool:
	if _selected_opportunity_index < 0 or _selected_opportunity_index >= _sea_opportunities.size():
		return false
	var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
	return _player_position.distance_to(opportunity.get("position", Vector2.ZERO)) <= OPPORTUNITY_DISTANCE


func is_region_id_unlocked(region_id: String) -> bool:
	if region_id.is_empty() or not _discovered_regions.has(region_id):
		return true
	return bool(_discovered_regions.get(region_id, false))


func get_party_relation_state(party: Dictionary) -> Dictionary:
	return _get_party_relation_state(party)


func record_ship_condition(telemetry: Dictionary) -> void:
	_ship_condition["hull"] = clampi(int(round(float(telemetry.get("health", 100.0)) / maxf(float(telemetry.get("max_health", 100.0)), 1.0) * 100.0)), 0, 100)
	_ship_condition["repair_supplies"] = clampi(int(telemetry.get("repair_supplies", _ship_condition.get("repair_supplies", 3))), 0, 3)
	_ship_condition["morale"] = clampi(int(_ship_condition.get("morale", 58)) - (8 if int(_ship_condition.get("hull", 100)) < 45 else 0), 0, 100)


func add_boarding_crew_reward() -> void:
	var old_sailors := int(_ship_condition.get("sailors", 42))
	var old_gunners := int(_ship_condition.get("gunners", 18))
	_ship_condition["sailors"] = clampi(old_sailors + 2, 0, _crew_cap("sailors"))
	_ship_condition["gunners"] = clampi(old_gunners + 1, 0, _crew_cap("gunners"))
	_ship_condition["morale"] = clampi(int(_ship_condition.get("morale", 58)) + 3, 0, 100)
	_encounter_log.push_front("Boarding prize crew joined: sailors +%d, gunners +%d" % [
		int(_ship_condition.get("sailors", 42)) - old_sailors,
		int(_ship_condition.get("gunners", 18)) - old_gunners,
	])


func _crew_cap(kind: String) -> int:
	match kind:
		"sailors":
			return 48
		"gunners":
			return 22
		"carpenters":
			return 8
		_:
			return 99


func perform_port_service(service: String) -> bool:
	if service == "track_job":
		var tracked := _service_track_contract()
		if tracked:
			if _info_panel != null and _info_panel.visible and not _active_panel_section.is_empty():
				_populate_bottom_panel(_active_panel_section)
		return tracked
	if service == "engage_party":
		return _service_engage_party()
	if service == "hail_party":
		var hailed := _service_hail_party()
		if hailed and _info_panel != null and _info_panel.visible and not _active_panel_section.is_empty():
			_populate_bottom_panel(_active_panel_section)
		return hailed
	if service == "inspect_party":
		return _service_inspect_party()
	if not _can_use_port_services():
		_encounter_log.push_front("Need a harbor or fort anchorage for services")
		return false
	if _is_service_blocked_by_settlement(service):
		return false
	var changed := false
	match service:
		"repair":
			changed = _service_repair_hull()
		"resupply":
			changed = _service_resupply()
		"rest":
			changed = _service_rest()
		"buy_timber":
			changed = _service_buy_good("timber", 2)
		"buy_canvas":
			changed = _service_buy_good("canvas", 2)
		"buy_powder":
			changed = _service_buy_good("powder", 2)
		"sell_contraband":
			changed = _service_sell_good("contraband", 1)
		"sell_cannon_parts":
			changed = _service_sell_good("cannon_parts", 1)
		"hire_crew":
			changed = _service_hire_crew()
		"take_job":
			changed = _service_take_contract()
		"take_local_incident":
			changed = _service_take_local_incident()
		"ask_news":
			changed = _service_ask_news()
	if changed:
		if _info_panel != null and _info_panel.visible and not _active_panel_section.is_empty():
			_populate_bottom_panel(_active_panel_section)
		_update_date_label()
		_update_course_panel()
	return changed


func resolve_encounter_result(result: Dictionary) -> void:
	var party: Dictionary = result.get("party", {})
	if party.is_empty():
		return
	var party_name := String(party.get("name", "Fleet"))
	var outcome := String(result.get("outcome", "defeated"))
	var loot: Dictionary = result.get("loot", _build_loot_for_party(party, outcome))
	_remove_party_by_name(party_name)
	_apply_campaign_loot(loot)
	var reputation_delta := _apply_reputation_for_result(party, outcome)
	var power_delta := _apply_faction_power_for_result(party, outcome)
	var contract_result := _resolve_contract_for_party(party_name)
	var operation_result := _resolve_active_region_operation_for_party(party, outcome)
	_update_discovery_state()
	_defeated_parties.push_front({
		"name": party_name,
		"faction": String(party.get("faction", "Unknown")),
		"role": String(party.get("role", "Fleet")),
		"outcome": outcome,
		"loot": loot.duplicate(true),
		"reputation_delta": reputation_delta.duplicate(true),
		"power_delta": power_delta,
		"day": int(floor(_campaign_day)),
	})
	if _defeated_parties.size() > 12:
		_defeated_parties.resize(12)
	_encounter_log.push_front("%s %s; cargo transferred" % [party_name, outcome])
	if _encounter_log.size() > 8:
		_encounter_log.resize(8)
	_nearby_encounter_index = -1
	_selected_party_index = -1
	_locked_encounter_party_name = ""
	_position_world_labels()
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()
	if _info_panel != null and _info_panel.visible and not _active_panel_section.is_empty():
		_populate_bottom_panel(_active_panel_section)
	_prepare_after_action_report(party, outcome, loot, reputation_delta, power_delta, contract_result)
	if not operation_result.is_empty():
		_pending_after_action_report += "\n\nRegional operation\n%s" % String(operation_result.get("summary", "Operation updated"))
	_show_pending_after_action_report()


func get_nearest_location_distance() -> float:
	return _nearest_location_distance


func press_bottom_button(section: String) -> void:
	_show_bottom_panel(section)


func _build() -> void:
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_map_canvas = MapCanvas.new()
	_map_canvas.name = "WorldMapCanvas"
	_map_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_map_canvas.owner_ui = self
	_map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_canvas.offset_bottom = -78.0
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_map_canvas)

	for i in range(_locations.size()):
		var location: Dictionary = _locations[i]
		var label := _make_label(String(location.get("name", "Location")), 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", location.get("color", Color.WHITE))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(label)
		_location_labels.append(label)

	for party in _parties:
		var label := _make_label("%s  %d" % [String(party.get("name", "Party")), int(party.get("strength", 0))], 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", party.get("color", Color.WHITE))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(label)
		_party_labels.append(label)

	_build_selected_panel(root)
	_build_ship_ledger_panel(root)
	_build_course_panel(root)
	_build_world_events_panel(root)
	_build_warfront_panel(root)
	_build_captains_desk_panel(root)
	_build_map_legend_panel(root)
	_build_info_panel(root)
	_build_interaction_panel(root)
	_build_tooltip(root)
	_build_bottom_bar(root)
	_position_world_labels()


func _build_selected_panel(root: Control) -> void:
	_selected_panel = PanelContainer.new()
	_selected_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.025, 0.025, 0.82)))
	_selected_panel.anchor_left = 0.02
	_selected_panel.anchor_right = 0.33
	_selected_panel.anchor_top = 0.04
	_selected_panel.anchor_bottom = 0.04
	_selected_panel.offset_bottom = 108.0
	root.add_child(_selected_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_selected_panel.add_child(box)
	_selected_title = _make_label("", 21)
	_selected_body = _make_label("", 13)
	_selected_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_selected_title)
	box.add_child(_selected_body)


func _build_ship_ledger_panel(root: Control) -> void:
	_ship_ledger_panel = PanelContainer.new()
	_ship_ledger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_ledger_panel.z_index = 27
	_ship_ledger_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.030, 0.034, 0.84)))
	_ship_ledger_panel.anchor_left = 0.36
	_ship_ledger_panel.anchor_right = 0.60
	_ship_ledger_panel.anchor_top = 0.04
	_ship_ledger_panel.anchor_bottom = 0.04
	_ship_ledger_panel.offset_bottom = 126.0
	root.add_child(_ship_ledger_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_ship_ledger_panel.add_child(box)

	_ship_ledger_title = _make_label("Ship Ledger", 20)
	_ship_ledger_title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	box.add_child(_ship_ledger_title)

	_ship_ledger_body = _make_label("", 12)
	_ship_ledger_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ship_ledger_body)
	_update_ship_ledger_panel()


func _build_course_panel(root: Control) -> void:
	_course_panel = PanelContainer.new()
	_course_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_course_panel.z_index = 28
	_course_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.025, 0.018, 0.88)))
	_course_panel.anchor_left = 0.62
	_course_panel.anchor_right = 0.98
	_course_panel.anchor_top = 0.04
	_course_panel.anchor_bottom = 0.04
	_course_panel.offset_bottom = 318.0
	root.add_child(_course_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_course_panel.add_child(box)

	_course_title = _make_label("Captain's Course", 22)
	_course_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	box.add_child(_course_title)

	_course_body = _make_label("", 13)
	_course_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_course_body)


func _build_world_events_panel(root: Control) -> void:
	_world_events_panel = PanelContainer.new()
	_world_events_panel.visible = false
	_world_events_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_events_panel.z_index = 27
	_world_events_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.026, 0.022, 0.84)))
	_world_events_panel.anchor_left = 0.02
	_world_events_panel.anchor_right = 0.34
	_world_events_panel.anchor_top = 0.18
	_world_events_panel.anchor_bottom = 0.18
	_world_events_panel.offset_bottom = 186.0
	root.add_child(_world_events_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_world_events_panel.add_child(box)

	_world_events_title = _make_label("World Events", 20)
	_world_events_title.add_theme_color_override("font_color", Color(0.84, 0.96, 0.82))
	box.add_child(_world_events_title)

	_world_events_body = _make_label("", 12)
	_world_events_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_world_events_body)
	_update_world_events_panel()


func _build_warfront_panel(root: Control) -> void:
	_warfront_panel = PanelContainer.new()
	_warfront_panel.visible = false
	_warfront_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warfront_panel.z_index = 27
	_warfront_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.026, 0.020, 0.018, 0.84)))
	_warfront_panel.anchor_left = 0.02
	_warfront_panel.anchor_right = 0.34
	_warfront_panel.anchor_top = 0.40
	_warfront_panel.anchor_bottom = 0.40
	_warfront_panel.offset_bottom = 212.0
	root.add_child(_warfront_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_warfront_panel.add_child(box)

	_warfront_title = _make_label("Warfront", 20)
	_warfront_title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42))
	box.add_child(_warfront_title)

	_warfront_body = _make_label("", 12)
	_warfront_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_warfront_body)
	_update_warfront_panel()


func _build_captains_desk_panel(root: Control) -> void:
	_captains_desk_panel = PanelContainer.new()
	_captains_desk_panel.visible = false
	_captains_desk_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_captains_desk_panel.z_index = 27
	_captains_desk_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.020, 0.026, 0.86)))
	_captains_desk_panel.anchor_left = 0.36
	_captains_desk_panel.anchor_right = 0.69
	_captains_desk_panel.anchor_top = 1.0
	_captains_desk_panel.anchor_bottom = 1.0
	_captains_desk_panel.offset_top = -300.0
	_captains_desk_panel.offset_bottom = -90.0
	root.add_child(_captains_desk_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_captains_desk_panel.add_child(box)

	_captains_desk_title = _make_label("Captain's Desk", 20)
	_captains_desk_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	box.add_child(_captains_desk_title)

	_captains_desk_body = _make_label("", 12)
	_captains_desk_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_captains_desk_body)
	_update_captains_desk_panel()


func _build_map_legend_panel(root: Control) -> void:
	_map_legend_panel = PanelContainer.new()
	_map_legend_panel.visible = false
	_map_legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_legend_panel.z_index = 26
	_map_legend_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.020, 0.026, 0.82)))
	_map_legend_panel.anchor_left = 0.70
	_map_legend_panel.anchor_right = 0.98
	_map_legend_panel.anchor_top = 1.0
	_map_legend_panel.anchor_bottom = 1.0
	_map_legend_panel.offset_top = -268.0
	_map_legend_panel.offset_bottom = -90.0
	root.add_child(_map_legend_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_map_legend_panel.add_child(box)

	_map_legend_title = _make_label("Map Legend", 18)
	_map_legend_title.add_theme_color_override("font_color", Color(0.92, 0.90, 0.78))
	box.add_child(_map_legend_title)

	_map_legend_body = _make_label("", 12)
	_map_legend_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_map_legend_body)
	_update_map_legend_panel()


func _build_tooltip(root: Control) -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.86)))
	_tooltip_panel.custom_minimum_size = Vector2(230.0, 72.0)
	root.add_child(_tooltip_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_tooltip_panel.add_child(box)
	_tooltip_title = _make_label("", 18)
	_tooltip_body = _make_label("", 12)
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tooltip_title)
	box.add_child(_tooltip_body)


func _build_interaction_panel(root: Control) -> void:
	_interaction_panel = PanelContainer.new()
	_interaction_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_interaction_panel.visible = false
	_interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_interaction_panel.z_index = 48
	_interaction_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.022, 0.018, 0.93)))
	_interaction_panel.anchor_left = 0.58
	_interaction_panel.anchor_right = 0.98
	_interaction_panel.anchor_top = 0.08
	_interaction_panel.anchor_bottom = 0.86
	root.add_child(_interaction_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_interaction_panel.add_child(box)

	_interaction_title = _make_label("", 24)
	_interaction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_interaction_title)

	var separator := HSeparator.new()
	box.add_child(separator)

	_interaction_scroll = ScrollContainer.new()
	_interaction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_interaction_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_interaction_scroll)

	_interaction_content = VBoxContainer.new()
	_interaction_content.add_theme_constant_override("separation", 10)
	_interaction_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_scroll.add_child(_interaction_content)

	_interaction_body = _make_label("", 13)
	_interaction_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_interaction_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(_interaction_body)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(actions)

	for entry in [
		["Tavern", "menu_tavern"],
		["Market", "menu_market"],
		["Shipyard", "menu_shipyard"],
		["Governor", "menu_governor"],
		["Jobs", "menu_jobs"],
		["Back", "menu_settlement"],
		["Repair Hull", "repair"],
		["Resupply Kits", "resupply"],
		["Rest Crew", "rest"],
		["Buy Wood", "buy_timber"],
		["Buy Canvas", "buy_canvas"],
		["Buy Powder", "buy_powder"],
		["Sell Loot", "sell_contraband"],
		["Sell Parts", "sell_cannon_parts"],
		["Hire Crew", "hire_crew"],
		["Take Job", "take_job"],
		["Local Incident", "take_local_incident"],
		["Track Job", "track_job"],
		["Ask News", "ask_news"],
		["Hail Fleet", "hail_party"],
		["Trade/Inspect", "inspect_party"],
		["Engage Fleet", "engage_party"],
		["Launch Battle", "launch_battle"],
		["Scout Waters", "region_scout"],
		["Patrol Contact", "region_patrol"],
		["Raid Waters", "region_raid"],
		["Open Inventory", "open_inventory_report"],
		["Open Notes", "open_reports_panel"],
		["Open Notes", "open_factions_panel"],
		["Continue Sailing", "continue_campaign"],
		["Investigate", "investigate_opportunity"],
		["Take All", "take_all_reward"],
		["Take Half", "take_half_reward"],
		["Take Cargo", "take_cargo_reward"],
		["Take Crew", "take_crew_reward"],
		["Leave Reward", "leave_reward"],
		["Close", "close_interaction"],
	]:
		_add_interaction_button(actions, String(entry[0]), String(entry[1]))


func _add_interaction_button(parent: Control, text: String, action: String) -> void:
	var button := Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(174.0, 38.0)
	if action == "close_interaction":
		button.pressed.connect(_hide_interaction_panel)
	else:
		button.pressed.connect(_run_interaction_action.bind(action))
	parent.add_child(button)
	_interaction_buttons[action] = button


func _build_bottom_bar(root: Control) -> void:
	var bottom := PanelContainer.new()
	bottom.process_mode = Node.PROCESS_MODE_ALWAYS
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.z_index = 30
	bottom.add_theme_stylebox_override("panel", _panel_style(Color(0.54, 0.42, 0.27, 0.96)))
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -78.0
	root.add_child(bottom)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bottom.add_child(row)

	for section in ["Camp", "Notes", "Inventory", "Character", "Party"]:
		_add_bottom_button(row, section)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_date_label = _make_label("April 3, 1665\nAfternoon", 16)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_date_label)

	_control_label = _make_label("", 13)
	_control_label.anchor_left = 0.0
	_control_label.anchor_right = 1.0
	_control_label.anchor_top = 1.0
	_control_label.anchor_bottom = 1.0
	_control_label.offset_top = -24.0
	_control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_control_label)


func _add_bottom_button(row: HBoxContainer, section: String) -> void:
	var button := Button.new()
	button.name = "%sButton" % section
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = section
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(104.0, 38.0)
	button.pressed.connect(_show_bottom_panel.bind(section))
	row.add_child(button)
	_bottom_buttons[section] = button


func _build_info_panel(root: Control) -> void:
	_info_panel = PanelContainer.new()
	_info_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_info_panel.visible = false
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.z_index = 35
	_info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.016, 0.012, 0.96)))
	_info_panel.anchor_left = 0.03
	_info_panel.anchor_right = 0.37
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_top = -360.0
	_info_panel.offset_bottom = -96.0
	root.add_child(_info_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_info_panel.add_child(box)

	_info_title = _make_label("", 19)
	_info_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(_info_title)

	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_info_scroll)

	_info_content = VBoxContainer.new()
	_info_content.add_theme_constant_override("separation", 8)
	_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_scroll.add_child(_info_content)

	_info_body = _make_label("", 12)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_content.add_child(_info_body)

	var close_button := Button.new()
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.text = "Close"
	close_button.pressed.connect(_close_info_panel)
	box.add_child(close_button)


func _add_service_button(row: HBoxContainer, text: String, service: String) -> void:
	var button := Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(92.0, 30.0)
	button.pressed.connect(perform_port_service.bind(service))
	row.add_child(button)
	_service_buttons[service] = button


func _apply_interaction_theme(color: Color, title_color: Color = Color.WHITE) -> void:
	if _interaction_panel != null:
		_interaction_panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.96)))
	if _interaction_title != null:
		_interaction_title.add_theme_color_override("font_color", title_color)
	_apply_interaction_layout(false)
	_reset_interaction_content()


func _apply_interaction_layout(wide: bool) -> void:
	if _interaction_panel == null:
		return
	if wide:
		_interaction_panel.anchor_left = 0.18
		_interaction_panel.anchor_right = 0.82
		_interaction_panel.anchor_top = 0.12
		_interaction_panel.anchor_bottom = 0.86
	else:
		_interaction_panel.anchor_left = 0.58
		_interaction_panel.anchor_right = 0.98
		_interaction_panel.anchor_top = 0.08
		_interaction_panel.anchor_bottom = 0.86
	_interaction_panel.offset_left = 0.0
	_interaction_panel.offset_right = 0.0
	_interaction_panel.offset_top = 0.0
	_interaction_panel.offset_bottom = 0.0


func _reset_interaction_content() -> void:
	if _interaction_content == null:
		return
	for child in _interaction_content.get_children():
		if child != _interaction_body:
			_interaction_content.remove_child(child)
			child.queue_free()
	if _interaction_body != null:
		_interaction_body.visible = true
		_interaction_body.text = ""


func _begin_visual_interaction() -> void:
	if _interaction_body != null:
		_interaction_body.visible = false


func _status_bar(value: int, width: int = 12) -> String:
	var filled := clampi(int(round(float(value) / 100.0 * float(width))), 0, width)
	var output := ""
	for i in range(width):
		output += "#" if i < filled else "-"
	return output


func _settlement_dashboard(location: Dictionary, settlement: Dictionary) -> String:
	var security := int(settlement.get("security", 50))
	var prosperity := int(settlement.get("prosperity", 50))
	var pressure := int(settlement.get("pressure", 50))
	return "Port condition\nSecurity   [%s] %s (%d)\nProsperity [%s] %s (%d)\nPressure   [%s] %d/100\nAccess: %s\nFaction: %s\n\n%s" % [
		_status_bar(security),
		String(settlement.get("security_label", "watched")),
		security,
		_status_bar(prosperity),
		String(settlement.get("prosperity_label", "steady")),
		prosperity,
		_status_bar(pressure),
		pressure,
		String(settlement.get("access_label", "open")),
		String(location.get("faction", "Independent")),
		_settlement_modifier_report(settlement),
	]


func _district_header(name: String, mood: String, effect: String) -> String:
	return "%s\n%s\n%s" % [name, mood, effect]


func _fleet_encounter_dashboard(party: Dictionary, relation_state: Dictionary) -> String:
	var distance := _player_position.distance_to(party.get("position", _player_position)) * 12.0
	var player_power := _player_boarding_power()
	var target_power := _party_boarding_resistance(party, relation_state)
	var boarding_read := _boarding_read(player_power, target_power)
	var recommended := _fleet_recommended_action(party, relation_state, player_power, target_power)
	var close_state := "Close enough for immediate decisions" if can_enter_selected_party() else "Not in speaking range; first click will plot/intercept"
	return "%s\n\nContact report\nFaction: %s - %s (%d)\nRole: %s\nCargo: %s\nIntent: %s -> %s\nDistance: %.1f days\nRange: %s\n\nPower read\nYour boarders [%s] %d\nTarget resistance [%s] %d\nBoarding: %s\nRecommended: %s\n\nAction board\n%s" % [
		_district_header("Fleet Encounter Board", "Your officers gather around the rail while signal flags rise.", "Hail or inspect the contact, then commit to combat and disable it for boarding."),
		String(relation_state.get("faction", "Unknown")),
		String(relation_state.get("label", "Wary")),
		int(relation_state.get("reputation", 0)),
		String(party.get("role", "Fleet")),
		String(party.get("cargo", "unknown")),
		String(party.get("intent", "sailing route")),
		String(relation_state.get("effective_stance", party.get("stance", "neutral"))),
		distance,
		close_state,
		_status_bar(clampi(player_power, 0, 100)),
		player_power,
		_status_bar(clampi(target_power, 0, 100)),
		target_power,
		boarding_read,
		recommended,
		_fleet_action_board_text(party, relation_state, player_power, target_power),
	]


func _boarding_read(player_power: int, target_power: int) -> String:
	if player_power >= target_power + 18:
		return "likely to yield"
	if player_power >= target_power:
		return "uncertain"
	return "will probably fight"


func _fleet_recommended_action(party: Dictionary, relation_state: Dictionary, player_power: int, target_power: int) -> String:
	var stance := String(relation_state.get("effective_stance", "neutral"))
	if not can_enter_selected_party():
		return "Close distance"
	if player_power >= target_power + 18:
		return "Engage and disable for boarding"
	if stance == "flee":
		return "Hail or chase before it slips away"
	if stance == "chase":
		return "Prepare to fight"
	if int(party.get("strength", 0)) > player_power + 15:
		return "Inspect, then avoid or soften later"
	return "Inspect, then choose whether to engage"


func _fleet_action_board_text(party: Dictionary, relation_state: Dictionary, player_power: int, target_power: int) -> String:
	var stance := String(relation_state.get("effective_stance", "neutral"))
	var boarding_line := "Boarding: "
	if player_power >= target_power + 18:
		boarding_line += "strong advantage once the enemy is disabled."
	elif player_power >= target_power:
		boarding_line += "contested; damage enemy guns and morale first."
	else:
		boarding_line += "high risk until the enemy crew is weakened."
	var hail_line := "Hail Fleet: "
	if stance == "chase":
		hail_line += "hostile fleets may refuse and force battle."
	elif stance == "flee":
		hail_line += "may reveal cargo but the fleet may keep running."
	else:
		hail_line += "parley for rumor/context without committing."
	return "%s\nInspect/Trade: reveals cargo, strength and boarding resistance.\n%s\nEngage Fleet: starts naval combat or plots intercept if distant." % [
		hail_line,
		boarding_line,
	]


func _build_settlement_hub_screen(location: Dictionary, settlement: Dictionary) -> void:
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Harbor District", "%s\nPick a district, make a decision, then sail out with changed cargo, crew, contracts or route." % String(location.get("mood", "Anchorage")), Color(0.18, 0.12, 0.07)))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(stats)
	_add_metric_card(stats, "Security", int(settlement.get("security", 50)), String(settlement.get("security_label", "watched")), Color(0.44, 0.68, 0.74))
	_add_metric_card(stats, "Prosperity", int(settlement.get("prosperity", 50)), String(settlement.get("prosperity_label", "steady")), Color(0.72, 0.62, 0.30))
	_add_metric_card(stats, "Pressure", int(settlement.get("pressure", 50)), "sea pressure", Color(0.80, 0.36, 0.28))

	var districts := GridContainer.new()
	districts.columns = 2
	districts.add_theme_constant_override("h_separation", 10)
	districts.add_theme_constant_override("v_separation", 10)
	districts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(districts)
	_add_district_card(districts, "Tavern", "Crew, rest, rumors", "Morale %d" % int(_ship_condition.get("morale", 58)), Color(0.54, 0.32, 0.18))
	_add_district_card(districts, "Market", "Buy stores, sell prize cargo", "Prosperity %d" % int(settlement.get("prosperity", 50)), Color(0.58, 0.48, 0.20))
	_add_district_card(districts, "Shipyard", "Hull repair, combat kits", "Hull %d%%" % int(_ship_condition.get("hull", 100)), Color(0.25, 0.44, 0.48))
	_add_district_card(districts, "Governor", "Faction work and access", "%s %s" % [String(location.get("faction", "Independent")), _signed_int_text(int(_faction_reputation.get(String(location.get("faction", "Independent")), 0)))], Color(0.38, 0.30, 0.50))
	_add_district_card(districts, "Jobs", "Contracts and local incidents", "%d active" % _active_contracts.size(), Color(0.26, 0.42, 0.30))
	_add_district_card(districts, "Local Lead", _local_incident_report(location), "Use incident button", Color(0.34, 0.26, 0.18))
	_add_interaction_notice_card()


func _build_tavern_screen(settlement: Dictionary) -> void:
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Tavern and Crew Hall", "Lanterns, wet coats and informants crowd the tables. Rest, hire and rumor actions change sailing speed and route knowledge.", Color(0.22, 0.12, 0.06)))
	_add_stat_bar(_interaction_content, "Crew Morale", int(_ship_condition.get("morale", 58)), 100, Color(0.74, 0.55, 0.24))
	_interaction_content.add_child(_crew_card("Sailors", int(_ship_condition.get("sailors", 42)), _crew_cap("sailors"), "Speed / Boarding", Color(0.52, 0.70, 0.86)))
	_interaction_content.add_child(_crew_card("Gunners", int(_ship_condition.get("gunners", 18)), _crew_cap("gunners"), "Reload / Broadside", Color(0.86, 0.62, 0.34)))
	_interaction_content.add_child(_crew_card("Carpenters", int(_ship_condition.get("carpenters", 6)), _crew_cap("carpenters"), "Repair / Flooding", Color(0.58, 0.82, 0.54)))
	_interaction_content.add_child(_visual_summary_panel("Local Read", "Hire cost: %d silver\nProsperity: %s\nAccess: %s" % [
		_hire_crew_cost(),
		String(settlement.get("prosperity_label", "steady")),
		String(settlement.get("access_label", "open")),
	], Color(0.16, 0.10, 0.06)))
	_add_interaction_notice_card()


func _build_market_screen(market: Dictionary) -> void:
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Market and Customs Yard", "Buy voyage supplies, sell captured cargo, and turn combat loot into future survival.", Color(0.20, 0.15, 0.06)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(grid)
	_add_inventory_slot(grid, "Timber", int(_cargo_hold.get("timber", 0)), Color(0.55, 0.34, 0.18), _market_good_price_text(market, "timber"))
	_add_inventory_slot(grid, "Canvas", int(_cargo_hold.get("canvas", 0)), Color(0.80, 0.74, 0.58), _market_good_price_text(market, "canvas"))
	_add_inventory_slot(grid, "Powder", int(_cargo_hold.get("powder", 0)), Color(0.25, 0.25, 0.25), _market_good_price_text(market, "powder"))
	_add_inventory_slot(grid, "Contraband", int(_cargo_hold.get("contraband", 0)), Color(0.45, 0.16, 0.12), _market_good_price_text(market, "contraband"))
	_add_inventory_slot(grid, "Parts", int(_cargo_hold.get("cannon_parts", 0)), Color(0.54, 0.58, 0.62), _market_good_price_text(market, "cannon_parts"))
	_add_inventory_slot(grid, "Silver", int(_cargo_hold.get("silver", 0)), Color(0.78, 0.78, 0.68), "purse")
	_add_stat_bar(_interaction_content, "Prosperity", int(market.get("prosperity", 50)), 100, Color(0.72, 0.62, 0.30))
	_add_stat_bar(_interaction_content, "Security", int(market.get("security", 50)), 100, Color(0.44, 0.68, 0.74))
	_add_interaction_notice_card()


func _build_shipyard_screen() -> void:
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Shipyard and Powder Slip", "Hull, repair kits and stored materials carry directly into the next naval battle.", Color(0.08, 0.18, 0.20)))
	_add_stat_bar(_interaction_content, "Hull Condition", int(_ship_condition.get("hull", 100)), 100, Color(0.58, 0.82, 0.54))
	_add_stat_bar(_interaction_content, "Repair Kits", int(_ship_condition.get("repair_supplies", 3)), 3, Color(0.70, 0.92, 1.0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(grid)
	_add_inventory_slot(grid, "Timber", int(_cargo_hold.get("timber", 0)), Color(0.55, 0.34, 0.18), "repair beams")
	_add_inventory_slot(grid, "Canvas", int(_cargo_hold.get("canvas", 0)), Color(0.80, 0.74, 0.58), "sail cloth")
	_add_inventory_slot(grid, "Powder", int(_cargo_hold.get("powder", 0)), Color(0.25, 0.25, 0.25), "kit charges")
	_add_interaction_notice_card()


func _build_governor_screen(location: Dictionary) -> void:
	_begin_visual_interaction()
	var faction := String(location.get("faction", "Independent"))
	var relation := int(_faction_reputation.get(faction, 0))
	var faction_color: Color = location.get("color", Color.WHITE)
	_interaction_content.add_child(_visual_summary_panel("Governor's Office", "Maps, seals and hostile ledgers turn contracts into faction access, pressure and patrol behavior.", Color(0.16, 0.10, 0.20)))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(stats)
	_add_metric_card(stats, "Relation", _relation_to_bar_value(relation), "%s (%d)" % [_reputation_label(relation), relation], Color(0.62, 0.50, 0.86))
	_add_metric_card(stats, "Sea Power", int(_faction_power.get(faction, 45)), faction, faction_color)
	_add_metric_card(stats, "Renown", clampi(_captain_renown * 8, 0, 100), "%d" % _captain_renown, Color(1.0, 0.78, 0.36))
	_interaction_content.add_child(_visual_summary_panel("Local Incident", _local_incident_report(location), Color(0.12, 0.10, 0.08)))
	_add_interaction_notice_card()


func _build_jobs_screen() -> void:
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Contract Board", "Wanted notices, sealed dispatches and convoy reports become visible campaign targets.", Color(0.08, 0.16, 0.12)))
	_interaction_content.add_child(_visual_summary_panel("Active Work", _job_board_report(), Color(0.10, 0.12, 0.08)))
	_interaction_content.add_child(_visual_summary_panel("Local Lead", _local_incident_report(get_selected_region()), Color(0.13, 0.10, 0.06)))
	_add_interaction_notice_card()


func _show_settlement_interaction(location: Dictionary) -> void:
	var settlement := _get_settlement_state(location)
	_apply_interaction_theme(Color(0.030, 0.025, 0.018), location.get("color", Color.WHITE))
	_apply_interaction_layout(true)
	_interaction_title.text = String(location.get("name", "Harbor"))
	_build_settlement_hub_screen(location, settlement)
	_set_interaction_buttons(["menu_tavern", "menu_market", "menu_shipyard", "menu_governor", "menu_jobs", "take_local_incident", "track_job", "close_interaction"])
	_show_bottom_panel("Camp")
	_info_panel.visible = false
	_open_interaction_panel()


func _show_tavern_interaction() -> void:
	var location := get_selected_region()
	var settlement := _get_settlement_state(location)
	_apply_interaction_theme(Color(0.060, 0.035, 0.020), Color(1.0, 0.78, 0.42))
	_apply_interaction_layout(true)
	_interaction_title.text = "%s Tavern" % String(location.get("name", "Harbor"))
	_build_tavern_screen(settlement)
	_set_interaction_buttons(["rest", "hire_crew", "ask_news", "menu_settlement", "close_interaction"])


func _show_market_interaction() -> void:
	var market := _get_market_snapshot()
	_apply_interaction_theme(Color(0.045, 0.036, 0.018), Color(1.0, 0.86, 0.38))
	_apply_interaction_layout(true)
	_interaction_title.text = "%s Market" % String(market.get("location", "Harbor"))
	_build_market_screen(market)
	_set_interaction_buttons(["buy_timber", "buy_canvas", "buy_powder", "sell_contraband", "sell_cannon_parts", "menu_settlement", "close_interaction"])


func _show_shipyard_interaction() -> void:
	var location := get_selected_region()
	_apply_interaction_theme(Color(0.028, 0.040, 0.044), Color(0.70, 0.92, 1.0))
	_apply_interaction_layout(true)
	_interaction_title.text = "%s Shipyard" % String(location.get("name", "Harbor"))
	_build_shipyard_screen()
	_set_interaction_buttons(["repair", "resupply", "menu_settlement", "close_interaction"])


func _show_governor_interaction() -> void:
	var location := get_selected_region()
	_apply_interaction_theme(Color(0.040, 0.032, 0.048), location.get("color", Color.WHITE))
	_apply_interaction_layout(true)
	_interaction_title.text = "%s Governor" % String(location.get("name", "Harbor"))
	_build_governor_screen(location)
	_set_interaction_buttons(["take_job", "take_local_incident", "track_job", "menu_settlement", "close_interaction"])


func _show_jobs_interaction() -> void:
	_apply_interaction_theme(Color(0.026, 0.033, 0.030), Color(0.78, 1.0, 0.74))
	_apply_interaction_layout(true)
	_interaction_title.text = "Harbor Jobs"
	_build_jobs_screen()
	_set_interaction_buttons(["take_job", "take_local_incident", "track_job", "ask_news", "menu_settlement", "close_interaction"])


func _show_fleet_interaction(index: int) -> void:
	if index < 0 or index >= _parties.size():
		return
	_selected_party_index = index
	var party: Dictionary = _parties[index]
	var relation_state := _get_party_relation_state(party)
	_apply_interaction_theme(Color(0.020, 0.030, 0.038), party.get("color", Color.WHITE))
	_interaction_title.text = String(party.get("name", "Fleet"))
	_interaction_body.text = _fleet_encounter_dashboard(party, relation_state) + _interaction_notice_text()
	_set_interaction_buttons(["hail_party", "inspect_party", "engage_party", "close_interaction"])
	_show_bottom_panel("Reports")
	_info_panel.visible = false
	_open_interaction_panel()


func _show_region_operation(region: Dictionary) -> void:
	_apply_interaction_theme(Color(0.026, 0.030, 0.036), region.get("color", Color.WHITE))
	_interaction_title.text = "%s Operations" % String(region.get("name", "Waters"))
	_interaction_body.text = "%s\n\nRegion read\n%s\n\nRegional effects\n%s\n\nActive order\n%s\n\nOperation choices\nScout Waters: creates a sea opportunity marker inside this region.\nPatrol Contact: selects the best moving fleet in/near this region and plots intercept.\nRaid Waters: launches a direct regional naval encounter, higher risk but immediate pressure play.\n\nStrategic effect\nWinning raids or marked patrol battles reduces sea power; scouting builds cargo/crew routes before you commit." % [
		_district_header("Regional Operation", String(region.get("mood", "Open waters")), "This is the Warband-style sea-region decision layer: choose reconnaissance, contact, or a direct raid instead of blindly entering combat."),
		_warfront_region_state_line(region),
		_regional_effect_report(region),
		_active_region_operation_line(region),
	]
	_set_interaction_buttons(["region_scout", "region_patrol", "region_raid", "open_reports_panel", "close_interaction"])
	_show_bottom_panel("Factions")
	_info_panel.visible = false
	_open_interaction_panel()


func _set_interaction_buttons(visible_actions: Array) -> void:
	for key in _interaction_buttons.keys():
		var button := _interaction_buttons[key] as Button
		var action := String(key)
		button.visible = visible_actions.has(action)
		if button.visible:
			button.text = _interaction_button_label(action)
			button.disabled = _interaction_button_disabled(action)
		else:
			button.disabled = false
	if _interaction_scroll != null:
		_interaction_scroll.scroll_vertical = 0


func _interaction_button_label(action: String) -> String:
	match action:
		"repair":
			var hull := int(_ship_condition.get("hull", 100))
			var missing := 100 - hull
			var timber_cost := maxi(1, int(ceil(float(missing) / 18.0)))
			var canvas_cost := maxi(1, int(ceil(float(missing) / 30.0)))
			return "Repair Hull  %dT/%dC" % [timber_cost, canvas_cost] if hull < 100 else "Repair Hull  Full"
		"resupply":
			var kits := int(_ship_condition.get("repair_supplies", 3))
			return "Resupply Kits  %d Powder" % ((3 - kits) * 2) if kits < 3 else "Resupply Kits  Full"
		"rest":
			return "Rest Crew  Pay Wages"
		"hire_crew":
			return "Hire Crew  %d Silver" % _hire_crew_cost()
		"ask_news":
			return "Ask News  4 Silver"
		"buy_timber":
			return _market_button_label("Buy Timber", "timber", true)
		"buy_canvas":
			return _market_button_label("Buy Canvas", "canvas", true)
		"buy_powder":
			return _market_button_label("Buy Powder", "powder", true)
		"sell_contraband":
			return _market_button_label("Sell Contraband", "contraband", false)
		"sell_cannon_parts":
			return _market_button_label("Sell Parts", "cannon_parts", false)
		"take_job":
			return "Take Job  %d/3" % _active_contracts.size()
		"take_local_incident":
			return _local_incident_button_label()
		"track_job":
			return "Track Job  %s" % ("Ready" if not _active_contracts.is_empty() else "None")
	return _default_interaction_button_label(action)


func _interaction_button_disabled(action: String) -> bool:
	match action:
		"repair":
			var hull := int(_ship_condition.get("hull", 100))
			if hull >= 100:
				return true
			var missing := 100 - hull
			return int(_cargo_hold.get("timber", 0)) < maxi(1, int(ceil(float(missing) / 18.0))) or int(_cargo_hold.get("canvas", 0)) < maxi(1, int(ceil(float(missing) / 30.0)))
		"resupply":
			var kits := int(_ship_condition.get("repair_supplies", 3))
			return kits >= 3 or int(_cargo_hold.get("powder", 0)) < (3 - kits) * 2
		"hire_crew":
			return int(_cargo_hold.get("silver", 0)) < _hire_crew_cost() or _crew_is_full()
		"ask_news":
			return int(_cargo_hold.get("silver", 0)) < 4
		"buy_timber":
			return _buy_disabled("timber")
		"buy_canvas":
			return _buy_disabled("canvas")
		"buy_powder":
			return _buy_disabled("powder")
		"sell_contraband":
			return int(_cargo_hold.get("contraband", 0)) <= 0
		"sell_cannon_parts":
			return int(_cargo_hold.get("cannon_parts", 0)) <= 0
		"take_job":
			return _active_contracts.size() >= 3
		"take_local_incident":
			return _local_incident_button_disabled()
		"track_job":
			return _active_contracts.is_empty()
		"take_all_reward", "take_half_reward":
			return _pending_opportunity_reward.is_empty()
		"take_cargo_reward":
			var cargo: Dictionary = _pending_opportunity_reward.get("cargo", {})
			return _pending_opportunity_reward.is_empty() or cargo.is_empty()
		"take_crew_reward":
			var ship: Dictionary = _pending_opportunity_reward.get("ship", {})
			return _pending_opportunity_reward.is_empty() or ship.is_empty()
		"leave_reward":
			return _pending_opportunity_reward.is_empty()
	return false


func _default_interaction_button_label(action: String) -> String:
	match action:
		"menu_tavern":
			return "Tavern"
		"menu_market":
			return "Market"
		"menu_shipyard":
			return "Shipyard"
		"menu_governor":
			return "Governor"
		"menu_jobs":
			return "Jobs"
		"menu_settlement":
			return "Back"
		"hail_party":
			return "Hail Fleet"
		"inspect_party":
			return "Trade/Inspect"
		"engage_party":
			return "Engage Fleet"
		"launch_battle":
			return "Launch Battle"
		"region_scout":
			return "Scout Waters"
		"region_patrol":
			return "Patrol Contact"
		"region_raid":
			return "Raid Waters"
		"open_inventory_report":
			return "Open Inventory"
		"open_reports_panel":
			return "Open Notes"
		"open_factions_panel":
			return "Open Notes"
		"continue_campaign":
			return "Continue Sailing"
		"investigate_opportunity":
			return "Investigate"
		"take_all_reward":
			return "Take All"
		"take_half_reward":
			return "Take Half"
		"take_cargo_reward":
			return "Take Cargo"
		"take_crew_reward":
			return "Take Crew"
		"leave_reward":
			return "Leave"
		"take_local_incident":
			return "Accept Local Incident"
		"close_interaction":
			return "Close"
	return action.capitalize()


func _market_button_label(label: String, good: String, buying: bool) -> String:
	var market := _get_market_snapshot()
	var prices: Dictionary = market.get("buy_prices", {}) if buying else market.get("sell_prices", {})
	var amount := 2 if buying else 1
	var price := int(prices.get(good, 0)) * amount
	var stock := int(_cargo_hold.get(good, 0))
	return "%s  %d Silver  Stock %d" % [label, price, stock]


func _buy_disabled(good: String) -> bool:
	var market := _get_market_snapshot()
	var buy_prices: Dictionary = market.get("buy_prices", {})
	return int(_cargo_hold.get("silver", 0)) < int(buy_prices.get(good, 0)) * 2


func _crew_is_full() -> bool:
	for kind in ["sailors", "gunners", "carpenters"]:
		if int(_ship_condition.get(kind, 0)) < _crew_cap(kind):
			return false
	return true


func _hide_interaction_panel() -> void:
	if _interaction_panel != null:
		_interaction_panel.visible = false
	_set_campaign_hud_suppressed(false)


func _open_interaction_panel() -> void:
	if _interaction_scroll != null:
		_interaction_scroll.scroll_vertical = 0
	if _interaction_panel != null:
		_interaction_panel.visible = true
	_set_campaign_hud_suppressed(true)


func _set_campaign_hud_suppressed(suppressed: bool) -> void:
	if _hud_suppressed == suppressed:
		return
	_hud_suppressed = suppressed
	var normal_visible := not suppressed
	if _selected_panel != null:
		_selected_panel.visible = normal_visible
	if _ship_ledger_panel != null:
		_ship_ledger_panel.visible = normal_visible
	if _course_panel != null:
		_course_panel.visible = normal_visible
	if _world_events_panel != null:
		_world_events_panel.visible = false
	if _warfront_panel != null:
		_warfront_panel.visible = false
	if _captains_desk_panel != null:
		_captains_desk_panel.visible = false
	if _map_legend_panel != null:
		_map_legend_panel.visible = false


func _interaction_notice_text() -> String:
	if _interaction_notice.is_empty():
		return ""
	return "\n\nResult: %s" % _interaction_notice


func _set_interaction_notice_from_log() -> void:
	if _encounter_log.is_empty():
		return
	_interaction_notice = String(_encounter_log[0])


func _refresh_interaction_after_action(action: String) -> void:
	if _is_fleet_interaction_action(action):
		if _selected_party_index >= 0 and _selected_party_index < _parties.size():
			_show_fleet_interaction(_selected_party_index)
		else:
			_hide_interaction_panel()
			_show_bottom_panel("Reports")
	elif action == "buy_timber" or action == "buy_canvas" or action == "buy_powder" or action == "sell_contraband" or action == "sell_cannon_parts":
		_show_market_interaction()
	elif action == "repair" or action == "resupply":
		_show_shipyard_interaction()
	elif action == "rest" or action == "hire_crew" or action == "ask_news":
		_show_tavern_interaction()
	elif action == "take_job" or action == "take_local_incident" or action == "track_job":
		_show_jobs_interaction()
	else:
		_show_settlement_interaction(get_selected_region())


func _is_fleet_interaction_action(action: String) -> bool:
	return action == "hail_party" or action == "inspect_party" or action == "engage_party"


func _is_port_ledger_action(action: String) -> bool:
	return action in [
		"repair",
		"resupply",
		"rest",
		"buy_timber",
		"buy_canvas",
		"buy_powder",
		"sell_contraband",
		"sell_cannon_parts",
		"hire_crew",
		"take_job",
		"take_local_incident",
		"track_job",
		"ask_news",
	]


func _campaign_ledger_snapshot() -> Dictionary:
	return {
		"cargo": _cargo_hold.duplicate(true),
		"ship": _ship_condition.duplicate(true),
		"contracts": _active_contracts.size(),
		"completed": _completed_contracts.size(),
		"opportunities": _sea_opportunities.size(),
		"day": _campaign_day,
		"target": _player_target,
		"renown": _captain_renown,
	}


func _show_port_action_report(action: String, before: Dictionary) -> void:
	var result := _interaction_notice
	var diff := _ledger_diff_text(before)
	var next := _ledger_next_step(action)
	var title := _ledger_action_title(action)
	_apply_interaction_theme(Color(0.038, 0.030, 0.020), Color(1.0, 0.82, 0.42))
	_interaction_title.text = title
	_interaction_body.text = "%s\n\nResult\n%s\n\nLedger change\n%s\n\nNext move\n%s" % [
		_district_header("Captain's Ledger", "The harbor clerk updates your ship books.", "Port choices now resolve into visible cargo, crew, repair, route or contract consequences before you sail again."),
		result if not result.is_empty() else "No major change recorded.",
		diff,
		next,
	]
	match action:
		"repair", "resupply":
			_set_interaction_buttons(["menu_shipyard", "open_inventory_report", "continue_campaign"])
		"buy_timber", "buy_canvas", "buy_powder", "sell_contraband", "sell_cannon_parts":
			_set_interaction_buttons(["menu_market", "open_inventory_report", "continue_campaign"])
		"rest", "hire_crew", "ask_news":
			_set_interaction_buttons(["menu_tavern", "open_reports_panel", "continue_campaign"])
		"take_job", "take_local_incident", "track_job":
			_set_interaction_buttons(["menu_jobs", "open_reports_panel", "continue_campaign"])
		_:
			_set_interaction_buttons(["menu_settlement", "continue_campaign"])


func _ledger_diff_text(before: Dictionary) -> String:
	var lines: Array[String] = []
	var cargo_before: Dictionary = before.get("cargo", {})
	for key in ["silver", "timber", "canvas", "powder", "cannon_parts", "contraband"]:
		var old_value := int(cargo_before.get(key, 0))
		var new_value := int(_cargo_hold.get(key, 0))
		if old_value != new_value:
			lines.append("- %s: %d -> %d (%s)" % [String(key).capitalize(), old_value, new_value, _signed_int_text(new_value - old_value)])
	var ship_before: Dictionary = before.get("ship", {})
	for key in ["hull", "repair_supplies", "morale", "sailors", "gunners", "carpenters"]:
		var old_ship := int(ship_before.get(key, 0))
		var new_ship := int(_ship_condition.get(key, 0))
		if old_ship != new_ship:
			lines.append("- %s: %d -> %d (%s)" % [String(key).capitalize(), old_ship, new_ship, _signed_int_text(new_ship - old_ship)])
	var old_contracts := int(before.get("contracts", 0))
	if old_contracts != _active_contracts.size():
		lines.append("- Active contracts: %d -> %d" % [old_contracts, _active_contracts.size()])
	var old_completed := int(before.get("completed", 0))
	if old_completed != _completed_contracts.size():
		lines.append("- Completed contracts: %d -> %d" % [old_completed, _completed_contracts.size()])
	var old_opportunities := int(before.get("opportunities", 0))
	if old_opportunities != _sea_opportunities.size():
		lines.append("- Sea chances: %d -> %d" % [old_opportunities, _sea_opportunities.size()])
	var old_day := float(before.get("day", _campaign_day))
	if absf(_campaign_day - old_day) > 0.001:
		lines.append("- Time passed: %.2f days" % (_campaign_day - old_day))
	var old_target: Vector2 = before.get("target", _player_target)
	if old_target.distance_to(_player_target) > 0.001:
		lines.append("- Course plotted: %s" % _campaign_target_label())
	if lines.is_empty():
		return "- No resource delta; check the result note for why."
	return "\n".join(lines)


func _ledger_next_step(action: String) -> String:
	match action:
		"repair":
			return "Hull is ready for combat. Resupply kits if powder allows, then choose a fleet or route."
		"resupply":
			return "Repair kits carry into naval combat. Leave port when the next target is worth the risk."
		"rest":
			return "Morale is higher but time advanced. Check Reports for moving fleets before sailing."
		"hire_crew":
			return "Crew capacity improved. Harder fights and boarding attempts are now safer."
		"ask_news":
			return "A lead was added to the map/report flow. Track or intercept the highlighted fleet."
		"take_job":
			return "The job is now active. Use Track Job or follow Captain's Orders on the map."
		"take_local_incident":
			return "A local incident now has a visible route, contract or sea marker. Follow the highlighted map objective."
		"track_job":
			return "Course is plotted to the active job. Sail until Enter opens the target encounter."
		"buy_timber", "buy_canvas", "buy_powder":
			return "Supplies are in cargo. Visit Shipyard if you bought them for repairs or kits."
		"sell_contraband", "sell_cannon_parts":
			return "Silver increased. Spend it on crew, supplies or safer port preparation."
	return "Return to the harbor district or continue sailing."


func _ledger_action_title(action: String) -> String:
	match action:
		"repair":
			return "Hull Repaired"
		"resupply":
			return "Repair Kits Restocked"
		"rest":
			return "Crew Rested"
		"hire_crew":
			return "Crew Hired"
		"ask_news":
			return "News Purchased"
		"take_job":
			return "Contract Accepted"
		"take_local_incident":
			return "Local Incident Accepted"
		"track_job":
			return "Job Tracked"
		"buy_timber", "buy_canvas", "buy_powder":
			return "Cargo Purchased"
		"sell_contraband", "sell_cannon_parts":
			return "Cargo Sold"
	return "Harbor Action"


func _prepare_after_action_report(party: Dictionary, outcome: String, loot: Dictionary, reputation_delta: Dictionary, power_delta: int, contract_result: Dictionary) -> void:
	var party_name := String(party.get("name", "Fleet"))
	_pending_after_action_title = "%s %s" % [party_name, outcome.capitalize()]
	_pending_after_action_report = "%s\n\nSpoils transferred to cargo\n%s\n\nMap consequence\n%s\n\nPolitical consequence\n%s\nSea power: %s %s\n\nShip and crew state\nHull: %d%%\nRepair kits: %d/3\nMorale: %d\nSilver: %d\n\n%s\n\nRecommended course\n%s\n\nNext move\nOpen Inventory to inspect cargo, Open Notes to see reports/factions, or Continue Sailing to return to the campaign map." % [
		_district_header("After Action Report", "The smoke clears and prize crews count what can be saved.", "Combat now feeds back into the campaign: cargo, reputation, contracts, sea power and future port pressure change here."),
		_loot_report_text(loot),
		_after_action_map_consequence(party, outcome),
		_reputation_delta_text(reputation_delta),
		String(party.get("faction", "Unknown")),
		_signed_int_text(power_delta),
		int(_ship_condition.get("hull", 100)),
		int(_ship_condition.get("repair_supplies", 3)),
		int(_ship_condition.get("morale", 58)),
		int(_cargo_hold.get("silver", 0)),
		_contract_result_text(contract_result),
		_after_action_recommended_course(contract_result),
	]


func _show_pending_after_action_report() -> void:
	if not visible or _pending_after_action_report.is_empty():
		return
	_apply_interaction_theme(Color(0.045, 0.030, 0.018), Color(1.0, 0.78, 0.34))
	_interaction_title.text = _pending_after_action_title
	_interaction_body.text = _pending_after_action_report
	_set_interaction_buttons(["open_inventory_report", "open_reports_panel", "continue_campaign"])
	_info_panel.visible = false
	_open_interaction_panel()
	_pending_after_action_report = ""
	_pending_after_action_title = ""


func _loot_report_text(loot: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["silver", "timber", "canvas", "powder", "cannon_parts", "contraband"]:
		var value := int(loot.get(key, 0))
		if value > 0:
			lines.append("- %s +%d" % [String(key).capitalize(), value])
	if lines.is_empty():
		return "- No useful cargo recovered"
	return "\n".join(lines)


func _signed_int_text(value: int) -> String:
	if value >= 0:
		return "+%d" % value
	return "%d" % value


func _contract_result_text(contract_result: Dictionary) -> String:
	if contract_result.is_empty():
		return "Contract outcome\n- No active hunt contract completed"
	var local_line := "\n- Local settlement consequence applied" if not String(contract_result.get("local_origin", "")).is_empty() else ""
	return "Contract outcome\n- Completed: %s\n- Reward: +%d silver\n- Issuer trust: +2%s" % [
		String(contract_result.get("target", "Fleet")),
		int(contract_result.get("reward", 0)),
		local_line,
	]


func _after_action_map_consequence(party: Dictionary, outcome: String) -> String:
	var faction := String(party.get("faction", "Independent"))
	var pressure := _region_pressure_for_faction(faction)
	if bool(party.get("regional_operation", false)):
		return "- %s raid resolved as %s\n- %s sea power reduced; pressure now reads %d/100\n- Warfront and Factions refresh after you continue" % [
			String(party.get("operation_region", "Regional")),
			outcome,
			faction,
			pressure,
		]
	return "- %s removed from moving fleet map\n- Outcome recorded as %s in Reports\n- %s pressure now reads %d/100\n- World Events and Captain's Course refresh after you continue" % [
		String(party.get("name", "Fleet")),
		outcome,
		faction,
		pressure,
	]


func _after_action_recommended_course(contract_result: Dictionary) -> String:
	if not contract_result.is_empty():
		return "Contract completed. Open Inventory or Factions, then return to a friendly port to repair, sell cargo and take another job."
	var hull := int(_ship_condition.get("hull", 100))
	var kits := int(_ship_condition.get("repair_supplies", 3))
	var morale := int(_ship_condition.get("morale", 58))
	if hull < 55:
		return "Hull is worn. Plot course to the nearest port and repair before chasing another fleet."
	if kits <= 0:
		return "Repair kits are empty. Visit a shipyard and resupply before the next fight."
	if morale < 35:
		return "Crew morale is low. Rest at a tavern before long pressure routes."
	if _active_contracts.is_empty():
		return "No active contract remains. Enter a port and use Jobs to take a new target."
	return "Track the remaining active contract or inspect nearby fleets for a better prize."


func _run_interaction_action(action: String) -> void:
	match action:
		"menu_settlement":
			_show_settlement_interaction(get_selected_region())
			return
		"menu_tavern":
			_show_tavern_interaction()
			return
		"menu_market":
			_show_market_interaction()
			return
		"menu_shipyard":
			_show_shipyard_interaction()
			return
		"menu_governor":
			_show_governor_interaction()
			return
		"menu_jobs":
			_show_jobs_interaction()
			return
		"open_inventory_report":
			_hide_interaction_panel()
			_show_bottom_panel("Inventory")
			return
		"open_reports_panel":
			_hide_interaction_panel()
			_show_bottom_panel("Notes")
			return
		"open_factions_panel":
			_hide_interaction_panel()
			_show_bottom_panel("Notes")
			return
		"continue_campaign":
			_hide_interaction_panel()
			return
		"launch_battle":
			_launch_selected_party_battle()
			return
		"region_scout":
			_accept_region_scout()
			return
		"region_patrol":
			_accept_region_patrol()
			return
		"region_raid":
			_launch_region_raid()
			return
		"investigate_opportunity":
			if _prepare_selected_opportunity_reward():
				_show_pending_opportunity_reward_screen()
			return
		"take_all_reward", "take_half_reward", "take_cargo_reward", "take_crew_reward", "leave_reward":
			if _resolve_pending_opportunity_reward(action):
				_show_opportunity_resolution_report()
			return
	var ledger_before := _campaign_ledger_snapshot() if _is_port_ledger_action(action) else {}
	var changed := perform_port_service(action)
	_set_interaction_notice_from_log()
	if _is_fleet_interaction_action(action) and _interaction_panel.visible and _interaction_title.text == "Battle Briefing":
		return
	if action == "engage_party":
		return
	if not _interaction_panel.visible:
		return
	if changed and _is_port_ledger_action(action):
		_show_port_action_report(action, ledger_before)
	elif changed or not _interaction_notice.is_empty():
		_refresh_interaction_after_action(action)


func _position_world_labels() -> void:
	if _map_canvas == null:
		return
	var map_size := _get_map_size()
	for i in range(_location_labels.size()):
		var location: Dictionary = _locations[i]
		var pos: Vector2 = location.get("position", Vector2.ZERO) * map_size
		var label := _location_labels[i]
		label.position = pos + Vector2(-90.0, 12.0)
		label.size = Vector2(180.0, 24.0)
	for i in range(_party_labels.size()):
		var party: Dictionary = _parties[i]
		var pos: Vector2 = party.get("position", Vector2.ZERO) * map_size
		var label := _party_labels[i]
		var is_focus := i == _selected_party_index or i == _nearby_encounter_index or is_contract_target(String(party.get("name", "")))
		label.visible = is_focus
		label.position = pos + Vector2(-92.0, 12.0)
		label.size = Vector2(184.0, 30.0)
		label.add_theme_font_size_override("font_size", 14 if is_focus else 12)


func _remove_party_by_name(party_name: String) -> void:
	for i in range(_parties.size() - 1, -1, -1):
		var party: Dictionary = _parties[i]
		if String(party.get("name", "")) != party_name:
			continue
		_parties.remove_at(i)
		if i < _party_labels.size():
			var label := _party_labels[i]
			_party_labels.remove_at(i)
			if is_instance_valid(label):
				label.queue_free()
		break


func _build_loot_for_party(party: Dictionary, outcome: String) -> Dictionary:
	var role_key := String(party.get("role", "Fleet")).to_lower()
	var strength := int(party.get("strength", 40))
	var captured_bonus := 1.35 if outcome == "captured" else 1.0
	var loot := {
		"timber": maxi(2, int(round(float(strength) / 28.0 * captured_bonus))),
		"canvas": maxi(1, int(round(float(strength) / 42.0 * captured_bonus))),
		"powder": maxi(1, int(round(float(strength) / 36.0 * captured_bonus))),
		"cannon_parts": 1 if strength >= 70 else 0,
		"silver": 0,
		"contraband": 0,
	}
	if role_key.contains("treasure"):
		loot["silver"] = maxi(20, int(round(float(strength) * 1.8 * captured_bonus)))
		loot["powder"] = int(loot["powder"]) + 2
	elif role_key.contains("merchant"):
		loot["silver"] = maxi(8, int(round(float(strength) * 0.8 * captured_bonus)))
		loot["contraband"] = int(loot["contraband"]) + 3
	elif role_key.contains("courier"):
		loot["silver"] = maxi(6, int(round(float(strength) * 0.45 * captured_bonus)))
		loot["contraband"] = int(loot["contraband"]) + 1
	elif role_key.contains("raider") or role_key.contains("bounty"):
		loot["contraband"] = int(loot["contraband"]) + maxi(2, int(round(float(strength) / 30.0)))
		loot["cannon_parts"] = int(loot["cannon_parts"]) + 1
	return loot


func _apply_campaign_loot(loot: Dictionary) -> void:
	for key in loot.keys():
		var cargo_key := String(key)
		_cargo_hold[cargo_key] = int(_cargo_hold.get(cargo_key, 0)) + int(loot.get(key, 0))


func _can_use_port_services() -> bool:
	var location := get_selected_region()
	var kind := String(location.get("kind", "port"))
	return (kind == "port" or kind == "fort") and _is_location_enterable(location)


func _get_settlement_state(location: Dictionary) -> Dictionary:
	var kind := String(location.get("kind", "port"))
	var faction := String(location.get("faction", "Independent"))
	var reputation := int(_faction_reputation.get(faction, 0))
	var pressure := _region_pressure_for_faction(faction)
	var fort_bonus := 12 if kind == "fort" else 0
	var port_bonus := 8 if kind == "port" else 0
	var modifier := _get_settlement_modifier(String(location.get("id", "")))
	var security := clampi(62 + int(round(float(reputation) * 0.45)) - int(round(float(pressure) * 0.28)) + fort_bonus + int(modifier.get("security", 0)), 8, 100)
	var prosperity := clampi(54 + int(round(float(reputation) * 0.30)) - int(round(float(pressure) * 0.18)) + port_bonus + int(modifier.get("prosperity", 0)), 8, 100)
	var access_closed := reputation <= -45 and security >= 42
	var access_label := _settlement_access_label(reputation, security, access_closed)
	return {
		"faction": faction,
		"reputation": reputation,
		"pressure": pressure,
		"security": security,
		"prosperity": prosperity,
		"security_modifier": int(modifier.get("security", 0)),
		"prosperity_modifier": int(modifier.get("prosperity", 0)),
		"last_change": String(modifier.get("last_change", "")),
		"access_closed": access_closed,
		"access_label": access_label,
		"security_label": _settlement_security_label(security),
		"prosperity_label": _settlement_prosperity_label(prosperity),
	}


func _is_service_blocked_by_settlement(service: String) -> bool:
	var settlement := _get_settlement_state(get_selected_region())
	if not bool(settlement.get("access_closed", false)):
		return false
	if service == "ask_news" and int(settlement.get("security", 50)) < 58:
		return false
	if service == "take_local_incident":
		return false
	_encounter_log.push_front("%s harbor is closed to your flag" % String(get_selected_region().get("name", "Harbor")))
	return true


func _get_settlement_modifier(location_id: String) -> Dictionary:
	if location_id.is_empty():
		return {"security": 0, "prosperity": 0, "last_change": ""}
	if not _settlement_modifiers.has(location_id):
		_settlement_modifiers[location_id] = {"security": 0, "prosperity": 0, "last_change": ""}
	return (_settlement_modifiers[location_id] as Dictionary)


func _adjust_settlement_modifier(location_id: String, security_delta: int, prosperity_delta: int, reason: String) -> String:
	if location_id.is_empty():
		return ""
	var modifier := _get_settlement_modifier(location_id)
	modifier["security"] = clampi(int(modifier.get("security", 0)) + security_delta, -28, 28)
	modifier["prosperity"] = clampi(int(modifier.get("prosperity", 0)) + prosperity_delta, -28, 28)
	var location := _find_location_by_id(location_id)
	var name := String(location.get("name", location_id))
	var security_text := _signed_int_text(security_delta)
	var prosperity_text := _signed_int_text(prosperity_delta)
	var line := "%s: security %s, prosperity %s - %s" % [name, security_text, prosperity_text, reason]
	modifier["last_change"] = line
	_settlement_modifiers[location_id] = modifier
	_political_log.push_front(line)
	if _political_log.size() > 8:
		_political_log.resize(8)
	return line


func _settlement_modifier_report(settlement: Dictionary) -> String:
	var security_modifier := int(settlement.get("security_modifier", 0))
	var prosperity_modifier := int(settlement.get("prosperity_modifier", 0))
	var last_change := String(settlement.get("last_change", ""))
	if security_modifier == 0 and prosperity_modifier == 0:
		return "Local consequence\nNo lasting local changes yet."
	var line := "Local consequence\nSecurity modifier: %s   Prosperity modifier: %s" % [
		_signed_int_text(security_modifier),
		_signed_int_text(prosperity_modifier),
	]
	if not last_change.is_empty():
		line += "\nLast change: %s" % last_change
	return line


func _settlement_access_label(reputation: int, security: int, closed: bool) -> String:
	if closed:
		return "closed"
	if reputation >= 35:
		return "welcoming"
	if reputation <= -25:
		return "hostile watch"
	if security <= 28:
		return "black market"
	return "open"


func _settlement_security_label(value: int) -> String:
	if value >= 75:
		return "guarded"
	if value >= 48:
		return "watched"
	if value >= 25:
		return "restless"
	return "lawless"


func _settlement_prosperity_label(value: int) -> String:
	if value >= 75:
		return "prosperous"
	if value >= 48:
		return "steady"
	if value >= 25:
		return "strained"
	return "poor"


func _service_repair_hull() -> bool:
	var hull := int(_ship_condition.get("hull", 100))
	if hull >= 100:
		_encounter_log.push_front("Hull already sound at 100%")
		return false
	var missing := 100 - hull
	var timber_cost := maxi(1, int(ceil(float(missing) / 18.0)))
	var canvas_cost := maxi(1, int(ceil(float(missing) / 30.0)))
	if int(_cargo_hold.get("timber", 0)) < timber_cost or int(_cargo_hold.get("canvas", 0)) < canvas_cost:
		_encounter_log.push_front("Not enough timber/canvas for hull repair")
		return false
	_cargo_hold["timber"] = int(_cargo_hold.get("timber", 0)) - timber_cost
	_cargo_hold["canvas"] = int(_cargo_hold.get("canvas", 0)) - canvas_cost
	_ship_condition["hull"] = 100
	_campaign_day += 0.35
	_encounter_log.push_front("Hull repaired to 100%%; spent %d timber, %d canvas" % [timber_cost, canvas_cost])
	return true


func _service_resupply() -> bool:
	var supplies := int(_ship_condition.get("repair_supplies", 3))
	if supplies >= 3:
		_encounter_log.push_front("Repair kits already full at 3/3")
		return false
	var needed := 3 - supplies
	var powder_cost := needed * 2
	if int(_cargo_hold.get("powder", 0)) < powder_cost:
		_encounter_log.push_front("Not enough powder barrels for repair kits")
		return false
	_cargo_hold["powder"] = int(_cargo_hold.get("powder", 0)) - powder_cost
	_ship_condition["repair_supplies"] = 3
	_campaign_day += 0.12
	_encounter_log.push_front("Repair kits restocked to 3/3; powder now %d" % int(_cargo_hold.get("powder", 0)))
	return true


func _service_rest() -> bool:
	var morale := int(_ship_condition.get("morale", 58))
	var rest_gain := 18 if morale < 35 else 12
	_ship_condition["morale"] = clampi(morale + rest_gain, 0, 100)
	_campaign_day = floor(_campaign_day) + 1.25
	_update_daily_wages()
	_encounter_log.push_front("Crew rested until morning; morale %d -> %d" % [morale, int(_ship_condition.get("morale", 58))])
	return true


func _service_buy_good(good: String, amount: int) -> bool:
	var market := _get_market_snapshot()
	var buy_prices: Dictionary = market.get("buy_prices", {})
	var price := int(buy_prices.get(good, 0)) * amount
	if price <= 0:
		return false
	if int(_cargo_hold.get("silver", 0)) < price:
		_encounter_log.push_front("Not enough silver to buy %s" % good)
		return false
	_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) - price
	_cargo_hold[good] = int(_cargo_hold.get(good, 0)) + amount
	_campaign_day += 0.04
	_encounter_log.push_front("Bought %d %s for %d silver; stock %d, silver %d" % [amount, good, price, int(_cargo_hold.get(good, 0)), int(_cargo_hold.get("silver", 0))])
	return true


func _service_sell_good(good: String, amount: int) -> bool:
	var held := int(_cargo_hold.get(good, 0))
	if held < amount:
		_encounter_log.push_front("No %s to sell" % good)
		return false
	var market := _get_market_snapshot()
	var sell_prices: Dictionary = market.get("sell_prices", {})
	var price := int(sell_prices.get(good, 0)) * amount
	if price <= 0:
		return false
	_cargo_hold[good] = held - amount
	_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) + price
	_campaign_day += 0.04
	_encounter_log.push_front("Sold %d %s for %d silver; stock %d, silver %d" % [amount, good, price, int(_cargo_hold.get(good, 0)), int(_cargo_hold.get("silver", 0))])
	return true


func _service_hire_crew() -> bool:
	var hire_cost := _hire_crew_cost()
	if int(_cargo_hold.get("silver", 0)) < hire_cost:
		_encounter_log.push_front("Not enough silver to hire crew")
		return false
	for kind in ["sailors", "gunners", "carpenters"]:
		var current := int(_ship_condition.get(kind, 0))
		var cap := _crew_cap(kind)
		if current >= cap:
			continue
		_ship_condition[kind] = current + 1
		_ship_condition["morale"] = clampi(int(_ship_condition.get("morale", 58)) + 1, 0, 100)
		_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) - hire_cost
		_encounter_log.push_front("Hired 1 %s for %d silver; crew now %d/%d" % [kind, hire_cost, int(_ship_condition.get(kind, 0)), _crew_cap(kind)])
		return true
	_encounter_log.push_front("Crew is already at capacity")
	return false


func _hire_crew_cost() -> int:
	var location := get_selected_region()
	var faction := String(location.get("faction", "Independent"))
	var reputation := int(_faction_reputation.get(faction, 0))
	return clampi(10 - int(round(float(reputation) / 12.0)), 6, 16)


func _service_take_contract() -> bool:
	if _active_contracts.size() >= 3:
		_encounter_log.push_front("Contract log is full")
		return false
	var location := get_selected_region()
	var faction := String(location.get("faction", "Independent"))
	_contract_sequence += 1
	if _contract_sequence % 2 == 0:
		return _service_take_delivery_contract(location, faction)
	var target := _find_contract_target(faction)
	if target.is_empty():
		_encounter_log.push_front("No suitable contract target nearby")
		return false
	var reward := _contract_reward_for_target(target, faction)
	_active_contracts.append({
		"type": "hunt",
		"issuer": String(location.get("name", "Harbor")),
		"faction": faction,
		"target": String(target.get("name", "Fleet")),
		"target_faction": String(target.get("faction", "Unknown")),
		"reward": reward,
		"status": "active",
	})
	_encounter_log.push_front("Contract accepted: hunt %s for %d silver" % [String(target.get("name", "Fleet")), reward])
	_player_target = target.get("position", _player_target)
	return true


func _service_take_delivery_contract(location: Dictionary, faction: String) -> bool:
	var destination := _find_delivery_destination(String(location.get("id", "")), faction)
	if destination.is_empty():
		_encounter_log.push_front("No delivery destination available")
		return false
	var reward := 18 + int(_player_position.distance_to(destination.get("position", _player_position)) * 80.0) + maxi(0, -int(_faction_reputation.get(faction, 0)) / 5)
	_active_contracts.append({
		"type": "delivery",
		"issuer": String(location.get("name", "Harbor")),
		"faction": faction,
		"target": String(destination.get("name", "Port")),
		"target_id": String(destination.get("id", "")),
		"reward": reward,
		"status": "active",
	})
	_player_target = destination.get("position", _player_target)
	_encounter_log.push_front("Contract accepted: deliver dispatches to %s for %d silver" % [String(destination.get("name", "Port")), reward])
	return true


func _service_take_local_incident() -> bool:
	var location := get_selected_region()
	var existing_contract := _local_incident_contract(location)
	if not existing_contract.is_empty():
		return _track_contract(existing_contract)
	var existing_opportunity_index := _local_incident_opportunity_index(location)
	if existing_opportunity_index >= 0:
		_select_opportunity_index(existing_opportunity_index)
		_encounter_log.push_front("Tracking local incident: %s" % String(_sea_opportunities[existing_opportunity_index].get("name", "Sea chance")))
		return true

	var incident := _local_incident_snapshot(location)
	var incident_type := String(incident.get("type", "opportunity"))
	if incident_type != "opportunity" and _active_contracts.size() >= 3:
		_encounter_log.push_front("Contract log is full; clear a job before taking local work")
		return false

	if incident_type == "hunt":
		var target: Dictionary = incident.get("target_party", {})
		if target.is_empty():
			return false
		_active_contracts.append({
			"type": "hunt",
			"issuer": String(location.get("name", "Harbor")),
			"faction": String(location.get("faction", "Independent")),
			"target": String(target.get("name", "Fleet")),
			"target_faction": String(target.get("faction", "Unknown")),
			"reward": int(incident.get("reward", 24)),
			"status": "active",
			"local_origin": String(location.get("id", "")),
			"local_title": String(incident.get("title", "Local bounty")),
		})
		_player_target = target.get("position", _player_target)
		_selected_party_index = _party_index_by_name(String(target.get("name", "")))
		_encounter_log.push_front("Local incident accepted: %s" % String(incident.get("title", "Local bounty")))
	elif incident_type == "delivery":
		var destination: Dictionary = incident.get("destination", {})
		if destination.is_empty():
			return false
		_active_contracts.append({
			"type": "delivery",
			"issuer": String(location.get("name", "Harbor")),
			"faction": String(location.get("faction", "Independent")),
			"target": String(destination.get("name", "Port")),
			"target_id": String(destination.get("id", "")),
			"reward": int(incident.get("reward", 20)),
			"status": "active",
			"local_origin": String(location.get("id", "")),
			"local_title": String(incident.get("title", "Local dispatch")),
		})
		_player_target = destination.get("position", _player_target)
		_selected_party_index = -1
		_encounter_log.push_front("Local incident accepted: %s" % String(incident.get("title", "Local dispatch")))
	else:
		var opportunity := {
			"id": _local_incident_id(location),
			"name": String(incident.get("title", "Local sea lead")),
			"type": String(incident.get("opportunity_type", "mystery")),
			"position": _local_incident_position(location),
			"risk": String(incident.get("risk", "medium")),
			"reward": String(incident.get("reward_text", "supplies or silver")),
			"description": String(incident.get("description", "A local lead points to something waiting offshore.")),
			"local_origin": String(location.get("id", "")),
		}
		_sea_opportunities.append(opportunity)
		_selected_opportunity_index = _sea_opportunities.size() - 1
		_player_target = opportunity.get("position", _player_target)
		_encounter_log.push_front("Local sea lead marked: %s" % String(opportunity.get("name", "Sea chance")))

	_campaign_day += 0.05
	if _map_canvas:
		_map_canvas.queue_redraw()
	return true


func _service_track_contract() -> bool:
	for contract in _active_contracts:
		if String(contract.get("status", "active")) != "active":
			continue
		if _track_contract(contract):
			return true
	_encounter_log.push_front("No active contract target to track")
	return false


func _track_contract(contract: Dictionary) -> bool:
	if String(contract.get("type", "hunt")) == "delivery":
		var destination := _find_location_by_id(String(contract.get("target_id", "")))
		if destination.is_empty():
			return false
		_player_target = destination.get("position", _player_target)
		_selected_party_index = -1
		_encounter_log.push_front("Tracking delivery: %s" % String(destination.get("name", "Port")))
		if _map_canvas:
			_map_canvas.queue_redraw()
		return true
	var target := _find_party_by_name(String(contract.get("target", "")))
	if target.is_empty():
		return false
	_player_target = target.get("position", _player_target)
	_selected_party_index = _party_index_by_name(String(target.get("name", "")))
	_encounter_log.push_front("Tracking contract target: %s" % String(target.get("name", "Fleet")))
	if _map_canvas:
		_map_canvas.queue_redraw()
	return true


func _service_ask_news() -> bool:
	var location := get_selected_region()
	var settlement := _get_settlement_state(location)
	var cost := clampi(6 - int(round(float(int(settlement.get("prosperity", 50))) / 28.0)), 2, 6)
	if int(_cargo_hold.get("silver", 0)) < cost:
		_encounter_log.push_front("Not enough silver to ask around the tavern")
		return false
	var target := _find_rumor_target(String(location.get("faction", "Independent")))
	if target.is_empty():
		_encounter_log.push_front("No useful sea news in this port")
		return false
	_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) - cost
	_campaign_day += 0.08
	_player_target = target.get("position", _player_target)
	_selected_party_index = _party_index_by_name(String(target.get("name", "")))
	var distance := _player_position.distance_to(target.get("position", _player_position)) * 12.0
	_encounter_log.push_front("Tavern news: %s sighted %.1f days away" % [String(target.get("name", "Fleet")), distance])
	if _map_canvas:
		_map_canvas.queue_redraw()
	return true


func _find_rumor_target(local_faction: String) -> Dictionary:
	var best_score := -99999.0
	var best_party := {}
	for party in _parties:
		var faction := String(party.get("faction", "Independent"))
		var stance := String(party.get("stance", "neutral"))
		var distance := _player_position.distance_to(party.get("position", _player_position))
		var reputation := int(_faction_reputation.get(faction, 0))
		var score := float(int(party.get("strength", 0))) - distance * 80.0
		if faction != local_faction:
			score += 12.0
		if stance == "chase":
			score += 26.0
		elif stance == "flee":
			score += 8.0
		score += float(maxi(0, -reputation)) * 0.35
		if is_contract_target(String(party.get("name", ""))):
			score += 18.0
		if score <= best_score:
			continue
		best_score = score
		best_party = party.duplicate(true)
	return best_party


func _contract_reward_for_target(target: Dictionary, issuer_faction: String) -> int:
	var base := maxi(18, int(round(float(target.get("strength", 40)) / 2.0)) + 12)
	var target_faction := String(target.get("faction", "Independent"))
	var target_rep := int(_faction_reputation.get(target_faction, 0))
	var danger_bonus := maxi(0, -target_rep / 4)
	var renown_bonus := int(round(float(_captain_renown) / 6.0))
	var rival_bonus := 8 if target_faction != issuer_faction else 0
	return base + danger_bonus + renown_bonus + rival_bonus


func _find_contract_target(issuer_faction: String) -> Dictionary:
	for party in _parties:
		if is_contract_target(String(party.get("name", ""))):
			continue
		var faction := String(party.get("faction", "Independent"))
		var stance := String(party.get("stance", "neutral"))
		if faction != issuer_faction and (stance == "chase" or int(party.get("strength", 0)) >= 70):
			return party.duplicate(true)
	return {}


func _find_delivery_destination(origin_id: String, issuer_faction: String) -> Dictionary:
	var best_score := -9999.0
	var best := {}
	for location in _locations:
		var kind := String(location.get("kind", "port"))
		if kind != "port" and kind != "fort":
			continue
		if String(location.get("id", "")) == origin_id:
			continue
		var distance := _player_position.distance_to(location.get("position", _player_position))
		var faction := String(location.get("faction", "Independent"))
		var score := distance * 100.0
		if faction != issuer_faction:
			score += 14.0
		if score <= best_score:
			continue
		best_score = score
		best = location.duplicate(true)
	return best


func _find_location_by_id(location_id: String) -> Dictionary:
	for location in _locations:
		if String(location.get("id", "")) == location_id:
			return location.duplicate(true)
	return {}


func _find_party_by_name(party_name: String) -> Dictionary:
	for party in _parties:
		if String(party.get("name", "")) == party_name:
			return party.duplicate(true)
	return {}


func _party_index_by_name(party_name: String) -> int:
	for i in range(_parties.size()):
		var party: Dictionary = _parties[i]
		if String(party.get("name", "")) == party_name:
			return i
	return -1


func _resolve_contract_for_party(party_name: String) -> Dictionary:
	for i in range(_active_contracts.size()):
		var contract: Dictionary = _active_contracts[i]
		if String(contract.get("target", "")) != party_name or String(contract.get("status", "active")) != "active":
			continue
		var reward := int(contract.get("reward", 0))
		var issuer_faction := String(contract.get("faction", "Independent"))
		_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) + reward
		_captain_renown += 1
		_faction_reputation[issuer_faction] = clampi(int(_faction_reputation.get(issuer_faction, 0)) + 2, -100, 100)
		_update_discovery_state()
		var local_change := _apply_local_contract_settlement_result(contract, "")
		contract["status"] = "completed"
		_completed_contracts.push_front(contract.duplicate(true))
		_active_contracts.remove_at(i)
		if _completed_contracts.size() > 6:
			_completed_contracts.resize(6)
		_encounter_log.push_front("Contract completed: %s +%d silver, %s trust +2" % [party_name, reward, issuer_faction])
		if not local_change.is_empty():
			_encounter_log.push_front(local_change)
		return contract.duplicate(true)
	return {}


func _resolve_delivery_contracts_for_location(location: Dictionary) -> void:
	var location_id := String(location.get("id", ""))
	for i in range(_active_contracts.size() - 1, -1, -1):
		var contract: Dictionary = _active_contracts[i]
		if String(contract.get("type", "hunt")) != "delivery":
			continue
		if String(contract.get("target_id", "")) != location_id:
			continue
		var reward := int(contract.get("reward", 0))
		var issuer_faction := String(contract.get("faction", "Independent"))
		_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) + reward
		_faction_reputation[issuer_faction] = clampi(int(_faction_reputation.get(issuer_faction, 0)) + 1, -100, 100)
		_captain_renown += 1
		var local_change := _apply_local_contract_settlement_result(contract, location_id)
		contract["status"] = "completed"
		_completed_contracts.push_front(contract.duplicate(true))
		_active_contracts.remove_at(i)
		_encounter_log.push_front("Delivery completed at %s: +%d silver" % [String(location.get("name", "Port")), reward])
		if not local_change.is_empty():
			_encounter_log.push_front(local_change)
	if _completed_contracts.size() > 6:
		_completed_contracts.resize(6)


func _apply_local_contract_settlement_result(contract: Dictionary, completion_location_id: String) -> String:
	var origin_id := String(contract.get("local_origin", ""))
	if origin_id.is_empty():
		return ""
	var title := String(contract.get("local_title", "local incident"))
	if String(contract.get("type", "hunt")) == "delivery":
		var origin_line := _adjust_settlement_modifier(origin_id, 1, 6, "%s completed" % title)
		if not completion_location_id.is_empty() and completion_location_id != origin_id:
			_adjust_settlement_modifier(completion_location_id, 0, 3, "delivery traffic from %s" % String(_find_location_by_id(origin_id).get("name", "another port")))
		return origin_line
	return _adjust_settlement_modifier(origin_id, 8, 2, "%s resolved" % title)


func _has_delivery_contract_for_location(location: Dictionary) -> bool:
	var location_id := String(location.get("id", ""))
	for contract in _active_contracts:
		if String(contract.get("type", "hunt")) == "delivery" and String(contract.get("target_id", "")) == location_id:
			return true
	return false


func _try_enter_selected_opportunity() -> bool:
	if _selected_opportunity_index < 0 or _selected_opportunity_index >= _sea_opportunities.size():
		return false
	var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
	if not can_enter_selected_opportunity():
		_player_target = opportunity.get("position", _player_target)
		_encounter_log.push_front("Sailing toward %s" % String(opportunity.get("name", "sea opportunity")))
		_show_bottom_panel("Map")
		if _map_canvas:
			_map_canvas.queue_redraw()
		_update_course_panel()
		return true
	_show_opportunity_interaction(_selected_opportunity_index)
	return true


func _show_opportunity_interaction(index: int) -> void:
	if index < 0 or index >= _sea_opportunities.size():
		return
	_selected_opportunity_index = index
	var opportunity: Dictionary = _sea_opportunities[index]
	var color := _opportunity_color(String(opportunity.get("type", "salvage")))
	_apply_interaction_theme(Color(0.020, 0.038, 0.040), color)
	_interaction_title.text = String(opportunity.get("name", "Sea Opportunity"))
	_interaction_body.text = ("%s\n\nRisk: %s\nLikely reward: %s\nDistance: %.1f days\n\nDecision\nInvestigate opens a recovery screen first; you choose all, half, cargo-only, crew-only or leave the find.\nLeave closes the screen; the marker remains on the map." % [
		_district_header("Sea Opportunity", String(opportunity.get("description", "Something waits in the water.")), "These are campaign-map encounters outside ports and fleets: visible reasons to sail, risk, and return with material consequences."),
		String(opportunity.get("risk", "unknown")),
		String(opportunity.get("reward", "unknown")),
		_player_position.distance_to(opportunity.get("position", _player_position)) * 12.0,
	]) + _interaction_notice_text()
	_set_interaction_buttons(["investigate_opportunity", "close_interaction"])
	_show_bottom_panel("Map")
	_info_panel.visible = false
	_open_interaction_panel()


func _resolve_selected_opportunity() -> bool:
	if not _prepare_selected_opportunity_reward():
		return false
	_show_pending_opportunity_reward_screen()
	return true


func _prepare_selected_opportunity_reward() -> bool:
	if _selected_opportunity_index < 0 or _selected_opportunity_index >= _sea_opportunities.size():
		_encounter_log.push_front("Select a sea opportunity first")
		return false
	var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
	_pending_opportunity_reward = _build_opportunity_reward(opportunity)
	_pending_opportunity_reward["opportunity_index"] = _selected_opportunity_index
	_pending_opportunity_reward["opportunity"] = opportunity.duplicate(true)
	return true


func _build_opportunity_reward(opportunity: Dictionary) -> Dictionary:
	var kind := String(opportunity.get("type", "salvage"))
	var cargo := {}
	var ship := {}
	var time_cost := 0.0
	var summary := ""
	match kind:
		"salvage":
			cargo = {"timber": 4, "canvas": 2, "cannon_parts": 1}
			summary = "The wreck can be stripped for repair stores and gun scrap."
		"rescue":
			ship = {"sailors": 3, "morale": 6}
			time_cost = 0.12
			summary = "Survivors can join the company, but the rescue costs daylight."
		"mystery":
			cargo = {"silver": 24, "contraband": 1}
			ship = {"morale": -3}
			summary = "The smoke hides valuables, black-market goods and an ugly story."
		_:
			cargo = {"silver": 10}
			summary = "The crew recovers a small purse of useful supplies."
	return {
		"kind": kind,
		"cargo": cargo,
		"ship": ship,
		"time": time_cost,
		"summary": summary,
		"mode": "",
		"applied_text": "",
	}


func _show_pending_opportunity_reward_screen() -> void:
	if _pending_opportunity_reward.is_empty():
		return
	var opportunity: Dictionary = _pending_opportunity_reward.get("opportunity", {})
	_apply_interaction_theme(Color(0.030, 0.032, 0.024), _opportunity_color(String(opportunity.get("type", "salvage"))))
	_apply_interaction_layout(true)
	_interaction_title.text = "Recovery Party"
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel(
		String(opportunity.get("name", "Sea Opportunity")),
		"%s\nRisk: %s\nDecision: choose what the crew brings aboard instead of silently changing inventory." % [
			String(_pending_opportunity_reward.get("summary", "The crew found something useful.")),
			String(opportunity.get("risk", "unknown")),
		],
		Color(0.12, 0.09, 0.06)
	))
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(layout)
	var cargo_column := _add_visual_column(layout, "Found Cargo", Color(0.17, 0.115, 0.070), 300.0)
	_add_reward_inventory_slots(cargo_column, _pending_opportunity_reward.get("cargo", {}))
	var ship_column := _add_visual_column(layout, "Crew Effect", Color(0.17, 0.12, 0.08), 300.0)
	_add_reward_ship_effects(ship_column, _pending_opportunity_reward.get("ship", {}), float(_pending_opportunity_reward.get("time", 0.0)))
	var choice_column := _add_visual_column(layout, "Captain's Choice", Color(0.20, 0.15, 0.09), 300.0)
	choice_column.add_child(_visual_summary_panel("Take All", _reward_preview_text("take_all_reward"), Color(0.12, 0.09, 0.055)))
	choice_column.add_child(_visual_summary_panel("Take Half", _reward_preview_text("take_half_reward"), Color(0.12, 0.09, 0.055)))
	choice_column.add_child(_visual_summary_panel("Filtered Take", "Take Cargo keeps physical loot only.\nTake Crew keeps manpower/morale effects only.\nLeave abandons the find and removes the marker.", Color(0.12, 0.09, 0.055)))
	_set_interaction_buttons(["take_all_reward", "take_half_reward", "take_cargo_reward", "take_crew_reward", "leave_reward", "close_interaction"])
	_info_panel.visible = false
	_open_interaction_panel()


func _add_reward_inventory_slots(parent: Control, cargo: Dictionary) -> void:
	if cargo.is_empty():
		parent.add_child(_visual_summary_panel("No Cargo", "Nothing physical to load from this find.", Color(0.10, 0.075, 0.045)))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for key in cargo.keys():
		var name := _cargo_display_name(String(key))
		_add_inventory_slot(grid, name, int(cargo.get(key, 0)), _cargo_color(String(key)), _cargo_reward_tag(String(key)))


func _add_reward_ship_effects(parent: Control, ship: Dictionary, time_cost: float) -> void:
	if ship.is_empty() and time_cost <= 0.0:
		parent.add_child(_visual_summary_panel("No Crew Effect", "This opportunity only affects cargo.", Color(0.10, 0.075, 0.045)))
		return
	if ship.has("sailors"):
		parent.add_child(_crew_card("Sailors", int(_ship_condition.get("sailors", 42)) + int(ship.get("sailors", 0)), _crew_cap("sailors"), "%s sailors" % _signed_int_text(int(ship.get("sailors", 0))), Color(0.52, 0.70, 0.86)))
	if ship.has("gunners"):
		parent.add_child(_crew_card("Gunners", int(_ship_condition.get("gunners", 18)) + int(ship.get("gunners", 0)), _crew_cap("gunners"), "%s gunners" % _signed_int_text(int(ship.get("gunners", 0))), Color(0.86, 0.62, 0.34)))
	if ship.has("carpenters"):
		parent.add_child(_crew_card("Carpenters", int(_ship_condition.get("carpenters", 6)) + int(ship.get("carpenters", 0)), _crew_cap("carpenters"), "%s carpenters" % _signed_int_text(int(ship.get("carpenters", 0))), Color(0.58, 0.82, 0.54)))
	if ship.has("morale"):
		_add_stat_bar(parent, "Morale Change", int(_ship_condition.get("morale", 58)) + int(ship.get("morale", 0)), 100, Color(0.95, 0.78, 0.36))
	if time_cost > 0.0:
		parent.add_child(_visual_summary_panel("Time Cost", "%.2f campaign days pass while the boats work." % time_cost, Color(0.10, 0.075, 0.045)))


func _resolve_pending_opportunity_reward(action: String) -> bool:
	if _pending_opportunity_reward.is_empty():
		_encounter_log.push_front("No pending recovery choice")
		return false
	var opportunity_index := int(_pending_opportunity_reward.get("opportunity_index", -1))
	if opportunity_index < 0 or opportunity_index >= _sea_opportunities.size():
		_pending_opportunity_reward = {}
		_encounter_log.push_front("The sea opportunity is no longer available")
		return false
	var reward := _filtered_opportunity_reward(_pending_opportunity_reward, action)
	var applied_text := _apply_opportunity_reward(reward)
	var opportunity: Dictionary = _pending_opportunity_reward.get("opportunity", {})
	var local_text := _apply_opportunity_local_effect(opportunity, reward)
	if not local_text.is_empty():
		applied_text += "\n%s" % local_text
	var operation_result := _resolve_active_region_operation_for_opportunity(opportunity, applied_text)
	if not operation_result.is_empty():
		applied_text += "\n%s" % String(operation_result.get("summary", "Regional operation updated"))
	_sea_opportunities.remove_at(opportunity_index)
	_selected_opportunity_index = -1
	_pending_opportunity_reward["mode"] = action
	_pending_opportunity_reward["applied_text"] = applied_text
	_interaction_notice = applied_text
	_encounter_log.push_front(applied_text)
	if _encounter_log.size() > 8:
		_encounter_log.resize(8)
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()
	_update_date_label()
	return true


func _filtered_opportunity_reward(reward: Dictionary, action: String) -> Dictionary:
	var filtered := {
		"cargo": {},
		"ship": {},
		"time": 0.0,
	}
	if action == "leave_reward":
		return filtered
	var cargo: Dictionary = reward.get("cargo", {})
	var ship: Dictionary = reward.get("ship", {})
	if action == "take_all_reward" or action == "take_cargo_reward" or action == "take_half_reward":
		filtered["cargo"] = _scaled_int_dictionary(cargo, 0.5 if action == "take_half_reward" else 1.0)
	if action == "take_all_reward" or action == "take_crew_reward" or action == "take_half_reward":
		filtered["ship"] = _scaled_int_dictionary(ship, 0.5 if action == "take_half_reward" else 1.0)
		filtered["time"] = float(reward.get("time", 0.0)) * (0.5 if action == "take_half_reward" else 1.0)
	return filtered


func _scaled_int_dictionary(values: Dictionary, factor: float) -> Dictionary:
	var output := {}
	for key in values.keys():
		var value := int(values.get(key, 0))
		if value == 0:
			continue
		var scaled := int(ceil(absf(float(value)) * factor)) * (1 if value > 0 else -1)
		output[key] = scaled
	return output


func _apply_opportunity_reward(reward: Dictionary) -> String:
	var lines: Array[String] = []
	var cargo: Dictionary = reward.get("cargo", {})
	for key in cargo.keys():
		var cargo_key := String(key)
		var value := int(cargo.get(key, 0))
		if value == 0:
			continue
		_cargo_hold[cargo_key] = int(_cargo_hold.get(cargo_key, 0)) + value
		lines.append("%s %s" % [_cargo_display_name(cargo_key), _signed_int_text(value)])
	var ship: Dictionary = reward.get("ship", {})
	for key in ship.keys():
		var ship_key := String(key)
		var value := int(ship.get(key, 0))
		if value == 0:
			continue
		var cap := _crew_cap(ship_key)
		if ship_key == "morale":
			cap = 100
		_ship_condition[ship_key] = clampi(int(_ship_condition.get(ship_key, 0)) + value, 0, cap)
		lines.append("%s %s" % [ship_key.capitalize(), _signed_int_text(value)])
	var time_cost := float(reward.get("time", 0.0))
	if time_cost > 0.0:
		_campaign_day += time_cost
		lines.append("Time %.2f days" % time_cost)
	if lines.is_empty():
		return "Recovery abandoned: nothing brought aboard"
	return "Recovered: %s" % ", ".join(lines)


func _apply_opportunity_local_effect(opportunity: Dictionary, reward: Dictionary) -> String:
	var local_origin := String(opportunity.get("local_origin", ""))
	if local_origin.is_empty():
		return ""
	var cargo: Dictionary = reward.get("cargo", {})
	var ship: Dictionary = reward.get("ship", {})
	if cargo.is_empty() and ship.is_empty():
		return ""
	var kind := String(opportunity.get("type", "salvage"))
	var security_delta := 1 if kind == "rescue" and ship.has("sailors") else 0
	var prosperity_delta := 3 if not cargo.is_empty() else 1
	return _adjust_settlement_modifier(local_origin, security_delta, prosperity_delta, "%s resolved offshore" % String(opportunity.get("name", "Local lead")))


func _show_opportunity_resolution_report() -> void:
	_apply_interaction_theme(Color(0.035, 0.044, 0.032), Color(0.82, 1.0, 0.72))
	_apply_interaction_layout(true)
	_interaction_title.text = "Recovery Resolved"
	_begin_visual_interaction()
	_interaction_content.add_child(_visual_summary_panel("Result", _interaction_notice, Color(0.12, 0.09, 0.055)))
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_content.add_child(layout)
	var cargo_column := _add_visual_column(layout, "Cargo Hold Now", Color(0.17, 0.115, 0.070), 330.0)
	var cargo_grid := GridContainer.new()
	cargo_grid.columns = 2
	cargo_grid.add_theme_constant_override("h_separation", 10)
	cargo_grid.add_theme_constant_override("v_separation", 10)
	cargo_column.add_child(cargo_grid)
	_add_inventory_slot(cargo_grid, "Timber", int(_cargo_hold.get("timber", 0)), _cargo_color("timber"), "repair beams")
	_add_inventory_slot(cargo_grid, "Canvas", int(_cargo_hold.get("canvas", 0)), _cargo_color("canvas"), "sail cloth")
	_add_inventory_slot(cargo_grid, "Powder", int(_cargo_hold.get("powder", 0)), _cargo_color("powder"), "kit charges")
	_add_inventory_slot(cargo_grid, "Silver", int(_cargo_hold.get("silver", 0)), _cargo_color("silver"), "purse")
	var crew_column := _add_visual_column(layout, "Crew State", Color(0.17, 0.12, 0.08), 330.0)
	crew_column.add_child(_crew_card("Sailors", int(_ship_condition.get("sailors", 42)), _crew_cap("sailors"), "Speed / Boarding", Color(0.52, 0.70, 0.86)))
	crew_column.add_child(_crew_card("Gunners", int(_ship_condition.get("gunners", 18)), _crew_cap("gunners"), "Reload / Broadside", Color(0.86, 0.62, 0.34)))
	_add_stat_bar(crew_column, "Morale", int(_ship_condition.get("morale", 58)), 100, Color(0.95, 0.78, 0.36))
	_pending_opportunity_reward = {}
	_set_interaction_buttons(["open_inventory_report", "open_reports_panel", "continue_campaign"])


func _reward_preview_text(action: String) -> String:
	if _pending_opportunity_reward.is_empty():
		return "No pending reward."
	var reward := _filtered_opportunity_reward(_pending_opportunity_reward, action)
	var parts: Array[String] = []
	var cargo: Dictionary = reward.get("cargo", {})
	for key in cargo.keys():
		parts.append("%s %s" % [_cargo_display_name(String(key)), _signed_int_text(int(cargo.get(key, 0)))])
	var ship: Dictionary = reward.get("ship", {})
	for key in ship.keys():
		parts.append("%s %s" % [String(key).capitalize(), _signed_int_text(int(ship.get(key, 0)))])
	var time_cost := float(reward.get("time", 0.0))
	if time_cost > 0.0:
		parts.append("%.2f days" % time_cost)
	if parts.is_empty():
		return "No cargo or crew change."
	return "\n".join(parts)


func _cargo_display_name(key: String) -> String:
	match key:
		"timber":
			return "Timber"
		"canvas":
			return "Canvas"
		"powder":
			return "Powder"
		"cannon_parts":
			return "Parts"
		"contraband":
			return "Contraband"
		"silver":
			return "Silver"
	return key.capitalize()


func _cargo_color(key: String) -> Color:
	match key:
		"timber":
			return Color(0.55, 0.34, 0.18)
		"canvas":
			return Color(0.80, 0.74, 0.58)
		"powder":
			return Color(0.25, 0.25, 0.25)
		"cannon_parts":
			return Color(0.54, 0.58, 0.62)
		"contraband":
			return Color(0.45, 0.16, 0.12)
		"silver":
			return Color(0.78, 0.78, 0.68)
	return Color(0.70, 0.65, 0.50)


func _cargo_reward_tag(key: String) -> String:
	match key:
		"timber":
			return "repair beams"
		"canvas":
			return "sail cloth"
		"powder":
			return "kit charges"
		"cannon_parts":
			return "gun scrap"
		"contraband":
			return "black market"
		"silver":
			return "purse"
	return "cargo"


func _get_market_snapshot() -> Dictionary:
	var location := get_selected_region()
	var faction := String(location.get("faction", "Independent"))
	var reputation := int(_faction_reputation.get(faction, 0))
	var kind := String(location.get("kind", "port"))
	var available := _can_use_port_services()
	var state := _get_settlement_state(location)
	var relation_discount := clampf(float(reputation) / 240.0, -0.28, 0.22)
	var fort_markup := 0.12 if kind == "fort" else 0.0
	var unrest_markup := clampf(float(100 - int(state.get("security", 50))) / 260.0, 0.0, 0.30)
	var prosperity_discount := clampf(float(int(state.get("prosperity", 50)) - 50) / 360.0, -0.14, 0.12)
	var buy_multiplier := clampf(1.0 - relation_discount + fort_markup + unrest_markup - prosperity_discount, 0.68, 1.55)
	var sell_multiplier := clampf(0.72 + relation_discount * 0.75 - fort_markup * 0.5 + prosperity_discount * 0.7, 0.42, 1.10)
	var base_prices := {
		"timber": 5,
		"canvas": 6,
		"powder": 7,
		"contraband": 13,
		"cannon_parts": 18,
	}
	var buy_prices := {}
	var sell_prices := {}
	for key in base_prices.keys():
		buy_prices[key] = maxi(1, int(round(float(base_prices[key]) * buy_multiplier)))
		sell_prices[key] = maxi(1, int(round(float(base_prices[key]) * sell_multiplier)))
	return {
		"available": available,
		"location": String(location.get("name", "Open Sea")),
		"faction": faction,
		"reputation": reputation,
		"security": int(state.get("security", 50)),
		"prosperity": int(state.get("prosperity", 50)),
		"access_closed": bool(state.get("access_closed", false)),
		"access_label": String(state.get("access_label", "open")),
		"security_label": String(state.get("security_label", "watched")),
		"prosperity_label": String(state.get("prosperity_label", "steady")),
		"buy_prices": buy_prices,
		"sell_prices": sell_prices,
	}


func _apply_reputation_for_result(party: Dictionary, outcome: String) -> Dictionary:
	var faction := String(party.get("faction", "Independent"))
	var role_key := String(party.get("role", "Fleet")).to_lower()
	var strength := int(party.get("strength", 40))
	var renown_gain := maxi(1, int(round(float(strength) / 35.0)))
	if outcome == "captured":
		renown_gain += 1
	_captain_renown += renown_gain

	var delta := {}
	if faction == "Crown Dominion":
		delta["Crown Dominion"] = -maxi(4, int(round(float(strength) / 18.0)))
		delta["Free Captains"] = 2 + (1 if outcome == "captured" else 0)
		if role_key.contains("treasure"):
			delta["Independent"] = int(delta.get("Independent", 0)) + 1
	elif faction == "Free Captains":
		delta["Free Captains"] = -maxi(3, int(round(float(strength) / 24.0)))
		delta["Crown Dominion"] = 1
	elif faction == "Ironwake Compact":
		delta["Ironwake Compact"] = -maxi(3, int(round(float(strength) / 22.0)))
		delta["Free Captains"] = 1
	elif faction == "Unclaimed":
		delta["Unclaimed"] = -2
		delta["Independent"] = 2
		delta["Free Captains"] = 1
	elif faction == "Uncharted":
		delta["Uncharted"] = -1
		delta["Crown Dominion"] = -1
	else:
		delta[faction] = -2

	for key in delta.keys():
		var rep_key := String(key)
		_faction_reputation[rep_key] = clampi(int(_faction_reputation.get(rep_key, 0)) + int(delta.get(key, 0)), -100, 100)

	_political_log.push_front("%s %s: renown +%d, %s" % [
		String(party.get("name", "Fleet")),
		outcome,
		renown_gain,
		_reputation_delta_text(delta),
	])
	if _political_log.size() > 8:
		_political_log.resize(8)
	return delta


func _apply_faction_power_for_result(party: Dictionary, outcome: String) -> int:
	var faction := String(party.get("faction", "Independent"))
	var strength := int(party.get("strength", 40))
	var loss := maxi(1, int(round(float(strength) / 28.0)))
	if outcome == "captured":
		loss += 1
	_faction_power[faction] = clampi(int(_faction_power.get(faction, 45)) - loss, 0, 100)
	_political_log.push_front("%s sea power %d after losing %s" % [
		faction,
		int(_faction_power.get(faction, 45)),
		String(party.get("name", "Fleet")),
	])
	if _political_log.size() > 8:
		_political_log.resize(8)
	return -loss


func _reputation_delta_text(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta.get(key, 0))
		var sign := "+" if value >= 0 else ""
		parts.append("%s %s%d" % [String(key), sign, value])
	if parts.is_empty():
		return "No reputation change"
	return ", ".join(parts)


func _set_selected_index(index: int) -> void:
	_selected_index = posmod(index, _locations.size())
	_selected_party_index = -1
	_selected_opportunity_index = -1
	_locked_encounter_party_name = ""
	var location: Dictionary = _locations[_selected_index]
	_selected_title.text = String(location.get("name", "Location"))
	_selected_title.add_theme_color_override("font_color", location.get("color", Color.WHITE))
	var lock_text := "\nStatus: Fog locked" if not _is_region_unlocked(location) else ""
	_selected_body.text = "%s\n%s%s\n%s" % [
		String(location.get("faction", "Unknown")),
		String(location.get("mood", "Unknown water")),
		lock_text,
		String(location.get("description", "")),
	]
	if _map_canvas:
		_map_canvas.queue_redraw()


func _handle_map_click(point: Vector2, double_click: bool = false) -> void:
	var opportunity_index := _opportunity_at_point(point)
	if opportunity_index >= 0:
		_select_opportunity_index(opportunity_index)
		if double_click or can_enter_selected_opportunity():
			_try_enter_selected_opportunity()
		return

	var party_index := _party_at_point(point)
	if party_index >= 0:
		_select_party_index(party_index)
		return

	var index := _location_at_point(point)
	if index >= 0:
		_set_selected_index(index)
		var location: Dictionary = _locations[index]
		_player_target = location.get("position", _player_target)
		var kind := String(location.get("kind", "port"))
		var can_open_settlement := (kind == "port" or kind == "fort") and _is_location_enterable(location)
		if double_click or can_open_settlement:
			_try_deploy_selected_region()
	else:
		_hover_index = -1
		_selected_party_index = -1
		_locked_encounter_party_name = ""
		_set_player_target_from_point(point)


func _select_from_point(point: Vector2) -> void:
	_handle_map_click(point, false)


func _set_player_target_from_point(point: Vector2) -> void:
	var map_size := _get_map_size()
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	_player_target = _clamp_map_position(Vector2(point.x / map_size.x, point.y / map_size.y))
	_selected_opportunity_index = -1
	_locked_encounter_party_name = ""
	_map_canvas.queue_redraw()
	_update_course_panel()


func _select_party_index(index: int) -> void:
	if index < 0 or index >= _parties.size():
		return
	_selected_party_index = index
	_selected_opportunity_index = -1
	_interaction_notice = ""
	var party: Dictionary = _parties[index]
	_locked_encounter_party_name = String(party.get("name", ""))
	_player_target = party.get("position", _player_target)
	_hover_party_index = index
	_show_fleet_interaction(index)
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()


func _select_opportunity_index(index: int) -> void:
	if index < 0 or index >= _sea_opportunities.size():
		return
	_selected_opportunity_index = index
	_selected_party_index = -1
	_locked_encounter_party_name = ""
	var opportunity: Dictionary = _sea_opportunities[index]
	_player_target = opportunity.get("position", _player_target)
	_encounter_log.push_front("Course set to %s" % String(opportunity.get("name", "sea opportunity")))
	_show_bottom_panel("Map")
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()


func _try_deploy_selected_region() -> bool:
	if _try_enter_selected_opportunity():
		return true
	if _try_deploy_selected_party():
		return true
	var region := get_selected_region()
	if not _is_region_unlocked(region):
		_encounter_log.push_front("%s is still hidden behind fog" % String(region.get("name", "Unknown waters")))
		_show_bottom_panel("Notes")
		return false
	if not _is_location_enterable(region):
		_player_target = region.get("position", _player_target)
		_show_bottom_panel("Map")
		if _map_canvas:
			_map_canvas.queue_redraw()
		return false
	var kind := String(region.get("kind", "port"))
	if kind == "port" or kind == "fort":
		var completed_delivery := _has_delivery_contract_for_location(region)
		_resolve_delivery_contracts_for_location(region)
		if not completed_delivery:
			_encounter_log.push_front("Entered %s anchorage" % String(region.get("name", "Harbor")))
		_set_interaction_notice_from_log()
		_show_settlement_interaction(region)
		return true
	if kind == "sea":
		_show_region_operation(region)
		return true
	deploy_requested.emit(region)
	return true


func _is_region_unlocked(region: Dictionary) -> bool:
	var id := String(region.get("id", ""))
	if not _discovered_regions.has(id):
		return true
	return bool(_discovered_regions.get(id, false))


func _update_discovery_state() -> void:
	if bool(_discovered_regions.get("pale_meridian", false)):
		return
	if _captain_renown >= 20 or int(_faction_reputation.get("Uncharted", -22)) >= -5:
		_discovered_regions["pale_meridian"] = true
		_encounter_log.push_front("Pale Meridian fog route discovered")


func _try_deploy_selected_party() -> bool:
	if not can_enter_selected_party():
		return false
	_show_fleet_interaction(_selected_party_index)
	return true


func _service_engage_party() -> bool:
	if _selected_party_index < 0 or _selected_party_index >= _parties.size():
		_encounter_log.push_front("Select a fleet first")
		_show_bottom_panel("Reports")
		return false
	if can_enter_selected_party():
		var close_party: Dictionary = _parties[_selected_party_index]
		_show_battle_briefing(close_party)
		return true
	var party: Dictionary = _parties[_selected_party_index]
	_player_target = party.get("position", _player_target)
	_encounter_log.push_front("Course set to intercept %s" % String(party.get("name", "Fleet")))
	if _map_canvas:
		_map_canvas.queue_redraw()
	_show_bottom_panel("Reports")
	return true


func _service_hail_party() -> bool:
	if _selected_party_index < 0 or _selected_party_index >= _parties.size():
		_encounter_log.push_front("Select a fleet to hail")
		_show_bottom_panel("Reports")
		return false
	var party: Dictionary = _parties[_selected_party_index]
	if not can_enter_selected_party():
		_player_target = party.get("position", _player_target)
		_encounter_log.push_front("Closing distance to hail %s" % String(party.get("name", "Fleet")))
		return true
	var relation_state := _get_party_relation_state(party)
	var stance := String(relation_state.get("effective_stance", "neutral"))
	var party_name := String(party.get("name", "Fleet"))
	if stance == "chase":
		_encounter_log.push_front("%s refuses parley and beats to quarters" % party_name)
		return _service_engage_party()
	if stance == "flee":
		_player_target = party.get("position", _player_target)
		_encounter_log.push_front("%s avoids parley; pursuit course plotted" % party_name)
		return true
	_encounter_log.push_front("%s hails back: %s" % [party_name, _rumor_line_for_party(party)])
	_campaign_day += 0.03
	return true


func _service_inspect_party() -> bool:
	if _selected_party_index < 0 or _selected_party_index >= _parties.size():
		_encounter_log.push_front("Select a fleet to inspect")
		return false
	var party: Dictionary = _parties[_selected_party_index]
	if not can_enter_selected_party():
		_player_target = party.get("position", _player_target)
		_encounter_log.push_front("Course set to inspect %s" % String(party.get("name", "Fleet")))
		return true
	var relation_state := _get_party_relation_state(party)
	var player_power := _player_boarding_power()
	var target_power := _party_boarding_resistance(party, relation_state)
	var boarding_read := _boarding_read(player_power, target_power)
	_encounter_log.push_front("Inspection: %s carries %s, strength %d, %s; boarding %s" % [
		String(party.get("name", "Fleet")),
		String(party.get("cargo", "unknown cargo")),
		int(party.get("strength", 0)),
		String(relation_state.get("label", "wary")),
		boarding_read,
	])
	_campaign_day += 0.02
	return true


func _player_boarding_power() -> int:
	return 55 + int(_captain_renown * 1.4) + int(int(_ship_condition.get("morale", 58)) / 3)


func _party_boarding_resistance(party: Dictionary, relation_state: Dictionary) -> int:
	var target_power := int(party.get("strength", 45))
	var stance := String(relation_state.get("effective_stance", "neutral"))
	if stance == "flee":
		target_power -= 14
	if stance == "chase":
		target_power += 12
	return target_power


func _rumor_line_for_party(party: Dictionary) -> String:
	var cargo := String(party.get("cargo", "cargo"))
	var faction := String(party.get("faction", "Independent"))
	var strength := int(party.get("strength", 0))
	if strength >= 75:
		return "%s warships are moving heavy guns through these waters." % faction
	if cargo.contains("silver") or cargo.contains("treasure"):
		return "Treasure cargo has been seen under %s colors." % faction
	return "They carry %s and report shifting patrols ahead." % cargo


func _show_battle_briefing(party: Dictionary) -> void:
	var relation_state := _get_party_relation_state(party)
	var outcome_loot := _build_loot_for_party(party, "defeated")
	var capture_loot := _build_loot_for_party(party, "captured")
	_apply_interaction_theme(Color(0.036, 0.026, 0.022), party.get("color", Color.WHITE))
	_interaction_title.text = "Battle Briefing"
	_interaction_body.text = "%s%s\n\nTarget\n%s\n\nYour readiness\n%s\n\nLikely spoils if defeated\n%s\n\nPrize bonus if captured\n%s\n\nConsequences\n%s\n\nDecision\nLaunch Battle enters naval combat. You can still hail, inspect or close this screen before committing." % [
		_district_header("Engagement Briefing", "The quartermaster lays out powder, hull reports and enemy colors before the order is given.", "This is the campaign-to-combat gate: choose battle knowing stakes, readiness, loot and political risk."),
		_interaction_notice_text(),
		_battle_target_read(party, relation_state),
		_battle_readiness_text(),
		_loot_report_text(outcome_loot),
		_loot_report_text(capture_loot),
		_battle_consequence_text(party),
	]
	_set_interaction_buttons(["launch_battle", "hail_party", "inspect_party", "close_interaction"])


func _accept_region_scout() -> void:
	var region := get_selected_region()
	var marker := {
		"id": "scout_%s_%d" % [String(region.get("id", "waters")), int(_campaign_day * 100.0)],
		"name": "%s Scout Lead" % String(region.get("name", "Waters")),
		"type": "rescue" if _sea_region_pressure(region) >= 65 else "salvage",
		"position": _region_operation_position(region, 0),
		"risk": "high" if _sea_region_pressure(region) >= 70 else "medium",
		"reward": "crew, supplies and regional intelligence",
		"description": "Scouts mark a concrete lead inside %s. Investigating it gives resources and a safer read on these waters." % String(region.get("name", "Waters")),
	}
	_sea_opportunities.append(marker)
	_selected_opportunity_index = _sea_opportunities.size() - 1
	_player_target = marker.get("position", _player_target)
	_campaign_day += 0.04
	_start_region_operation(region, "scout", marker.get("position", _player_target), String(marker.get("name", "Scout lead")), String(marker.get("id", "")))
	_interaction_notice = "Scout lead marked in %s" % String(region.get("name", "Waters"))
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()
	_show_region_operation(region)


func _accept_region_patrol() -> void:
	var region := get_selected_region()
	var target := _best_region_party(region)
	if target.is_empty():
		_interaction_notice = "No moving fleet contact inside %s. Scout first or raid the waters directly." % String(region.get("name", "Waters"))
		_show_region_operation(region)
		return
	_selected_party_index = _party_index_by_name(String(target.get("name", "")))
	_selected_opportunity_index = -1
	_player_target = target.get("position", _player_target)
	_start_region_operation(region, "patrol", target.get("position", _player_target), String(target.get("name", "Fleet contact")), String(target.get("name", "")))
	_interaction_notice = "Patrol contact selected: %s" % String(target.get("name", "Fleet"))
	if _map_canvas:
		_map_canvas.queue_redraw()
	_update_course_panel()
	_show_fleet_interaction(_selected_party_index)


func _launch_region_raid() -> void:
	var region := get_selected_region()
	if not _is_region_unlocked(region):
		_interaction_notice = "%s is still hidden behind fog" % String(region.get("name", "Unknown waters"))
		_show_region_operation(region)
		return
	_start_region_operation(region, "raid", region.get("position", _player_target), "%s defense flotilla" % String(region.get("name", "Waters")), String(region.get("name", "Waters")))
	_hide_interaction_panel()
	deploy_requested.emit(_build_region_operation_encounter(region))


func _launch_selected_party_battle() -> void:
	if _selected_party_index < 0 or _selected_party_index >= _parties.size():
		_encounter_log.push_front("Select a fleet first")
		_show_bottom_panel("Reports")
		return
	var party: Dictionary = _parties[_selected_party_index]
	if not can_enter_selected_party():
		_player_target = party.get("position", _player_target)
		_encounter_log.push_front("Course set to intercept %s" % String(party.get("name", "Fleet")))
		_show_bottom_panel("Reports")
		return
	_hide_interaction_panel()
	deploy_requested.emit(_build_party_encounter_region(party))


func _battle_target_read(party: Dictionary, relation_state: Dictionary) -> String:
	return "%s\nFaction: %s - %s (%d)\nRole: %s\nCargo: %s\nIntent: %s\nStrength: %d" % [
		String(party.get("name", "Fleet")),
		String(relation_state.get("faction", "Independent")),
		String(relation_state.get("label", "Wary")),
		int(relation_state.get("reputation", 0)),
		String(party.get("role", "Fleet")),
		String(party.get("cargo", "unknown")),
		String(party.get("intent", relation_state.get("effective_stance", "sailing route"))),
		int(party.get("strength", 0)),
	]


func _battle_readiness_text() -> String:
	var hull := int(_ship_condition.get("hull", 100))
	var kits := int(_ship_condition.get("repair_supplies", 3))
	var morale := int(_ship_condition.get("morale", 58))
	var warning := "Ready"
	if hull < 45:
		warning = "Hull is dangerous; repair before battle"
	elif kits <= 0:
		warning = "No repair kits; resupply is recommended"
	elif morale < 30:
		warning = "Crew morale is weak; rest or hire crew"
	return "Hull [%s] %d%%\nRepair kits: %d/3\nMorale [%s] %d/100\nRead: %s" % [
		_status_bar(hull),
		hull,
		kits,
		_status_bar(morale),
		morale,
		warning,
	]


func _battle_consequence_text(party: Dictionary) -> String:
	var faction := String(party.get("faction", "Independent"))
	var relation := int(_faction_reputation.get(faction, 0))
	var power := int(_faction_power.get(faction, 45))
	return "Attacking %s will shift reputation from %s (%d) and reduce their sea power from %d if you win. Capturing instead of sinking improves cargo return." % [
		faction,
		_reputation_label(relation),
		relation,
		power,
	]


func _build_party_encounter_region(party: Dictionary) -> Dictionary:
	var faction := String(party.get("faction", "Independent"))
	var role := String(party.get("role", "Fleet"))
	var name := String(party.get("name", "Fleet"))
	return {
		"id": "encounter_%s" % name.to_lower().replace(" ", "_"),
		"name": name,
		"kind": "sea",
		"position": party.get("position", _player_position),
		"faction": faction,
		"color": party.get("color", Color.WHITE),
		"mood": role,
		"intent": String(party.get("intent", "sailing route")),
		"description": "%s encounter. Cargo: %s. Strength: %d." % [
			role,
			String(party.get("cargo", "unknown")),
			int(party.get("strength", 0)),
		],
		"encounter_party": party.duplicate(true),
	}


func _build_region_operation_encounter(region: Dictionary) -> Dictionary:
	var faction := String(region.get("faction", "Independent"))
	var pressure := _sea_region_pressure(region)
	var power := int(_faction_power.get(faction, 45))
	var party := {
		"name": "%s defense flotilla" % String(region.get("name", "Waters")),
		"faction": faction,
		"role": "Regional defense",
		"stance": "chase" if pressure >= 62 else "shadow",
		"cargo": "regional stores",
		"position": region.get("position", _player_position),
		"strength": clampi(38 + int(float(pressure) * 0.55) + int(float(power) * 0.20), 34, 138),
		"color": region.get("color", Color.WHITE),
		"regional_operation": true,
		"operation_region": String(region.get("name", "Waters")),
	}
	return {
		"id": "raid_%s" % String(region.get("id", String(region.get("name", "waters")))).to_lower().replace(" ", "_"),
		"name": "%s Raid" % String(region.get("name", "Waters")),
		"kind": "sea",
		"position": region.get("position", _player_position),
		"faction": faction,
		"color": region.get("color", Color.WHITE),
		"mood": _warfront_control_label(faction, pressure, power),
		"description": "Regional raid in %s. Pressure %d, sea power %d. Expect patrol wings and a harder return route." % [
			String(region.get("name", "Waters")),
			pressure,
			power,
		],
		"operation": "regional_raid",
		"encounter_party": party,
	}


func _best_region_party(region: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -99999.0
	var points: Array = region.get("points", [])
	var faction := String(region.get("faction", "Independent"))
	for party in _parties:
		var position: Vector2 = party.get("position", Vector2.ZERO)
		var in_region := _point_in_polygon(position, points)
		var distance := position.distance_to(region.get("position", _player_position))
		var score := float(int(party.get("strength", 0))) - distance * 90.0
		if in_region:
			score += 60.0
		if String(party.get("faction", "Independent")) == faction:
			score += 18.0
		if score <= best_score:
			continue
		best_score = score
		best = party.duplicate(true)
	return best


func _region_operation_position(region: Dictionary, salt: int) -> Vector2:
	var center: Vector2 = region.get("position", _player_position)
	var offset := Vector2(0.035 + float(salt) * 0.011, -0.030 + float(salt % 2) * 0.052)
	return _clamp_map_position(center + offset)


func _start_region_operation(region: Dictionary, action: String, target_position: Vector2, target_label: String, target_id: String) -> void:
	var faction := String(region.get("faction", "Independent"))
	_active_region_operation = {
		"id": "%s_%s_%d" % [action, String(region.get("id", "waters")), int(_campaign_day * 100.0)],
		"action": action,
		"region_id": String(region.get("id", "")),
		"region_name": String(region.get("name", "Waters")),
		"faction": faction,
		"target_position": target_position,
		"target_label": target_label,
		"target_id": target_id,
		"day": int(floor(_campaign_day)),
		"pressure_start": _sea_region_pressure(region),
		"power_start": int(_faction_power.get(faction, 45)),
		"status": "active",
	}
	_encounter_log.push_front("Regional order: %s %s" % [_region_operation_action_label(action), String(region.get("name", "Waters"))])
	if _encounter_log.size() > 8:
		_encounter_log.resize(8)


func _active_region_operation_line(region: Dictionary) -> String:
	if _active_region_operation.is_empty():
		return "No active regional operation. Choose scout, patrol or raid to create a visible campaign objective."
	var same_region := region.is_empty() or String(region.get("name", "")) == String(_active_region_operation.get("region_name", ""))
	var prefix := "This water" if same_region else "Elsewhere"
	var action := String(_active_region_operation.get("action", "operation"))
	var target_position: Vector2 = _active_region_operation.get("target_position", _player_position)
	return "%s: %s in %s\nTarget: %s\nDistance: %.1f days\nStarted: April %d, pressure %d, power %d" % [
		prefix,
		_region_operation_action_label(action),
		String(_active_region_operation.get("region_name", "Waters")),
		String(_active_region_operation.get("target_label", "marked target")),
		_player_position.distance_to(target_position) * 12.0,
		int(_active_region_operation.get("day", int(floor(_campaign_day)))),
		int(_active_region_operation.get("pressure_start", 0)),
		int(_active_region_operation.get("power_start", 0)),
	]


func _regional_effect_report(region: Dictionary) -> String:
	var lines: Array[String] = []
	for effect in _regional_effects:
		if not region.is_empty() and String(effect.get("region_name", "")) != String(region.get("name", "")):
			continue
		lines.append("- %s in %s: %s pressure, %.1f days left\n  %s" % [
			String(effect.get("name", "Regional effect")),
			String(effect.get("region_name", "Waters")),
			_signed_int_text(int(effect.get("pressure_delta", 0))),
			maxf(0.0, float(effect.get("expires_day", _campaign_day)) - _campaign_day),
			String(effect.get("description", "Temporary strategic effect.")),
		])
	if lines.is_empty():
		return "- None. Complete Scout, Patrol or Raid operations to leave temporary map effects."
	return "\n".join(lines)


func _region_operation_action_label(action: String) -> String:
	match action:
		"scout":
			return "Scout lead"
		"patrol":
			return "Patrol contact"
		"raid":
			return "Regional raid"
	return "Regional operation"


func _resolve_active_region_operation_for_party(party: Dictionary, outcome: String) -> Dictionary:
	if _active_region_operation.is_empty():
		return {}
	var action := String(_active_region_operation.get("action", ""))
	var target_id := String(_active_region_operation.get("target_id", ""))
	var party_name := String(party.get("name", ""))
	var party_region := String(party.get("operation_region", ""))
	var operation_region := String(_active_region_operation.get("region_name", ""))
	var matches := false
	if action == "raid" and bool(party.get("regional_operation", false)) and party_region == operation_region:
		matches = true
	elif action == "patrol" and target_id == party_name:
		matches = true
	if not matches:
		return {}
	var faction := String(_active_region_operation.get("faction", String(party.get("faction", "Independent"))))
	_add_regional_effect_from_operation(action)
	var power_now := int(_faction_power.get(faction, 45))
	var region_now := _find_sea_region_by_name(operation_region)
	var pressure_now := _sea_region_pressure(region_now) if not region_now.is_empty() else _region_pressure_for_faction(faction)
	var summary := "%s completed: %s %s. %s now reads sea power %d, pressure %d." % [
		_region_operation_action_label(action),
		String(_active_region_operation.get("target_label", party_name)),
		outcome,
		faction,
		power_now,
		pressure_now,
	]
	_encounter_log.push_front(summary)
	_active_region_operation = {}
	return {"summary": summary}


func _resolve_active_region_operation_for_opportunity(opportunity: Dictionary, result: String) -> Dictionary:
	if _active_region_operation.is_empty():
		return {}
	if String(_active_region_operation.get("action", "")) != "scout":
		return {}
	if String(_active_region_operation.get("target_id", "")) != String(opportunity.get("id", "")):
		return {}
	var region_name := String(_active_region_operation.get("region_name", "Waters"))
	_add_regional_effect_from_operation("scout")
	var summary := "Scout lead completed in %s. %s" % [region_name, result.replace("\n", " ")]
	_encounter_log.push_front(summary)
	_active_region_operation = {}
	return {"summary": summary}


func _add_regional_effect_from_operation(action: String) -> void:
	if _active_region_operation.is_empty():
		return
	var region := _find_sea_region_by_name(String(_active_region_operation.get("region_name", "")))
	var position: Vector2 = _active_region_operation.get("target_position", _player_position)
	var name := "Charted Lane"
	var pressure_delta := -6
	var radius := 0.120
	var duration := 4.0
	var color := Color(0.58, 1.0, 0.70)
	var description := "Scout reports reduce uncertainty and make routes safer for a few days."
	if action == "patrol":
		name = "Patrol Disrupted"
		pressure_delta = -10
		radius = 0.135
		duration = 4.5
		color = Color(0.46, 0.78, 1.0)
		description = "A moving patrol contact was broken; nearby pressure drops until the faction regroups."
	elif action == "raid":
		name = "Sea Power Shock"
		pressure_delta = -14
		radius = 0.155
		duration = 5.5
		color = Color(0.86, 0.64, 1.0)
		description = "A direct raid shakes command confidence and opens a temporary route window."
	var effect := {
		"id": "%s_%d" % [String(_active_region_operation.get("id", action)), int(_campaign_day * 100.0)],
		"name": name,
		"type": action,
		"region_name": String(_active_region_operation.get("region_name", "Waters")),
		"region_id": String(_active_region_operation.get("region_id", "")),
		"faction": String(_active_region_operation.get("faction", "Independent")),
		"position": region.get("position", position) if not region.is_empty() else position,
		"radius": radius,
		"pressure_delta": pressure_delta,
		"expires_day": _campaign_day + duration,
		"color": color,
		"description": description,
		"read": "%s pressure until Apr %d" % [_signed_int_text(pressure_delta), int(ceil(_campaign_day + duration))],
	}
	_regional_effects.push_front(effect)
	if _regional_effects.size() > 6:
		_regional_effects.resize(6)
	_political_log.push_front("%s: %s (%s pressure)" % [
		String(effect.get("region_name", "Waters")),
		name,
		_signed_int_text(pressure_delta),
	])
	if _political_log.size() > 8:
		_political_log.resize(8)


func _update_regional_effects() -> void:
	for i in range(_regional_effects.size() - 1, -1, -1):
		var effect: Dictionary = _regional_effects[i]
		if _campaign_day > float(effect.get("expires_day", _campaign_day)):
			_regional_effects.remove_at(i)


func _find_sea_region_by_name(region_name: String) -> Dictionary:
	for region in _sea_regions:
		if String(region.get("name", "")) == region_name:
			return region.duplicate(true)
	return {}


func _is_location_enterable(location: Dictionary) -> bool:
	var position: Vector2 = location.get("position", Vector2.ZERO)
	return _player_position.distance_to(position) <= _get_location_enter_radius(location)


func _get_location_enter_radius(location: Dictionary) -> float:
	match String(location.get("kind", "port")):
		"sea":
			return ENTER_DISTANCE_SEA
		"fort":
			return ENTER_DISTANCE_FORT
		_:
			return ENTER_DISTANCE_PORT


func _get_map_size() -> Vector2:
	if _map_canvas != null and _map_canvas.size.x > 1.0 and _map_canvas.size.y > 1.0:
		return _map_canvas.size
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y - 78.0, 1.0))


func _set_hover_from_point(point: Vector2) -> void:
	var opportunity_index := _opportunity_at_point(point)
	if opportunity_index >= 0:
		var opportunity: Dictionary = _sea_opportunities[opportunity_index]
		_hover_index = -1
		_hover_party_index = -1
		var color := _opportunity_color(String(opportunity.get("type", "salvage")))
		_tooltip_title.text = String(opportunity.get("name", "Sea Opportunity"))
		_tooltip_title.add_theme_color_override("font_color", color)
		_tooltip_body.text = "Risk: %s\nReward: %s\n%s" % [
			String(opportunity.get("risk", "unknown")),
			String(opportunity.get("reward", "unknown")),
			String(opportunity.get("description", "")),
		]
		_tooltip_panel.position = point + Vector2(18.0, 18.0)
		_tooltip_panel.visible = true
		return

	var index := _location_at_point(point)
	_hover_index = index
	if index >= 0:
		var location: Dictionary = _locations[index]
		var faction := String(location.get("faction", ""))
		var reputation := int(_faction_reputation.get(faction, 0))
		var power := int(_faction_power.get(faction, 45))
		_tooltip_title.text = String(location.get("name", "Location"))
		_tooltip_title.add_theme_color_override("font_color", location.get("color", Color.WHITE))
		_tooltip_body.text = "%s - %s (%d)\nSea power: %d/100\n%s" % [
			faction,
			_reputation_label(reputation),
			reputation,
			power,
			String(location.get("mood", "")),
		]
		_tooltip_panel.position = point + Vector2(18.0, 18.0)
		_tooltip_panel.visible = true
		return

	var party_index := _party_at_point(point)
	_hover_party_index = party_index
	if party_index < 0:
		_tooltip_panel.visible = false
		return

	var party: Dictionary = _parties[party_index]
	var relation_state := _get_party_relation_state(party)
	_tooltip_title.text = String(party.get("name", "Fleet"))
	_tooltip_title.add_theme_color_override("font_color", party.get("color", Color.WHITE))
	_tooltip_body.text = "%s - %s (%d)\n%s\nIntent: %s\nDistance: %.1f days" % [
		String(relation_state.get("faction", "Unknown")),
		String(relation_state.get("label", "Wary")),
		int(relation_state.get("reputation", 0)),
		String(party.get("role", "Moving party")),
		String(relation_state.get("effective_stance", party.get("stance", "neutral"))),
		_player_position.distance_to(party.get("position", Vector2.ZERO)) * 12.0,
	]
	_tooltip_panel.position = point + Vector2(18.0, 18.0)
	_tooltip_panel.visible = true


func _location_at_point(point: Vector2) -> int:
	var map_size := _get_map_size()
	for i in range(_locations.size()):
		var location: Dictionary = _locations[i]
		var pos: Vector2 = location.get("position", Vector2.ZERO) * map_size
		if point.distance_to(pos) <= 22.0:
			return i
	return -1


func _party_at_point(point: Vector2) -> int:
	var map_size := _get_map_size()
	for i in range(_parties.size()):
		var party: Dictionary = _parties[i]
		var pos: Vector2 = party.get("position", Vector2.ZERO) * map_size
		if point.distance_to(pos) <= 18.0:
			return i
	return -1


func _opportunity_at_point(point: Vector2) -> int:
	var map_size := _get_map_size()
	for i in range(_sea_opportunities.size()):
		var opportunity: Dictionary = _sea_opportunities[i]
		var pos: Vector2 = opportunity.get("position", Vector2.ZERO) * map_size
		if point.distance_to(pos) <= 24.0:
			return i
	return -1


func _opportunity_color(kind: String) -> Color:
	match kind:
		"salvage":
			return Color(0.98, 0.78, 0.36)
		"rescue":
			return Color(0.62, 0.95, 0.92)
		"mystery":
			return Color(0.95, 0.45, 0.28)
		_:
			return Color(0.92, 0.92, 0.78)


func _build_terrain_points() -> void:
	_forest_points.clear()
	_reef_points.clear()
	_mountain_points.clear()

	var i := 0
	while _forest_points.size() < 165 and i < 900:
		var p := Vector2(fposmod(0.11 + float(i) * 0.071, 0.96), fposmod(0.08 + float(i) * 0.113, 0.82))
		if _point_is_land(p):
			_forest_points.append(p)
		i += 1

	i = 0
	while _mountain_points.size() < 40 and i < 700:
		var p := Vector2(fposmod(0.05 + float(i) * 0.173, 0.92), fposmod(0.08 + float(i) * 0.157, 0.80))
		if _point_is_land(p):
			_mountain_points.append(p)
		i += 1

	i = 0
	while _reef_points.size() < 78 and i < 900:
		var p := Vector2(fposmod(0.18 + float(i) * 0.137, 0.78), fposmod(0.18 + float(i) * 0.091, 0.66))
		if not _point_is_land(p) and _point_near_land(p, 0.035):
			_reef_points.append(p)
		i += 1


func _point_is_land(point: Vector2) -> bool:
	for land in _landmasses:
		var points: Array = land.get("points", [])
		if _point_in_polygon(point, points):
			return true
	return false


func _point_near_land(point: Vector2, distance: float) -> bool:
	for land in _landmasses:
		var points: Array = land.get("points", [])
		if points.size() < 2:
			continue
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if _distance_to_segment(point, a, b) <= distance:
				return true
	return false


func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[j]
		var crosses := (a.y > point.y) != (b.y > point.y)
		if crosses:
			var denom := b.y - a.y
			if absf(denom) < 0.0001:
				j = i
				continue
			var x_at_y := (b.x - a.x) * (point.y - a.y) / denom + a.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _update_campaign_movement(delta: float) -> void:
	var manual := _get_campaign_manual_input()
	var player_moved := false
	var campaign_speed := _campaign_party_speed()
	if manual.length_squared() > 0.01:
		var movement := manual.normalized()
		_player_direction = movement
		_player_position += movement * campaign_speed * delta
		_player_position = _clamp_map_position(_player_position)
		_player_target = _player_position
		player_moved = true
	else:
		var to_target := _player_target - _player_position
		if to_target.length() > 0.004:
			var target_direction := to_target.normalized()
			_player_direction = target_direction
			_player_position += target_direction * minf(campaign_speed * delta, to_target.length())
			_player_position = _clamp_map_position(_player_position)
			player_moved = true

	if player_moved:
		_campaign_day += delta * 0.35
		_update_daily_wages()
		_update_travel_fatigue(delta)
		_update_region_pressure(delta)

	for i in range(_parties.size()):
		_update_party_movement(i, delta)

	_update_nearest_location()
	_update_nearby_encounter()
	_update_date_label()
	_update_course_panel()
	_position_world_labels()
	_map_canvas.queue_redraw()


func _update_party_movement(index: int, delta: float) -> void:
	if index < 0 or index >= _parties.size():
		return
	var party: Dictionary = _parties[index]
	var route: Array = party.get("route", [])
	if route.is_empty():
		return

	var position: Vector2 = party.get("position", Vector2.ZERO)
	var to_player := _player_position - position
	var distance_to_player := to_player.length()
	var relation_state := _get_party_relation_state(party)
	var stance := String(relation_state.get("effective_stance", party.get("stance", "neutral")))
	var detection_distance := float(relation_state.get("detection_distance", PARTY_DETECTION_DISTANCE))
	var chase_distance := float(relation_state.get("chase_distance", PARTY_CHASE_DISTANCE))
	var flee_distance := float(relation_state.get("flee_distance", PARTY_FLEE_DISTANCE))
	var desired_direction := Vector2.ZERO
	var speed_multiplier := 1.0
	var intent := "sailing route"
	var role_key := String(party.get("role", "Fleet")).to_lower()

	if distance_to_player <= detection_distance and to_player.length_squared() > 0.000001:
		match stance:
			"chase":
				if distance_to_player <= chase_distance:
					desired_direction = to_player.normalized()
					speed_multiplier = 1.18
					intent = "closing to engage"
			"flee":
				if distance_to_player <= flee_distance:
					desired_direction = (-to_player).normalized()
					speed_multiplier = 1.28
					intent = "evading"
			"shadow":
				if distance_to_player <= chase_distance:
					var flank := Vector2(-to_player.y, to_player.x).normalized()
					desired_direction = (to_player.normalized() * 0.45 + flank * 0.55).normalized()
					speed_multiplier = 0.92
					intent = "shadowing"
			"avoid":
				desired_direction = (-to_player).normalized()
				speed_multiplier = 0.86
				intent = "withdrawing"

	if desired_direction == Vector2.ZERO and _active_pressure_faction == String(party.get("faction", "")) and to_player.length_squared() > 0.000001:
		if role_key.contains("patrol") or role_key.contains("escort") or role_key.contains("blockade"):
			desired_direction = to_player.normalized()
			speed_multiplier = 1.05
			intent = "investigating pressure"

	if desired_direction == Vector2.ZERO:
		var route_direction := _get_party_route_direction(party, position)
		desired_direction = route_direction.get("direction", Vector2.ZERO)
		party["route_index"] = int(route_direction.get("route_index", party.get("route_index", 0)))

	if desired_direction.length_squared() > 0.001:
		position += desired_direction.normalized() * float(party.get("speed", 0.05)) * speed_multiplier * delta
		position = _clamp_map_position(position)
		party["position"] = position
		party["direction"] = desired_direction.normalized()
		party["intent"] = intent
		party["relation_state"] = String(relation_state.get("label", "Wary"))
		_parties[index] = party


func _get_party_relation_state(party: Dictionary) -> Dictionary:
	var faction := String(party.get("faction", "Independent"))
	var reputation := int(_faction_reputation.get(faction, 0))
	var base_stance := String(party.get("stance", "neutral"))
	var effective_stance := base_stance
	var detection_distance := PARTY_DETECTION_DISTANCE
	var chase_distance := PARTY_CHASE_DISTANCE
	var flee_distance := PARTY_FLEE_DISTANCE

	if reputation <= -35:
		effective_stance = "chase"
		detection_distance *= 1.45
		chase_distance *= 1.45
	elif reputation <= -15:
		if base_stance == "neutral" or base_stance == "shadow":
			effective_stance = "chase"
		detection_distance *= 1.22
		chase_distance *= 1.20
	elif reputation >= 35:
		if base_stance == "chase" or base_stance == "shadow":
			effective_stance = "neutral"
		detection_distance *= 0.72
		chase_distance *= 0.70
	elif reputation >= 15:
		if base_stance == "chase":
			effective_stance = "shadow"
		detection_distance *= 0.88

	return {
		"faction": faction,
		"reputation": reputation,
		"label": _reputation_label(reputation),
		"base_stance": base_stance,
		"effective_stance": effective_stance,
		"detection_distance": detection_distance,
		"chase_distance": chase_distance,
		"flee_distance": flee_distance,
	}


func _get_party_route_direction(party: Dictionary, position: Vector2) -> Dictionary:
	var route: Array = party.get("route", [])
	if route.is_empty():
		return {"direction": Vector2.ZERO, "route_index": int(party.get("route_index", 0))}
	var route_index := int(party.get("route_index", 0)) % route.size()
	var target: Vector2 = route[route_index]
	var to_target := target - position
	if to_target.length() < 0.006:
		route_index = (route_index + 1) % route.size()
		target = route[route_index]
		to_target = target - position
	return {
		"direction": to_target.normalized() if to_target.length_squared() > 0.000001 else Vector2.ZERO,
		"route_index": route_index,
	}


func _get_campaign_manual_input() -> Vector2:
	var left := Input.get_action_strength("campaign_left") > 0.2 or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.get_action_strength("campaign_right") > 0.2 or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.get_action_strength("campaign_up") > 0.2 or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.get_action_strength("campaign_down") > 0.2 or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(
		(1.0 if right else 0.0) - (1.0 if left else 0.0),
		(1.0 if down else 0.0) - (1.0 if up else 0.0)
	)


func _campaign_party_speed() -> float:
	var morale := int(_ship_condition.get("morale", 58))
	var hull := int(_ship_condition.get("hull", 100))
	var sailors := int(_ship_condition.get("sailors", 42))
	var morale_factor := lerpf(0.78, 1.16, clampf(float(morale) / 100.0, 0.0, 1.0))
	var hull_factor := lerpf(0.70, 1.0, clampf(float(hull) / 100.0, 0.0, 1.0))
	var crew_factor := clampf(float(sailors) / 42.0, 0.62, 1.0)
	return _player_speed * morale_factor * hull_factor * crew_factor


func _clamp_map_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 0.03, 0.97), clampf(value.y, 0.06, 0.88))


func _update_nearest_location() -> void:
	var best_index := _selected_index
	var best_distance := 999.0
	for i in range(_locations.size()):
		var location: Dictionary = _locations[i]
		var distance := _player_position.distance_to(location.get("position", Vector2.ZERO))
		if distance < best_distance:
			best_distance = distance
			best_index = i
	_nearest_location_distance = best_distance
	if _selected_opportunity_index < 0 and _locked_encounter_party_name.is_empty() and best_distance < _get_location_enter_radius(_locations[best_index]) and best_index != _selected_index:
		_set_selected_index(best_index)


func _update_nearby_encounter() -> void:
	var previous_index := _nearby_encounter_index
	_nearby_encounter_index = -1
	if not _locked_encounter_party_name.is_empty():
		var locked_index := _party_index_by_name(_locked_encounter_party_name)
		if locked_index >= 0:
			var locked_party: Dictionary = _parties[locked_index]
			var locked_distance := _player_position.distance_to(locked_party.get("position", Vector2.ZERO))
			if locked_distance <= _party_encounter_radius(locked_party) * 2.25:
				_nearby_encounter_index = locked_index
				_selected_party_index = locked_index
				return
		_locked_encounter_party_name = ""
	var best_distance := 999.0
	for i in range(_parties.size()):
		var party: Dictionary = _parties[i]
		var distance := _player_position.distance_to(party.get("position", Vector2.ZERO))
		var encounter_distance := _party_encounter_radius(party)
		if distance <= encounter_distance and distance < best_distance:
			best_distance = distance
			_nearby_encounter_index = i
	if _nearby_encounter_index >= 0:
		_selected_party_index = _nearby_encounter_index
		_locked_encounter_party_name = String(_parties[_nearby_encounter_index].get("name", ""))
		if previous_index != _nearby_encounter_index:
			var party: Dictionary = _parties[_nearby_encounter_index]
			var message := "%s sighted at close range" % String(party.get("name", "Fleet"))
			if String(party.get("intent", "")) == "investigating pressure":
				message = "%s is intercepting your route" % String(party.get("name", "Fleet"))
			_encounter_log.push_front(message)
			if _encounter_log.size() > 8:
				_encounter_log.resize(8)


func _party_encounter_radius(party: Dictionary) -> float:
	var encounter_distance := ENCOUNTER_DISTANCE
	if String(party.get("intent", "")) == "investigating pressure":
		encounter_distance *= 1.65
	if String(party.get("stance", "")) == "chase":
		encounter_distance *= 1.18
	return encounter_distance


func _update_date_label() -> void:
	var day := int(floor(_campaign_day))
	var hour := int(fposmod(_campaign_day, 1.0) * 24.0)
	var time_name := "Morning"
	if hour >= 12 and hour < 17:
		time_name = "Afternoon"
	elif hour >= 17 and hour < 21:
		time_name = "Evening"
	elif hour >= 21 or hour < 5:
		time_name = "Night"
	_date_label.text = "April %d, 1665\n%s" % [maxi(day, 1), time_name]


func _update_daily_wages() -> void:
	var day := int(floor(_campaign_day))
	if day <= _last_wage_day:
		return
	_last_wage_day = day
	var wage := 6
	if int(_cargo_hold.get("silver", 0)) >= wage:
		_cargo_hold["silver"] = int(_cargo_hold.get("silver", 0)) - wage
		_encounter_log.push_front("Crew wages paid: %d silver" % wage)
	else:
		_ship_condition["morale"] = clampi(int(_ship_condition.get("morale", 58)) - 10, 0, 100)
		if int(_ship_condition.get("morale", 58)) < 25 and int(_ship_condition.get("sailors", 42)) > 24:
			_ship_condition["sailors"] = int(_ship_condition.get("sailors", 42)) - 2
			_encounter_log.push_front("Unpaid crew deserted: sailors -2")
		else:
			_encounter_log.push_front("Unpaid crew: morale drops")
	if _encounter_log.size() > 8:
		_encounter_log.resize(8)


func _show_bottom_panel(section: String) -> void:
	section = _normalize_bottom_section(section)
	_active_panel_section = section
	_set_bottom_button_active(section)
	_apply_info_panel_layout(section)
	_populate_bottom_panel(section)
	if _info_scroll != null:
		_info_scroll.scroll_vertical = 0
	_info_panel.visible = true


func _close_info_panel() -> void:
	if _info_panel != null:
		_info_panel.visible = false


func _normalize_bottom_section(section: String) -> String:
	if section == "Map" or section == "Reports" or section == "Factions":
		return "Notes"
	return section


func _apply_info_panel_layout(section: String) -> void:
	if _info_panel == null:
		return
	var full_screen := section == "Inventory" or section == "Party" or section == "Notes"
	if full_screen:
		_info_panel.anchor_left = 0.11
		_info_panel.anchor_right = 0.89
		_info_panel.anchor_top = 0.10
		_info_panel.anchor_bottom = 0.86
		_info_panel.offset_left = 0.0
		_info_panel.offset_right = 0.0
		_info_panel.offset_top = 0.0
		_info_panel.offset_bottom = 0.0
		_info_panel.z_index = 55
		_info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.105, 0.065, 0.985)))
		if _info_title != null:
			_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_info_panel.anchor_left = 0.03
		_info_panel.anchor_right = 0.37
		_info_panel.anchor_top = 1.0
		_info_panel.anchor_bottom = 1.0
		_info_panel.offset_left = 0.0
		_info_panel.offset_right = 0.0
		_info_panel.offset_top = -360.0
		_info_panel.offset_bottom = -96.0
		_info_panel.z_index = 35
		_info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.016, 0.012, 0.96)))
		if _info_title != null:
			_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _reset_info_content() -> void:
	if _info_content == null:
		return
	for child in _info_content.get_children():
		if child != _info_body:
			_info_content.remove_child(child)
			child.queue_free()
	if _info_body != null:
		_info_body.visible = true
		_info_body.text = ""


func _begin_visual_info() -> void:
	if _info_body != null:
		_info_body.visible = false


func _build_notes_panel() -> void:
	_begin_visual_info()
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_content.add_child(layout)

	var notes := _add_visual_column(layout, "Captain's Notes", Color(0.18, 0.12, 0.075), 310.0)
	notes.add_child(_visual_summary_panel("Current Orders", _campaign_orders_report(), Color(0.13, 0.09, 0.055)))
	notes.add_child(_visual_summary_panel("Contracts", _contract_report(), Color(0.10, 0.075, 0.045)))
	notes.add_child(_visual_summary_panel("Sea Chances", _opportunity_report(), Color(0.08, 0.11, 0.10)))
	notes.add_child(_visual_summary_panel("Chart Notes", "Pale Meridian: %s\nFree Captains around Nassau can become allies or rivals.\nBlackreef Wrecks has salvage, but raiders use the shoals." % [
		"route discovered" if bool(_discovered_regions.get("pale_meridian", false)) else "locked behind fog until renown or Uncharted knowledge rises",
	], Color(0.10, 0.075, 0.045)))

	var reports := _add_visual_column(layout, "Reports", Color(0.13, 0.15, 0.13), 350.0)
	reports.add_child(_visual_summary_panel("World Events", _world_events_report(), Color(0.07, 0.10, 0.08)))
	reports.add_child(_visual_summary_panel("Fleet Read", _selected_party_report() if not _selected_party_report().is_empty() else _nearest_party_report(), Color(0.08, 0.10, 0.12)))
	reports.add_child(_visual_summary_panel("Recent Actions", _recent_encounter_report(), Color(0.12, 0.09, 0.055)))
	reports.add_child(_visual_summary_panel("Prize History", _defeated_party_report(), Color(0.10, 0.075, 0.045)))

	var factions := _add_visual_column(layout, "Factions", Color(0.16, 0.12, 0.10), 350.0)
	factions.add_child(_visual_summary_panel("Warfront", _warfront_report(), Color(0.11, 0.08, 0.055)))
	for faction in ["Crown Dominion", "Free Captains", "Ironwake Compact", "Independent", "Unclaimed", "Uncharted"]:
		_add_faction_state_card(factions, faction)


func _add_faction_state_card(parent: Control, faction: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.095, 0.070, 0.045, 0.95)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var swatch := _solid_panel(Vector2(24.0, 24.0), _faction_color(faction), 3)
	header.add_child(swatch)
	var title := _make_label(faction, 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	header.add_child(title)
	var relation := int(_faction_reputation.get(faction, 0))
	var relation_label := _make_label("%s %s" % [_reputation_label(relation), _signed_int_text(relation)], 11)
	relation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(relation_label)
	_add_stat_bar(box, "Sea Power", int(_faction_power.get(faction, 45)), 100, _faction_color(faction))
	_add_stat_bar(box, "Relation", _relation_to_bar_value(relation), 100, Color(0.62, 0.50, 0.86))


func _faction_color(faction: String) -> Color:
	match faction:
		"Crown Dominion":
			return FACTION_CROWN
		"Free Captains":
			return FACTION_FREE
		"Ironwake Compact":
			return FACTION_IRON
		"Unclaimed":
			return FACTION_RAIDER
		"Uncharted":
			return FACTION_MERIDIAN
	return Color(0.88, 0.92, 0.82)


func _build_inventory_panel() -> void:
	_begin_visual_info()
	var deck := HBoxContainer.new()
	deck.add_theme_constant_override("separation", 12)
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_content.add_child(deck)

	var stores := _add_visual_column(deck, "Ship Stores", Color(0.18, 0.12, 0.075), 300.0)
	stores.add_child(_visual_summary_panel("Load Plan", _cargo_load_summary(), Color(0.13, 0.09, 0.055)))
	_add_store_category_card(stores, "Repair Stores", "Timber and canvas kept for hull and sail work.", int(_cargo_hold.get("timber", 0)) + int(_cargo_hold.get("canvas", 0)), 30, "timber", Color(0.55, 0.34, 0.18))
	_add_store_category_card(stores, "Powder Room", "Charges reserved for repair kits and battle prep.", int(_cargo_hold.get("powder", 0)), 18, "powder", Color(0.25, 0.25, 0.25))
	_add_store_category_card(stores, "Prize Locker", "Captured cargo waiting for a good market.", int(_cargo_hold.get("contraband", 0)) + int(_cargo_hold.get("cannon_parts", 0)), 16, "contraband", Color(0.45, 0.16, 0.12))
	_add_store_category_card(stores, "Purse", "Silver for crew, rumors and port work.", int(_cargo_hold.get("silver", 0)), 80, "silver", Color(0.78, 0.78, 0.68))

	var outfit := _add_visual_column(deck, "Ship Outfit", Color(0.22, 0.16, 0.10), 320.0)
	_add_ship_profile_card(outfit)
	_add_stat_bar(outfit, "Hull", int(_ship_condition.get("hull", 100)), 100, Color(0.58, 0.82, 0.54))
	_add_stat_bar(outfit, "Repair Kits", int(_ship_condition.get("repair_supplies", 3)), 3, Color(0.70, 0.92, 1.0))
	_add_stat_bar(outfit, "Cargo Slots", _cargo_slot_count(), 18, Color(0.95, 0.78, 0.36))

	var hold := _add_visual_column(deck, "Cargo Hold", Color(0.17, 0.115, 0.070), 360.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold.add_child(grid)
	_add_inventory_slot(grid, "Timber", int(_cargo_hold.get("timber", 0)), Color(0.55, 0.34, 0.18), "repair beams")
	_add_inventory_slot(grid, "Canvas", int(_cargo_hold.get("canvas", 0)), Color(0.80, 0.74, 0.58), "sail cloth")
	_add_inventory_slot(grid, "Powder", int(_cargo_hold.get("powder", 0)), Color(0.25, 0.25, 0.25), "kit charges")
	_add_inventory_slot(grid, "Parts", int(_cargo_hold.get("cannon_parts", 0)), Color(0.54, 0.58, 0.62), "gun scrap")
	_add_inventory_slot(grid, "Contraband", int(_cargo_hold.get("contraband", 0)), Color(0.45, 0.16, 0.12), "black market")
	_add_inventory_slot(grid, "Silver", int(_cargo_hold.get("silver", 0)), Color(0.78, 0.78, 0.68), "purse")
	hold.add_child(_visual_summary_panel("Nearest Market", _market_report(), Color(0.13, 0.09, 0.055)))
	_add_inventory_action_row(hold)


func _build_party_panel() -> void:
	_begin_visual_info()
	var sailors := int(_ship_condition.get("sailors", 42))
	var gunners := int(_ship_condition.get("gunners", 18))
	var carpenters := int(_ship_condition.get("carpenters", 6))
	var total := sailors + gunners + carpenters
	var cap_total := _crew_cap("sailors") + _crew_cap("gunners") + _crew_cap("carpenters")
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_content.add_child(layout)

	var skills := _add_visual_column(layout, "Party Skills", Color(0.17, 0.12, 0.08), 280.0)
	_add_stat_bar(skills, "Boarding", sailors, _crew_cap("sailors"), Color(0.52, 0.70, 0.86))
	_add_stat_bar(skills, "Broadside", gunners, _crew_cap("gunners"), Color(0.86, 0.62, 0.34))
	_add_stat_bar(skills, "Repairs", carpenters, _crew_cap("carpenters"), Color(0.58, 0.82, 0.54))
	_add_stat_bar(skills, "Morale", int(_ship_condition.get("morale", 58)), 100, Color(0.95, 0.78, 0.36))

	var center := _add_visual_column(layout, "Quarterdeck", Color(0.22, 0.16, 0.10), 310.0)
	_add_ship_profile_card(center)
	center.add_child(_make_deck_muster_panel(sailors, gunners, carpenters))
	center.add_child(_visual_summary_panel("Company", "%d/%d crew\nCampaign speed %.2f\nDaily wages 6 silver\nHire cost %d silver" % [
		total,
		cap_total,
		_campaign_party_speed(),
		_hire_crew_cost(),
	], Color(0.13, 0.09, 0.055)))

	var roster := _add_visual_column(layout, "Company Roster", Color(0.17, 0.115, 0.070), 360.0)
	roster.add_child(_crew_card("Sailors", sailors, _crew_cap("sailors"), "Speed / Boarding", Color(0.52, 0.70, 0.86)))
	roster.add_child(_crew_card("Gunners", gunners, _crew_cap("gunners"), "Reload / Broadside", Color(0.86, 0.62, 0.34)))
	roster.add_child(_crew_card("Carpenters", carpenters, _crew_cap("carpenters"), "Repair / Flooding", Color(0.58, 0.82, 0.54)))
	roster.add_child(_visual_summary_panel("Readiness", "Hull %d%%\nRepair kits %d/3" % [
		int(_ship_condition.get("hull", 100)),
		int(_ship_condition.get("repair_supplies", 3)),
	], Color(0.12, 0.12, 0.08)))


func _visual_summary_panel(title: String, body: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.92)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_label := _make_label(title, 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(title_label)
	var body_label := _make_label(body, 12)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body_label)
	return panel


func _add_visual_column(parent: Control, title: String, color: Color, min_width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.96)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	var label := _make_label(title, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(label)
	var line := HSeparator.new()
	box.add_child(line)
	return box


func _add_empty_inventory_grid(parent: Control, columns: int, rows: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for i in range(columns * rows):
		_add_inventory_slot(grid, "Empty", 0, Color(0.07, 0.055, 0.04), "slot")


func _cargo_load_summary() -> String:
	var repair_total := int(_cargo_hold.get("timber", 0)) + int(_cargo_hold.get("canvas", 0))
	var battle_total := int(_cargo_hold.get("powder", 0)) + int(_ship_condition.get("repair_supplies", 3)) * 2
	var prize_total := int(_cargo_hold.get("contraband", 0)) + int(_cargo_hold.get("cannon_parts", 0))
	var ready := "balanced"
	if repair_total < 8:
		ready = "repair-light"
	elif battle_total < 10:
		ready = "powder-light"
	elif prize_total > 10:
		ready = "heavy with prize cargo"
	return "Hold use: %d/18 slots\nLoad state: %s\nSilver: %d\nNearest market below reacts to port access." % [
		_cargo_slot_count(),
		ready,
		int(_cargo_hold.get("silver", 0)),
	]


func _add_store_category_card(parent: Control, title: String, body: String, value: int, max_value: int, icon_kind: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.095, 0.070, 0.045, 0.95)))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := _make_cargo_icon(icon_kind, color, Vector2(108.0, 72.0))
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var title_label := _make_label(title, 14)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	top.add_child(title_label)
	var value_label := _make_label("%d/%d" % [value, max_value], 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_label)
	var body_label := _make_label(body, 11)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(body_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = float(maxi(max_value, 1))
	bar.value = clampf(float(value), 0.0, float(maxi(max_value, 1)))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120.0, 12.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.022, 0.018, 0.95)))
	bar.add_theme_stylebox_override("fill", _progress_style(color))
	box.add_child(bar)


func _add_inventory_action_row(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.060, 0.040, 0.96)))
	parent.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(grid)
	_add_inventory_action_button(grid, "Open Market", Callable(self, "_open_market_from_inventory"))
	_add_inventory_action_button(grid, "Open Shipyard", Callable(self, "_open_shipyard_from_inventory"))


func _add_inventory_action_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(124.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _open_market_from_inventory() -> void:
	_info_panel.visible = false
	_show_market_interaction()
	_open_interaction_panel()


func _open_shipyard_from_inventory() -> void:
	_info_panel.visible = false
	_show_shipyard_interaction()
	_open_interaction_panel()


func _add_ship_profile_card(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.075, 0.045, 0.96)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var ship := _make_ship_silhouette()
	box.add_child(ship)
	var caption := _make_label("Brig outfit and cargo balance", 12)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(caption)


func _add_stat_bar(parent: Control, label_text: String, value: int, max_value: int, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.07, 0.05, 0.95)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var label := _make_label(label_text, 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var value_label := _make_label("%d/%d" % [value, max_value], 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = float(maxi(max_value, 1))
	bar.value = clampf(float(value), 0.0, float(maxi(max_value, 1)))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.022, 0.018, 0.95)))
	bar.add_theme_stylebox_override("fill", _progress_style(color))
	box.add_child(bar)


func _add_metric_card(parent: Control, title: String, value: int, caption: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150.0, 86.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.07, 0.05, 0.95)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title_label := _make_label(title, 13)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(title_label)
	_add_stat_bar(box, caption, value, 100, color)


func _add_district_card(parent: Control, title: String, body: String, state: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220.0, 116.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.90)))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title_label := _make_label(title, 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(title_label)
	var body_label := _make_label(body, 12)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_label)
	var state_label := _make_label(state, 11)
	state_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(state_label)


func _add_interaction_notice_card() -> void:
	if _interaction_notice.is_empty() or _interaction_content == null:
		return
	_interaction_content.add_child(_visual_summary_panel("Result", _interaction_notice, Color(0.24, 0.11, 0.08)))


func _market_good_price_text(market: Dictionary, good: String) -> String:
	var buy: Dictionary = market.get("buy_prices", {})
	var sell: Dictionary = market.get("sell_prices", {})
	if good == "contraband" or good == "cannon_parts":
		return "sell %d" % int(sell.get(good, 0))
	return "buy %d" % int(buy.get(good, 0))


func _make_cargo_icon(kind: String, color: Color, min_size: Vector2) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = min_size
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.043, 0.032, 0.88)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(box)
	match kind:
		"timber":
			_add_timber_icon(box, color)
		"canvas":
			_add_canvas_icon(box, color)
		"powder":
			_add_powder_icon(box, color)
		"parts":
			_add_parts_icon(box, color)
		"contraband":
			_add_crate_icon(box, color)
		"silver":
			_add_silver_icon(box, color)
		_:
			_add_empty_icon(box)
	return frame


func _solid_panel(size: Vector2, color: Color, radius: int = 3) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add_timber_icon(parent: VBoxContainer, color: Color) -> void:
	for i in range(5):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		parent.add_child(row)
		var plank_width := 58.0 + float(i % 2) * 12.0
		row.add_child(_solid_panel(Vector2(8.0, 8.0), color.darkened(0.28), 2))
		row.add_child(_solid_panel(Vector2(plank_width, 8.0), color.lightened(0.05 * float(i)), 2))
		row.add_child(_solid_panel(Vector2(8.0, 8.0), color.darkened(0.22), 2))


func _add_canvas_icon(parent: VBoxContainer, color: Color) -> void:
	var bale := VBoxContainer.new()
	bale.alignment = BoxContainer.ALIGNMENT_CENTER
	bale.add_theme_constant_override("separation", 4)
	parent.add_child(bale)
	var cloth := HBoxContainer.new()
	cloth.alignment = BoxContainer.ALIGNMENT_CENTER
	cloth.add_theme_constant_override("separation", 3)
	bale.add_child(cloth)
	for i in range(4):
		cloth.add_child(_solid_panel(Vector2(16.0, 38.0), color.darkened(0.05 * float(i)), 2))
	var strap_row := HBoxContainer.new()
	strap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	strap_row.add_theme_constant_override("separation", 26)
	bale.add_child(strap_row)
	strap_row.add_child(_solid_panel(Vector2(7.0, 8.0), Color(0.40, 0.28, 0.16), 1))
	strap_row.add_child(_solid_panel(Vector2(7.0, 8.0), Color(0.40, 0.28, 0.16), 1))


func _add_powder_icon(parent: VBoxContainer, color: Color) -> void:
	parent.add_child(_solid_panel(Vector2(58.0, 7.0), color.lightened(0.18), 2))
	var barrel := HBoxContainer.new()
	barrel.alignment = BoxContainer.ALIGNMENT_CENTER
	barrel.add_theme_constant_override("separation", 2)
	parent.add_child(barrel)
	for i in range(5):
		barrel.add_child(_solid_panel(Vector2(10.0, 38.0), Color(0.30, 0.22, 0.16).lightened(0.04 * float(i)), 2))
	parent.add_child(_solid_panel(Vector2(58.0, 6.0), Color(0.08, 0.08, 0.08), 1))


func _add_parts_icon(parent: VBoxContainer, color: Color) -> void:
	var cannon := VBoxContainer.new()
	cannon.alignment = BoxContainer.ALIGNMENT_CENTER
	cannon.add_theme_constant_override("separation", 3)
	parent.add_child(cannon)
	var barrel := HBoxContainer.new()
	barrel.alignment = BoxContainer.ALIGNMENT_CENTER
	barrel.add_theme_constant_override("separation", 0)
	cannon.add_child(barrel)
	barrel.add_child(_solid_panel(Vector2(58.0, 14.0), color.darkened(0.10), 2))
	barrel.add_child(_solid_panel(Vector2(16.0, 20.0), color.lightened(0.05), 2))
	var wheels := HBoxContainer.new()
	wheels.alignment = BoxContainer.ALIGNMENT_CENTER
	wheels.add_theme_constant_override("separation", 36)
	cannon.add_child(wheels)
	wheels.add_child(_solid_panel(Vector2(14.0, 14.0), Color(0.11, 0.09, 0.07), 7))
	wheels.add_child(_solid_panel(Vector2(14.0, 14.0), Color(0.11, 0.09, 0.07), 7))
	cannon.add_child(_solid_panel(Vector2(74.0, 5.0), Color(0.30, 0.31, 0.32), 1))


func _add_crate_icon(parent: VBoxContainer, color: Color) -> void:
	var crate := VBoxContainer.new()
	crate.alignment = BoxContainer.ALIGNMENT_CENTER
	crate.add_theme_constant_override("separation", 2)
	parent.add_child(crate)
	for i in range(3):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		crate.add_child(row)
		row.add_child(_solid_panel(Vector2(26.0, 15.0), color.darkened(0.03 * float(i)), 1))
		row.add_child(_solid_panel(Vector2(26.0, 15.0), color.darkened(0.10 + 0.03 * float(i)), 1))
	var seal := HBoxContainer.new()
	seal.alignment = BoxContainer.ALIGNMENT_CENTER
	seal.add_theme_constant_override("separation", 4)
	crate.add_child(seal)
	seal.add_child(_solid_panel(Vector2(62.0, 5.0), Color(0.15, 0.06, 0.04), 1))


func _add_silver_icon(parent: VBoxContainer, color: Color) -> void:
	for row_index in range(3):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 3)
		parent.add_child(row)
		for i in range(4 - row_index):
			row.add_child(_solid_panel(Vector2(15.0, 8.0), color.lightened(0.08 * float(i)), 4))


func _add_empty_icon(parent: VBoxContainer) -> void:
	var empty := ColorRect.new()
	empty.custom_minimum_size = Vector2(64.0, 36.0)
	empty.color = Color(0.025, 0.020, 0.016, 0.82)
	parent.add_child(empty)


func _make_ship_silhouette() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230.0, 134.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.055, 0.040, 0.82)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var sails := HBoxContainer.new()
	sails.alignment = BoxContainer.ALIGNMENT_CENTER
	sails.add_theme_constant_override("separation", 8)
	box.add_child(sails)
	for height in [64.0, 76.0, 58.0]:
		var sail := ColorRect.new()
		sail.custom_minimum_size = Vector2(38.0, height)
		sail.color = Color(0.90, 0.84, 0.64)
		sails.add_child(sail)
	var deck := ColorRect.new()
	deck.custom_minimum_size = Vector2(190.0, 20.0)
	deck.color = Color(0.64, 0.39, 0.25)
	box.add_child(deck)
	var hull := ColorRect.new()
	hull.custom_minimum_size = Vector2(220.0, 24.0)
	hull.color = Color(0.34, 0.19, 0.14)
	box.add_child(hull)
	return panel


func _cargo_icon_kind(item_name: String) -> String:
	var key := item_name.to_lower()
	if key == "cannon parts" or key == "parts":
		return "parts"
	return key


func _add_inventory_slot(parent: Control, item_name: String, count: int, color: Color, tag: String) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(154.0, 164.0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.075, 0.045, 0.96)))
	parent.add_child(slot)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	slot.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	var name_label := _make_label(item_name, 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var count_label := _make_label("x%d" % count, 13)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	header.add_child(count_label)
	var icon := _make_cargo_icon(_cargo_icon_kind(item_name), color, Vector2(124.0, 82.0))
	box.add_child(icon)
	var tag_label := _make_label(tag, 10)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(tag_label)


func _make_deck_muster_panel(sailors: int, gunners: int, carpenters: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.075, 0.045, 0.96)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := _make_label("Deck Watch", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	row.add_child(_make_crew_muster("Sailors", sailors, _crew_cap("sailors"), Color(0.52, 0.70, 0.86), 4))
	row.add_child(_make_crew_muster("Gunners", gunners, _crew_cap("gunners"), Color(0.86, 0.62, 0.34), 4))
	row.add_child(_make_crew_muster("Carpenters", carpenters, _crew_cap("carpenters"), Color(0.58, 0.82, 0.54), 4))
	return panel


func _make_crew_muster(title: String, value: int, cap: int, color: Color, figure_count: int = 7) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.043, 0.032, 0.88)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	var active_count := clampi(int(ceil(float(value) / float(maxi(cap, 1)) * float(figure_count))), 0, figure_count)
	for i in range(figure_count):
		row.add_child(_make_crew_person(title, color, i < active_count))
	var label := _make_label("%d/%d" % [value, cap], 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.66))
	box.add_child(label)
	return panel


func _make_crew_person(kind: String, color: Color, active: bool) -> Control:
	var person := VBoxContainer.new()
	person.custom_minimum_size = Vector2(28.0, 52.0)
	person.alignment = BoxContainer.ALIGNMENT_CENTER
	person.add_theme_constant_override("separation", 1)
	var uniform := color if active else Color(0.18, 0.17, 0.15)
	var skin := Color(0.70, 0.52, 0.38) if active else Color(0.28, 0.25, 0.22)
	var hat := Color(0.12, 0.18, 0.24)
	match kind.to_lower():
		"gunners":
			hat = Color(0.08, 0.08, 0.075)
		"carpenters":
			hat = Color(0.30, 0.22, 0.12)
		_:
			hat = Color(0.13, 0.20, 0.28)
	if not active:
		hat = Color(0.14, 0.13, 0.12)
	person.add_child(_solid_panel(Vector2(17.0, 5.0), hat, 2))
	person.add_child(_solid_panel(Vector2(14.0, 14.0), skin, 7))
	person.add_child(_solid_panel(Vector2(20.0, 20.0), uniform.darkened(0.08), 3))
	var legs := HBoxContainer.new()
	legs.alignment = BoxContainer.ALIGNMENT_CENTER
	legs.add_theme_constant_override("separation", 3)
	legs.add_child(_solid_panel(Vector2(7.0, 10.0), Color(0.09, 0.08, 0.07), 2))
	legs.add_child(_solid_panel(Vector2(7.0, 10.0), Color(0.09, 0.08, 0.07), 2))
	person.add_child(legs)
	return person


func _crew_card(title: String, value: int, cap: int, role: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.095, 0.075, 0.050, 0.95)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	top.add_child(_make_crew_person(title, color, value > 0))
	var name_label := _make_label("%s  %d/%d" % [title, value, cap], 15)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	top.add_child(name_label)
	box.add_child(_make_crew_muster(title, value, cap, color, 8))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = float(maxi(cap, 1))
	bar.value = clampf(float(value), 0.0, float(maxi(cap, 1)))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.022, 0.018, 0.95)))
	bar.add_theme_stylebox_override("fill", _progress_style(color))
	box.add_child(bar)
	var role_label := _make_label(role, 11)
	role_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	box.add_child(role_label)
	return panel


func _populate_bottom_panel(section: String) -> void:
	section = _normalize_bottom_section(section)
	_info_title.text = section
	_reset_info_content()
	match section:
		"Map":
			var region: Dictionary = get_selected_region()
			var settlement := _get_settlement_state(region)
			var distance := _player_position.distance_to(region.get("position", _player_position))
			var enter_state := "Ready to enter" if _is_location_enterable(region) else "Sailing range: %.1f days" % (distance * 12.0)
			var encounter_line := _current_encounter_line()
			_info_body.text = "Selected: %s\nFaction: %s\nAccess: %s\nSecurity: %s (%d)\nProsperity: %s (%d)\n%s%s\n\n%s\n\n%s\n\n%s\n\n%s\n\nClick empty water for free travel. Click fleets or sea opportunities for choices. Enter works when your party reaches a harbor, sea marker, opportunity or close fleet." % [
				String(region.get("name", "Unknown")),
				String(region.get("faction", "Unknown")),
				String(settlement.get("access_label", "open")),
				String(settlement.get("security_label", "watched")),
				int(settlement.get("security", 50)),
				String(settlement.get("prosperity_label", "steady")),
				int(settlement.get("prosperity", 50)),
				enter_state,
				encounter_line,
				_current_waters_report(),
				_opportunity_report(),
				_voyage_risk_report(),
				_campaign_orders_report(),
		]
		"Camp":
			_info_body.text = _camp_report()
		"Reports":
			var party_focus := _selected_party_report()
			_info_body.text = "Nearby fleets: %d\nCurrent waters: %s\n%s\n%s\n%s\n%s\n%s\n%s" % [
				_parties.size(),
				String(get_selected_region().get("name", "Unknown")),
				_current_waters_report(),
				party_focus,
				_nearest_party_report(),
				_recent_encounter_report(),
				_defeated_party_report(),
				_political_report(),
			]
		"Factions":
			_info_body.text = _factions_report()
		"Notes":
			_build_notes_panel()
		"Inventory":
			_build_inventory_panel()
		"Character":
			_info_body.text = _character_report()
		"Party":
			_build_party_panel()
		_:
			_info_body.text = "No report."


func _update_course_panel() -> void:
	if _course_panel == null or _course_body == null:
		return
	var target := _campaign_primary_target()
	var waters := _current_sea_region()
	var waters_name := String(waters.get("name", "Open sea")) if not waters.is_empty() else "Open sea"
	var pressure := _sea_region_pressure(waters) if not waters.is_empty() else 20
	_course_title.text = String(target.get("title", "Captain's Course"))
	_course_body.text = "%s\n\nTarget: %s\nDistance: %s\nWaters: %s, pressure %d/100\nNext: %s\n\n%s\n\n%s" % [
		String(target.get("summary", "Choose a harbor, fleet, job or sea lane.")),
		String(target.get("target", "None")),
		String(target.get("distance", "-")),
		waters_name,
		pressure,
		String(target.get("next", "Left-click to plot a course.")),
		_voyage_risk_report(),
		_campaign_orders_report(),
	]


func _update_world_events_panel() -> void:
	if _world_events_panel == null or _world_events_body == null:
		return
	_world_events_body.text = _world_events_report()


func _update_warfront_panel() -> void:
	if _warfront_panel == null or _warfront_body == null:
		return
	_warfront_body.text = _warfront_report()


func _update_captains_desk_panel() -> void:
	if _captains_desk_panel == null or _captains_desk_body == null:
		return
	_captains_desk_body.text = _captains_desk_report()


func _update_map_legend_panel() -> void:
	if _map_legend_panel == null or _map_legend_body == null:
		return
	_map_legend_body.text = _map_legend_report()


func _update_ship_ledger_panel() -> void:
	if _ship_ledger_panel == null or _ship_ledger_body == null:
		return
	_ship_ledger_body.text = _ship_ledger_report()


func _ship_ledger_report() -> String:
	var hull := int(_ship_condition.get("hull", 100))
	var morale := int(_ship_condition.get("morale", 58))
	var kits := int(_ship_condition.get("repair_supplies", 3))
	var cargo_total := int(_cargo_hold.get("timber", 0)) + int(_cargo_hold.get("canvas", 0)) + int(_cargo_hold.get("powder", 0)) + int(_cargo_hold.get("cannon_parts", 0)) + int(_cargo_hold.get("contraband", 0))
	var crew_total := int(_ship_condition.get("sailors", 42)) + int(_ship_condition.get("gunners", 18)) + int(_ship_condition.get("carpenters", 6))
	var warning := "Ready"
	if hull < 45:
		warning = "Repair hull"
	elif kits <= 0:
		warning = "Restock kits"
	elif morale < 30:
		warning = "Rest crew"
	elif _active_contracts.is_empty():
		warning = "Find work"
	return "Hull %d%%   Kits %d/3\nMorale %d   Crew %d\nSilver %d   Cargo %d   Renown %d\nContracts %d/3   %s" % [
		hull,
		kits,
		morale,
		crew_total,
		int(_cargo_hold.get("silver", 0)),
		cargo_total,
		_captain_renown,
		_active_contracts.size(),
		warning,
	]


func _world_events_report() -> String:
	var lines: Array[String] = []
	lines.append("Strategic pulse")
	lines.append("- Active jobs: %d   Sea chances: %d   Moving fleets: %d   Region effects: %d" % [_active_contracts.size(), _sea_opportunities.size(), _parties.size(), _regional_effects.size()])
	lines.append("- Current waters: %s" % String(_current_sea_region().get("name", "Open sea")))
	lines.append("- Hotspot: %s" % _world_hotspot_line())
	if not _regional_effects.is_empty():
		lines.append("")
		lines.append("Regional effects")
		for i in range(mini(3, _regional_effects.size())):
			var effect: Dictionary = _regional_effects[i]
			lines.append("- %s: %s, %s pressure, %.1f days left" % [
				String(effect.get("region_name", "Waters")),
				String(effect.get("name", "Effect")),
				_signed_int_text(int(effect.get("pressure_delta", 0))),
				maxf(0.0, float(effect.get("expires_day", _campaign_day)) - _campaign_day),
			])
	if _encounter_log.is_empty():
		lines.append("")
		lines.append("Recent reports")
		lines.append("- No reports yet. Enter a port, hail a fleet or follow a sea marker.")
	else:
		lines.append("")
		lines.append("Recent reports")
		for i in range(mini(4, _encounter_log.size())):
			lines.append("- %s" % String(_encounter_log[i]))
	return "\n".join(lines)


func _warfront_report() -> String:
	var current := _current_sea_region()
	var hotspot := _warfront_hotspot_region()
	var current_line := "Current waters: open sea"
	if not current.is_empty():
		current_line = "Current waters: %s - %s" % [
			String(current.get("name", "Waters")),
			_warfront_region_state_line(current),
		]
	var hotspot_line := "Hotspot: none"
	if not hotspot.is_empty():
		hotspot_line = "Hotspot: %s - %s" % [
			String(hotspot.get("name", "Waters")),
			_warfront_region_state_line(hotspot),
		]
	var operation_line := ""
	if not _active_region_operation.is_empty():
		operation_line = "\n\nActive operation\n%s" % _active_region_operation_line({})
	return "%s\n%s%s\n\nLikely behavior\n%s\n\nCaptain's move\n%s" % [
		current_line,
		hotspot_line,
		operation_line,
		_warfront_behavior_line(hotspot if not hotspot.is_empty() else current),
		_warfront_player_order(hotspot if not hotspot.is_empty() else current),
	]


func _warfront_hotspot_region() -> Dictionary:
	var best := {}
	var best_score := -99999
	for region in _sea_regions:
		var pressure := _sea_region_pressure(region)
		var faction := String(region.get("faction", "Independent"))
		var power := int(_faction_power.get(faction, 45))
		var relation := int(_faction_reputation.get(faction, 0))
		var score := pressure + int(power * 0.25) + maxi(0, -relation)
		if _is_sea_region_focus(region):
			score += 16
		if score <= best_score:
			continue
		best_score = score
		best = region.duplicate(true)
	return best


func _warfront_region_state_line(region: Dictionary) -> String:
	if region.is_empty():
		return "uncharted drift"
	var faction := String(region.get("faction", "Independent"))
	var pressure := _sea_region_pressure(region)
	var relation := int(_faction_reputation.get(faction, 0))
	var power := int(_faction_power.get(faction, 45))
	return "%s control, pressure %d, power %d, relation %s" % [
		_warfront_control_label(faction, pressure, power),
		pressure,
		power,
		_signed_int_text(relation),
	]


func _warfront_control_label(faction: String, pressure: int, power: int) -> String:
	if faction == "Uncharted":
		return "fogbound"
	if faction == "Unclaimed" or faction == "Independent":
		return "contested" if pressure >= 55 else "loose"
	if power >= 72 and pressure >= 65:
		return "locked"
	if power <= 35:
		return "weakened"
	if pressure >= 70:
		return "militarized"
	if pressure <= 36:
		return "thin"
	return "held"


func _warfront_behavior_line(region: Dictionary) -> String:
	if region.is_empty():
		return "- No regional command pressure nearby."
	var faction := String(region.get("faction", "Independent"))
	var pressure := _sea_region_pressure(region)
	var relation := int(_faction_reputation.get(faction, 0))
	if pressure >= 72 and relation < 0:
		return "- Hostile patrols are likely to shadow or intercept.\n- Delivery routes through this water need repair kits and morale."
	if pressure >= 62:
		return "- Escorts and checkpoint fleets concentrate here.\n- Asking news or tracking jobs may pull you into guarded lanes."
	if pressure <= 36:
		return "- Control is thin; smugglers, salvage leads and raids become safer targets."
	return "- Mixed traffic: merchants, patrols and opportunists share these waters."


func _warfront_player_order(region: Dictionary) -> String:
	if region.is_empty():
		return "- Plot toward a harbor, then take a local incident or contract."
	var faction := String(region.get("faction", "Independent"))
	var pressure := _sea_region_pressure(region)
	var relation := int(_faction_reputation.get(faction, 0))
	if pressure >= 72 and relation < 0:
		return "- Avoid long routes, hit isolated couriers, or repair before engaging."
	if pressure >= 62:
		return "- Use ports for local work, then strike a marked fleet to lower sea power."
	if pressure <= 36:
		return "- Take sea opportunities and sell loot before another faction moves in."
	return "- Follow Captain's Desk: track active work or choose the nearest local lead."


func _captains_desk_report() -> String:
	var lines: Array[String] = []
	lines.append(_desk_priority_line())
	lines.append("")
	if not _active_region_operation.is_empty():
		lines.append("Active operation: %s" % _active_region_operation_line({}))
		lines.append("")
	lines.append("Route: %s" % _route_legend_line())
	lines.append("Next action: %s" % _desk_next_action())
	lines.append("")
	lines.append("Nearest port: %s" % _desk_nearest_port_line())
	lines.append("Nearest fleet: %s" % _desk_nearest_fleet_line())
	lines.append("Sea chance: %s" % _desk_nearest_opportunity_line())
	lines.append("Local lead: %s" % _desk_local_incident_line())
	lines.append("Region effect: %s" % _desk_regional_effect_line())
	lines.append("")
	lines.append("Ship state: %s" % _desk_ship_state_line())
	return "\n".join(lines)


func _desk_priority_line() -> String:
	if not _active_region_operation.is_empty():
		return "Priority: %s - %s" % [
			_region_operation_action_label(String(_active_region_operation.get("action", "operation"))),
			String(_active_region_operation.get("target_label", "marked target")),
		]
	if _nearby_encounter_index >= 0 and _nearby_encounter_index < _parties.size():
		var party: Dictionary = _parties[_nearby_encounter_index]
		return "Priority: close fleet contact - %s" % String(party.get("name", "Fleet"))
	if can_enter_selected_opportunity():
		var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
		return "Priority: investigate %s" % String(opportunity.get("name", "sea chance"))
	if can_enter_selected_region():
		return "Priority: enter %s anchorage" % String(get_selected_region().get("name", "Harbor"))
	if not _active_job_target().is_empty():
		var job := _active_job_target()
		return "Priority: %s" % String(job.get("summary", "active contract"))
	if _active_contracts.is_empty():
		return "Priority: find work at a harbor"
	return "Priority: keep sailing and watch pressure"


func _desk_next_action() -> String:
	if not _active_region_operation.is_empty():
		var action := String(_active_region_operation.get("action", ""))
		if action == "scout":
			return "Sail to the scout marker and investigate it to finish the regional order."
		if action == "patrol":
			return "Close with the marked fleet, then hail, inspect, demand surrender or engage."
		if action == "raid":
			return "Win the regional battle, then read the after-action report for pressure changes."
	if _nearby_encounter_index >= 0:
		return "Press Enter for Hail / Inspect / Surrender / Engage."
	if can_enter_selected_opportunity():
		return "Press Enter to resolve the sea opportunity."
	if can_enter_selected_region():
		return "Press Enter to open port districts."
	if _player_position.distance_to(_player_target) > 0.010:
		return "Hold course; reroute if a hostile badge crosses the route."
	if _active_contracts.is_empty():
		return "Enter a port, open Jobs, then Take Job and Track Job."
	return "Track an active job or select a fleet/port."


func _desk_nearest_port_line() -> String:
	var nearest: Dictionary = {}
	var best_distance := INF
	for location in _locations:
		var kind := String(location.get("kind", "port"))
		if kind != "port" and kind != "fort":
			continue
		if not _is_region_unlocked(location):
			continue
		var distance := _player_position.distance_to(location.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			nearest = location
	if nearest.is_empty():
		return "none charted"
	var settlement := _get_settlement_state(nearest)
	return "%s, %.1f days, %s / sec %d / pro %d" % [
		String(nearest.get("name", "Harbor")),
		best_distance * 12.0,
		String(settlement.get("access_label", "open")),
		int(settlement.get("security", 50)),
		int(settlement.get("prosperity", 50)),
	]


func _desk_nearest_fleet_line() -> String:
	if _parties.is_empty():
		return "none"
	var nearest: Dictionary = {}
	var best_distance := INF
	for party in _parties:
		var distance := _player_position.distance_to(party.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			nearest = party
	if nearest.is_empty():
		return "none"
	var relation_state := _get_party_relation_state(nearest)
	return "%s, %.1f days, %s, str %d" % [
		String(nearest.get("name", "Fleet")),
		best_distance * 12.0,
		String(relation_state.get("label", "wary")),
		int(nearest.get("strength", 0)),
	]


func _desk_nearest_opportunity_line() -> String:
	if _sea_opportunities.is_empty():
		return "none visible"
	var nearest: Dictionary = {}
	var best_distance := INF
	for opportunity in _sea_opportunities:
		var distance := _player_position.distance_to(opportunity.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			nearest = opportunity
	if nearest.is_empty():
		return "none visible"
	return "%s, %.1f days, %s risk" % [
		String(nearest.get("name", "Opportunity")),
		best_distance * 12.0,
		String(nearest.get("risk", "unknown")),
	]


func _desk_local_incident_line() -> String:
	var selected := get_selected_region()
	var kind := String(selected.get("kind", "port"))
	if kind != "port" and kind != "fort":
		return "select a harbor or fort"
	var incident := _local_incident_snapshot(selected)
	if not _local_incident_contract(selected).is_empty() or _local_incident_opportunity_index(selected) >= 0:
		return "%s active" % String(incident.get("title", "Local incident"))
	return "%s available" % String(incident.get("title", "Local incident"))


func _desk_regional_effect_line() -> String:
	if _regional_effects.is_empty():
		return "none"
	var best: Dictionary = {}
	var best_distance := INF
	for effect in _regional_effects:
		var distance := _player_position.distance_to(effect.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			best = effect
	if best.is_empty():
		return "none"
	return "%s in %s, %s pressure, %.1f days" % [
		String(best.get("name", "Effect")),
		String(best.get("region_name", "Waters")),
		_signed_int_text(int(best.get("pressure_delta", 0))),
		maxf(0.0, float(best.get("expires_day", _campaign_day)) - _campaign_day),
	]


func _desk_ship_state_line() -> String:
	var hull := int(_ship_condition.get("hull", 100))
	var morale := int(_ship_condition.get("morale", 58))
	var kits := int(_ship_condition.get("repair_supplies", 3))
	var cargo := int(_cargo_hold.get("timber", 0)) + int(_cargo_hold.get("canvas", 0)) + int(_cargo_hold.get("powder", 0)) + int(_cargo_hold.get("cannon_parts", 0)) + int(_cargo_hold.get("contraband", 0))
	var warning := _voyage_readiness_warning()
	return "hull %d, morale %d, kits %d/3, cargo %d - %s" % [hull, morale, kits, cargo, warning]


func _map_legend_report() -> String:
	return "Route: %s\nFleet badges: CHASE red, SHADOW gold, FLEE blue\nPorts: OPEN green, RESTRICTED gold, CLOSED red\nWaters: brighter borders mean higher pressure\nRegional effects: large soft rings reduce pressure for limited days\nMarkers: gold cross = contract, ring = selected/ready" % [_route_legend_line()]


func _route_legend_line() -> String:
	if _player_position.distance_to(_player_target) <= 0.010:
		return "no plotted course"
	if not _active_region_operation.is_empty() and _player_target.distance_to(_active_region_operation.get("target_position", _player_target)) < 0.022:
		return "%s operation course" % _region_operation_action_label(String(_active_region_operation.get("action", "operation"))).to_lower()
	for contract in _active_contracts:
		if String(contract.get("status", "active")) != "active":
			continue
		if String(contract.get("type", "hunt")) == "delivery":
			var destination := _find_location_by_id(String(contract.get("target_id", "")))
			if not destination.is_empty() and _player_target.distance_to(destination.get("position", _player_target)) < 0.018:
				return "gold delivery job course"
		else:
			var target_party := _find_party_by_name(String(contract.get("target", "")))
			if not target_party.is_empty() and _player_target.distance_to(target_party.get("position", _player_target)) < 0.018:
				return "red hunt job intercept"
	for opportunity in _sea_opportunities:
		if _player_target.distance_to(opportunity.get("position", _player_target)) < 0.018:
			return "%s sea opportunity" % String(opportunity.get("type", "salvage"))
	for party in _parties:
		if _player_target.distance_to(party.get("position", _player_target)) < 0.018:
			var relation_state := _get_party_relation_state(party)
			return "%s fleet contact" % String(relation_state.get("label", "wary")).to_lower()
	return "free sailing course"


func _world_hotspot_line() -> String:
	var best_region := "Open sea"
	var best_faction := "Independent"
	var best_pressure := -1
	for region in _sea_regions:
		var pressure := _sea_region_pressure(region)
		if pressure > best_pressure:
			best_pressure = pressure
			best_region = String(region.get("name", "Waters"))
			best_faction = String(region.get("faction", "Independent"))
	var relation := int(_faction_reputation.get(best_faction, 0))
	var power := int(_faction_power.get(best_faction, 45))
	return "%s: %s pressure %d/100, relation %d, sea power %d" % [best_region, best_faction, best_pressure, relation, power]


func _voyage_risk_report() -> String:
	if _player_position.distance_to(_player_target) <= 0.010:
		return "Voyage Risk\n- No plotted route."
	var waters := _current_sea_region()
	var pressure := _region_pressure_for_faction(String(waters.get("faction", "Independent"))) if not waters.is_empty() else 20
	var route_days := _player_position.distance_to(_player_target) * 12.0
	var fleet_risk := _route_fleet_risk()
	var readiness := _voyage_readiness_warning()
	return "Voyage Risk\n- Route: %.1f days, pressure %d/100\n- Fleet screen: %s\n- Readiness: %s" % [
		route_days,
		pressure,
		fleet_risk,
		readiness,
	]


func _route_fleet_risk() -> String:
	var best: Dictionary = {}
	var best_distance := INF
	for party in _parties:
		var party_pos: Vector2 = party.get("position", Vector2.ZERO)
		var route_distance := _distance_to_segment(party_pos, _player_position, _player_target)
		if route_distance > 0.075:
			continue
		if route_distance < best_distance:
			best_distance = route_distance
			best = party
	if best.is_empty():
		return "clear route; no close fleet screen"
	var relation_state := _get_party_relation_state(best)
	return "%s, %s %s, %.1f days off route" % [
		String(best.get("name", "Fleet")),
		String(relation_state.get("label", "Wary")),
		String(best.get("intent", relation_state.get("effective_stance", "sailing route"))),
		best_distance * 12.0,
	]


func _voyage_readiness_warning() -> String:
	var hull := int(_ship_condition.get("hull", 100))
	var kits := int(_ship_condition.get("repair_supplies", 3))
	var morale := int(_ship_condition.get("morale", 58))
	if hull < 45:
		return "repair hull before taking pressure routes"
	if kits <= 0:
		return "no repair kits; visit shipyard if combat likely"
	if morale < 30:
		return "low morale; tavern rest recommended"
	return "fit to sail"


func _campaign_orders_report() -> String:
	var orders: Array[String] = []
	if not _active_region_operation.is_empty():
		orders.append("1. Active operation: %s in %s - %s" % [
			_region_operation_action_label(String(_active_region_operation.get("action", "operation"))),
			String(_active_region_operation.get("region_name", "Waters")),
			String(_active_region_operation.get("target_label", "marked target")),
		])
	else:
		orders.append("1. Regional operation: click any sea region, then Scout, Patrol or Raid.")
	var job := _active_job_target()
	if not job.is_empty():
		orders.append("2. Active job: %s - %s" % [String(job.get("target", "Objective")), String(job.get("next", "Follow the marked route."))])
	else:
		orders.append("2. Find work: enter a port, open Contract Board, then Track Job.")

	var opportunity := _nearest_opportunity_order()
	if not opportunity.is_empty():
		orders.append("3. Sea chance: %s" % opportunity)
	else:
		orders.append("3. Sea chance: none visible; ask news in port to reveal more.")

	var fleet := _nearest_fleet_order()
	if not fleet.is_empty():
		orders.append("4. Fleet decision: %s" % fleet)
	else:
		orders.append("4. Fleet decision: no contact; sail toward busy waters.")
	return "Captain's Orders\n%s" % "\n".join(orders)


func _nearest_opportunity_order() -> String:
	if _sea_opportunities.is_empty():
		return ""
	var best: Dictionary = {}
	var best_distance := INF
	for opportunity in _sea_opportunities:
		var distance := _player_position.distance_to(opportunity.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			best = opportunity
	if best.is_empty():
		return ""
	var state := "press Enter now" if best_distance <= OPPORTUNITY_DISTANCE else "click to plot course"
	return "%s, %s risk, %s reward, %.1f days - %s" % [
		String(best.get("name", "Opportunity")),
		String(best.get("risk", "unknown")),
		String(best.get("reward", "unknown")),
		best_distance * 12.0,
		state,
	]


func _nearest_fleet_order() -> String:
	if _parties.is_empty():
		return ""
	var best: Dictionary = {}
	var best_distance := INF
	for party in _parties:
		var distance := _player_position.distance_to(party.get("position", _player_position))
		if distance < best_distance:
			best_distance = distance
			best = party
	if best.is_empty():
		return ""
	var relation_state := _get_party_relation_state(best)
	var close_action := "open encounter choices" if best_distance <= ENCOUNTER_DISTANCE else "click to intercept"
	return "%s, %s %s, strength %d, %.1f days - %s" % [
		String(best.get("name", "Fleet")),
		String(relation_state.get("label", "Wary")),
		String(best.get("role", "Fleet")),
		int(best.get("strength", 0)),
		best_distance * 12.0,
		close_action,
	]


func _campaign_primary_target() -> Dictionary:
	if _nearby_encounter_index >= 0 and _nearby_encounter_index < _parties.size():
		var party: Dictionary = _parties[_nearby_encounter_index]
		var relation_state := _get_party_relation_state(party)
		return {
			"title": "Encounter At Hand",
			"summary": "%s is close enough for parley, inspection, surrender demand or attack." % String(party.get("name", "Fleet")),
			"target": "%s - %s, strength %d" % [
				String(relation_state.get("label", "Wary")),
				String(party.get("role", "Fleet")),
				int(party.get("strength", 0)),
			],
			"distance": "%.1f days" % (_player_position.distance_to(party.get("position", _player_position)) * 12.0),
			"next": "Press Enter or click the fleet to open encounter choices.",
		}
	if not _active_region_operation.is_empty():
		var action := String(_active_region_operation.get("action", "operation"))
		var target_position: Vector2 = _active_region_operation.get("target_position", _player_position)
		return {
			"title": "Active Regional Operation",
			"summary": "%s in %s is now the main campaign objective." % [
				_region_operation_action_label(action),
				String(_active_region_operation.get("region_name", "Waters")),
			],
			"target": String(_active_region_operation.get("target_label", "marked target")),
			"distance": "%.1f days" % (_player_position.distance_to(target_position) * 12.0),
			"next": _desk_next_action(),
		}
	var job := _active_job_target()
	if not job.is_empty():
		return job
	if _selected_party_index >= 0 and _selected_party_index < _parties.size():
		var party: Dictionary = _parties[_selected_party_index]
		var relation_state := _get_party_relation_state(party)
		return {
			"title": "Tracked Fleet",
			"summary": "%s is selected on the campaign map." % String(party.get("name", "Fleet")),
			"target": "%s - %s, %s" % [
				String(relation_state.get("faction", "Unknown")),
				String(relation_state.get("label", "Wary")),
				String(party.get("cargo", "unknown cargo")),
			],
			"distance": "%.1f days" % (_player_position.distance_to(party.get("position", _player_position)) * 12.0),
			"next": "Close distance, then Hail, Inspect or Engage.",
		}
	if _selected_opportunity_index >= 0 and _selected_opportunity_index < _sea_opportunities.size():
		var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
		var distance_to_opportunity := _player_position.distance_to(opportunity.get("position", _player_position)) * 12.0
		return {
			"title": "Sea Opportunity",
			"summary": String(opportunity.get("description", "A visible chance waits at sea.")),
			"target": "%s - %s reward" % [String(opportunity.get("name", "Opportunity")), String(opportunity.get("reward", "unknown"))],
			"distance": "%.1f days" % distance_to_opportunity,
			"next": "Sail close and press Enter to investigate, or reroute if the risk is not worth it.",
		}
	var selected := get_selected_region()
	var distance := _player_position.distance_to(selected.get("position", _player_position)) * 12.0
	if _player_target.distance_to(selected.get("position", _player_target)) < 0.018:
		return {
			"title": "Course Plotted",
			"summary": "Your ship is sailing toward %s." % String(selected.get("name", "Location")),
			"target": "%s - %s" % [String(selected.get("faction", "Unknown")), String(selected.get("mood", ""))],
			"distance": "%.1f days" % distance,
			"next": "Press Enter when close to open the port or sea encounter.",
		}
	if _player_target.distance_to(_player_position) > 0.010:
		return {
			"title": "Open Sea Course",
			"summary": "A free sailing route is plotted across the campaign map.",
			"target": _campaign_target_label(),
			"distance": "%.1f days" % (_player_position.distance_to(_player_target) * 12.0),
			"next": "Watch nearby fleets and reroute if patrol pressure rises.",
		}
	return {
		"title": "Awaiting Orders",
		"summary": "Pick a port, fleet, job target or open water route.",
		"target": String(selected.get("name", "Location")),
		"distance": "%.1f days" % distance,
		"next": "Left-click to plot a route. Use bottom panels for jobs, cargo and crew.",
	}


func _active_job_target() -> Dictionary:
	for contract in _active_contracts:
		if String(contract.get("status", "active")) != "active":
			continue
		if String(contract.get("type", "hunt")) == "delivery":
			var destination := _find_location_by_id(String(contract.get("target_id", "")))
			if destination.is_empty():
				continue
			return {
				"title": "Active Delivery",
				"summary": "Carry dispatches from %s for %d silver." % [String(contract.get("issuer", "Harbor")), int(contract.get("reward", 0))],
				"target": String(destination.get("name", "Port")),
				"distance": "%.1f days" % (_player_position.distance_to(destination.get("position", _player_position)) * 12.0),
				"next": "Sail to the marked port and enter anchorage to complete the job.",
			}
		var party := _find_party_by_name(String(contract.get("target", "")))
		if party.is_empty():
			continue
		return {
			"title": "Active Hunt",
			"summary": "Hunt contract from %s for %d silver." % [String(contract.get("issuer", "Harbor")), int(contract.get("reward", 0))],
			"target": "%s - strength %d" % [String(party.get("name", "Fleet")), int(party.get("strength", 0))],
			"distance": "%.1f days" % (_player_position.distance_to(party.get("position", _player_position)) * 12.0),
			"next": "Track, intercept, then defeat or capture the marked fleet.",
		}
	return {}


func _set_bottom_button_active(section: String) -> void:
	for key in _bottom_buttons.keys():
		var button := _bottom_buttons[key] as Button
		if button != null:
			button.modulate = Color(1.0, 0.92, 0.74) if String(key) == section else Color(1.0, 1.0, 1.0)


func _nearest_party_report() -> String:
	var entries: Array[Dictionary] = []
	for party in _parties:
		var distance := _player_position.distance_to(party.get("position", Vector2.ZERO))
		var relation_state := _get_party_relation_state(party)
		entries.append({
			"name": String(party.get("name", "Fleet")),
			"distance": distance,
			"strength": int(party.get("strength", 0)),
			"faction": String(relation_state.get("faction", "Unknown")),
			"relation": String(relation_state.get("label", "Wary")),
			"role": String(party.get("role", "Fleet")),
			"intent": String(party.get("intent", relation_state.get("effective_stance", "sailing route"))),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0)))
	var lines: Array[String] = []
	for i in range(mini(4, entries.size())):
		var entry := entries[i]
		lines.append("- %s: %.1f days, %s, %s, %s, strength %d" % [
			String(entry.get("name", "Fleet")),
			float(entry.get("distance", 0.0)) * 12.0,
			String(entry.get("relation", "Wary")),
			String(entry.get("role", "Fleet")),
			String(entry.get("intent", "sailing route")),
			int(entry.get("strength", 0)),
		])
	var output := "Nearest moving parties"
	for line in lines:
		output += "\n"
		output += line
	return output


func _selected_party_report() -> String:
	if _selected_party_index < 0 or _selected_party_index >= _parties.size():
		return ""
	var party: Dictionary = _parties[_selected_party_index]
	var relation_state := _get_party_relation_state(party)
	var distance := _player_position.distance_to(party.get("position", Vector2.ZERO)) * 12.0
	var action_line := "Actions: press Enter or click fleet for choices" if can_enter_selected_party() else "Actions: Engage plots intercept, Hail closes distance"
	return "Selected fleet: %s\nFaction: %s - %s (%d)\nRole: %s\nCargo: %s\nIntent: %s -> %s\nStrength: %d\nDistance: %.1f days\n%s\n" % [
		String(party.get("name", "Fleet")),
		String(relation_state.get("faction", "Unknown")),
		String(relation_state.get("label", "Wary")),
		int(relation_state.get("reputation", 0)),
		String(party.get("role", "Fleet")),
		String(party.get("cargo", "unknown")),
		String(party.get("intent", "sailing route")),
		String(relation_state.get("effective_stance", party.get("stance", "neutral"))),
		int(party.get("strength", 0)),
		distance,
		action_line,
	]


func _current_encounter_line() -> String:
	if _nearby_encounter_index < 0 or _nearby_encounter_index >= _parties.size():
		return ""
	var party: Dictionary = _parties[_nearby_encounter_index]
	return "\nClose fleet: %s - press Enter for encounter choices" % String(party.get("name", "Fleet"))


func _opportunity_report() -> String:
	if _sea_opportunities.is_empty():
		return "Sea opportunities\n- None currently visible"
	var output := "Sea opportunities"
	for i in range(mini(3, _sea_opportunities.size())):
		var opportunity: Dictionary = _sea_opportunities[i]
		output += "\n- %s: %s, %.1f days" % [
			String(opportunity.get("name", "Opportunity")),
			String(opportunity.get("risk", "unknown")),
			_player_position.distance_to(opportunity.get("position", _player_position)) * 12.0,
		]
	return output


func _current_waters_report() -> String:
	var region := _current_sea_region()
	if region.is_empty():
		return "Waters: Open sea\nPressure: Independent drift"
	var faction := String(region.get("faction", "Independent"))
	var reputation := int(_faction_reputation.get(faction, 0))
	var power := int(_faction_power.get(faction, 45))
	var pressure := _region_pressure_for_faction(faction)
	return "Waters: %s\nController: %s - %s (%d)\nSea power: %d/100\nPressure: %d/100" % [
		String(region.get("name", "Open Sea")),
		faction,
		_reputation_label(reputation),
		reputation,
		power,
		pressure,
	]


func _is_sea_region_focus(region: Dictionary) -> bool:
	var current := _current_sea_region()
	if not current.is_empty() and String(current.get("name", "")) == String(region.get("name", "")):
		return true
	var selected := get_selected_region()
	if String(selected.get("kind", "")) == "sea" and String(selected.get("faction", "")) == String(region.get("faction", "")):
		return true
	if _player_target != _player_position and _point_in_polygon(_player_target, region.get("points", [])):
		return true
	return false


func _campaign_decision_markers() -> Array:
	var markers: Array[Dictionary] = []
	if not _active_region_operation.is_empty():
		var action := String(_active_region_operation.get("action", "operation"))
		var color := Color(0.86, 0.64, 1.0) if action == "raid" else (Color(0.46, 0.78, 1.0) if action == "patrol" else Color(0.58, 1.0, 0.70))
		markers.append({
			"position": _active_region_operation.get("target_position", _player_target),
			"label": _region_operation_action_label(action).to_upper(),
			"color": color,
			"radius": 43.0,
		})
	if _nearby_encounter_index >= 0 and _nearby_encounter_index < _parties.size():
		var party: Dictionary = _parties[_nearby_encounter_index]
		markers.append({
			"position": party.get("position", _player_position),
			"label": "ENCOUNTER READY",
			"color": Color(1.0, 0.34, 0.22),
			"radius": 36.0,
		})
	elif _selected_party_index >= 0 and _selected_party_index < _parties.size():
		var party: Dictionary = _parties[_selected_party_index]
		var relation_state := _get_party_relation_state(party)
		markers.append({
			"position": party.get("position", _player_target),
			"label": "%s FLEET" % String(relation_state.get("label", "WARY")).to_upper(),
			"color": _campaign_route_color(),
			"radius": 33.0,
		})

	if _selected_opportunity_index >= 0 and _selected_opportunity_index < _sea_opportunities.size():
		var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
		markers.append({
			"position": opportunity.get("position", _player_target),
			"label": "SEA CHANCE",
			"color": _opportunity_color(String(opportunity.get("type", "salvage"))),
			"radius": 31.0,
		})
	elif can_enter_selected_region():
		var selected := get_selected_region()
		markers.append({
			"position": selected.get("position", _player_target),
			"label": "ANCHORAGE READY",
			"color": Color(0.54, 1.0, 0.66),
			"radius": 34.0,
		})
	elif _player_position.distance_to(_player_target) > 0.010:
		markers.append({
			"position": _player_target,
			"label": _campaign_target_label().to_upper(),
			"color": _campaign_route_color(),
			"radius": 30.0,
		})
	return markers


func _campaign_target_label() -> String:
	if not _active_region_operation.is_empty() and _player_target.distance_to(_active_region_operation.get("target_position", _player_target)) < 0.022:
		return String(_active_region_operation.get("target_label", "Regional operation"))
	if _selected_party_index >= 0 and _selected_party_index < _parties.size():
		var party: Dictionary = _parties[_selected_party_index]
		if _player_target.distance_to(party.get("position", _player_target)) < 0.018:
			return String(party.get("name", "Fleet"))
	if _selected_opportunity_index >= 0 and _selected_opportunity_index < _sea_opportunities.size():
		var opportunity: Dictionary = _sea_opportunities[_selected_opportunity_index]
		if _player_target.distance_to(opportunity.get("position", _player_target)) < 0.018:
			return String(opportunity.get("name", "Sea opportunity"))
	for contract in _active_contracts:
		if String(contract.get("status", "active")) != "active":
			continue
		if String(contract.get("type", "hunt")) == "delivery":
			var destination := _find_location_by_id(String(contract.get("target_id", "")))
			if not destination.is_empty() and _player_target.distance_to(destination.get("position", _player_target)) < 0.018:
				return "Job: %s" % String(destination.get("name", "Port"))
		else:
			var target_party := _find_party_by_name(String(contract.get("target", "")))
			if not target_party.is_empty() and _player_target.distance_to(target_party.get("position", _player_target)) < 0.018:
				return "Job: %s" % String(target_party.get("name", "Fleet"))
	for location in _locations:
		if _player_target.distance_to(location.get("position", _player_target)) < 0.018:
			return String(location.get("name", "Location"))
	return "Sailing target"


func _campaign_route_color() -> Color:
	if not _active_region_operation.is_empty() and _player_target.distance_to(_active_region_operation.get("target_position", _player_target)) < 0.022:
		var action := String(_active_region_operation.get("action", "operation"))
		if action == "raid":
			return Color(0.86, 0.64, 1.0)
		if action == "patrol":
			return Color(0.46, 0.78, 1.0)
		return Color(0.58, 1.0, 0.70)
	for contract in _active_contracts:
		if String(contract.get("status", "active")) != "active":
			continue
		if String(contract.get("type", "hunt")) == "delivery":
			var destination := _find_location_by_id(String(contract.get("target_id", "")))
			if not destination.is_empty() and _player_target.distance_to(destination.get("position", _player_target)) < 0.018:
				return Color(1.0, 0.74, 0.25)
		else:
			var target_party := _find_party_by_name(String(contract.get("target", "")))
			if not target_party.is_empty() and _player_target.distance_to(target_party.get("position", _player_target)) < 0.018:
				return Color(1.0, 0.42, 0.22)
	for opportunity in _sea_opportunities:
		if _player_target.distance_to(opportunity.get("position", _player_target)) < 0.018:
			return _opportunity_color(String(opportunity.get("type", "salvage")))
	for party in _parties:
		if _player_target.distance_to(party.get("position", _player_target)) < 0.018:
			var relation_state := _get_party_relation_state(party)
			var relation := int(relation_state.get("reputation", 0))
			if relation < -10:
				return Color(1.0, 0.32, 0.22)
			if relation > 15:
				return Color(0.36, 0.78, 1.0)
			return Color(1.0, 0.82, 0.36)
	return Color(1.0, 0.86, 0.42)


func _campaign_route_status() -> String:
	if _player_target.distance_to(_player_position) <= 0.010:
		return ""
	var eta := _player_position.distance_to(_player_target) * 12.0
	var waters := _current_sea_region()
	var pressure := _region_pressure_for_faction(String(waters.get("faction", "Independent"))) if not waters.is_empty() else 20
	var verb := "route"
	if _nearby_encounter_index >= 0:
		verb = "encounter ready"
	elif can_enter_selected_opportunity():
		verb = "opportunity ready"
	elif can_enter_selected_region():
		verb = "anchorage ready"
	elif not _active_job_target().is_empty():
		verb = "job course"
	return "%s - %.1f days, pressure %d" % [verb, eta, pressure]


func _update_region_pressure(delta: float) -> void:
	var region := _current_sea_region()
	if region.is_empty():
		_pressure_timer = maxf(_pressure_timer - delta, 0.0)
		_active_pressure_faction = ""
		return
	var faction := String(region.get("faction", "Independent"))
	var pressure := _region_pressure_for_faction(faction)
	_pressure_timer += delta * float(pressure) / 100.0
	if _pressure_timer < 3.5:
		return
	_pressure_timer = 0.0
	if pressure >= 72:
		_encounter_log.push_front("%s patrol pressure is rising" % faction)
		_active_pressure_faction = faction
	elif pressure >= 55:
		_encounter_log.push_front("%s waters feel watched" % faction)
		_active_pressure_faction = faction
	if _encounter_log.size() > 8:
		_encounter_log.resize(8)


func _update_travel_fatigue(delta: float) -> void:
	_fatigue_timer += delta
	if _fatigue_timer < 7.0:
		return
	_fatigue_timer = 0.0
	var morale := int(_ship_condition.get("morale", 58))
	if morale <= 18:
		return
	_ship_condition["morale"] = morale - 1
	if morale == 25:
		_encounter_log.push_front("Desertion risk: crew morale is critical")
	if morale == 35:
		_encounter_log.push_front("Crew morale is wearing thin")
		if _encounter_log.size() > 8:
			_encounter_log.resize(8)


func _region_pressure_for_faction(faction: String) -> int:
	var reputation := int(_faction_reputation.get(faction, 0))
	var power := int(_faction_power.get(faction, 45))
	return clampi(42 - reputation + int(round(float(power) * 0.22)), 10, 95)


func _sea_region_pressure(region: Dictionary) -> int:
	return clampi(_region_pressure_for_faction(String(region.get("faction", "Independent"))) + _regional_effect_pressure_delta(region), 5, 95)


func _regional_effect_pressure_delta(region: Dictionary) -> int:
	if region.is_empty():
		return 0
	var region_name := String(region.get("name", ""))
	var delta := 0
	for effect in _regional_effects:
		if String(effect.get("region_name", "")) == region_name:
			delta += int(effect.get("pressure_delta", 0))
	return clampi(delta, -24, 18)


func _sea_region_relation(region: Dictionary) -> int:
	return int(_faction_reputation.get(String(region.get("faction", "Independent")), 0))


func _sea_region_power(region: Dictionary) -> int:
	return int(_faction_power.get(String(region.get("faction", "Independent")), 45))


func _current_sea_region() -> Dictionary:
	for region in _sea_regions:
		var points: Array = region.get("points", [])
		if _point_in_polygon(_player_position, points):
			return region.duplicate(true)
	return {}


func _recent_encounter_report() -> String:
	if _encounter_log.is_empty():
		return "Recent sightings\n- None"
	var output := "Recent sightings"
	for entry in _encounter_log:
		output += "\n- %s" % String(entry)
	return output


func _defeated_party_report() -> String:
	if _defeated_parties.is_empty():
		return "Resolved encounters\n- None"
	var output := "Resolved encounters"
	for i in range(mini(4, _defeated_parties.size())):
		var entry: Dictionary = _defeated_parties[i]
		output += "\n- %s: %s on April %d" % [
			String(entry.get("name", "Fleet")),
			String(entry.get("outcome", "defeated")),
			int(entry.get("day", 1)),
		]
	return output


func _cargo_hold_report() -> String:
	return "Cargo hold\nHull condition: %d%%\nRepair kits: %d/3\nSpare timber: %d\nCanvas rolls: %d\nPowder barrels: %d\nSalvaged cannon parts: %d\nSilver: %d\nContraband: %d\n\n%s" % [
		int(_ship_condition.get("hull", 100)),
		int(_ship_condition.get("repair_supplies", 3)),
		int(_cargo_hold.get("timber", 0)),
		int(_cargo_hold.get("canvas", 0)),
		int(_cargo_hold.get("powder", 0)),
		int(_cargo_hold.get("cannon_parts", 0)),
		int(_cargo_hold.get("silver", 0)),
		int(_cargo_hold.get("contraband", 0)),
		_market_report(),
	]


func _cargo_slot_count() -> int:
	var count := 0
	for key in ["timber", "canvas", "powder", "cannon_parts", "contraband"]:
		count += int(ceil(float(int(_cargo_hold.get(key, 0))) / 3.0))
	return clampi(count, 0, 18)


func _camp_report() -> String:
	var service_state := "Services available" if _can_use_port_services() else "Reach a harbor or fort anchorage for services"
	var settlement := _get_settlement_state(get_selected_region())
	return "Settlement menu\n%s\nAccess: %s\nSecurity: %s (%d)\nProsperity: %s (%d)\n\nServices: Repair, Resupply, Rest, Buy Wood, Sell Loot, Hire Crew\nHarbor office: Take Job, Track Job, Ask News\nFleet actions: select a fleet, then Hail or Engage\n\nHull: %d%%\nRepair kits: %d/3\nCrew morale: %d\nCampaign speed: %.2f\nDaily wages: 6 silver\nHire crew: %d silver\n\n%s" % [
		service_state,
		String(settlement.get("access_label", "open")),
		String(settlement.get("security_label", "watched")),
		int(settlement.get("security", 50)),
		String(settlement.get("prosperity_label", "steady")),
		int(settlement.get("prosperity", 50)),
		int(_ship_condition.get("hull", 100)),
		int(_ship_condition.get("repair_supplies", 3)),
		int(_ship_condition.get("morale", 58)),
		_campaign_party_speed(),
		_hire_crew_cost(),
		_contract_report(),
	]


func _contract_report() -> String:
	var output := "Contracts"
	if _active_contracts.is_empty():
		output += "\n- Active: none"
	for contract in _active_contracts:
		var is_delivery := String(contract.get("type", "hunt")) == "delivery"
		var target := _find_location_by_id(String(contract.get("target_id", ""))) if is_delivery else _find_party_by_name(String(contract.get("target", "")))
		var distance_text := "unknown waters"
		if not target.is_empty():
			distance_text = "%.1f days" % (_player_position.distance_to(target.get("position", _player_position)) * 12.0)
		output += "\n- %s %s: %s from %s, %s, reward %d silver" % [
			"Delivery" if is_delivery else "Hunt",
			String(contract.get("status", "active")),
			String(contract.get("target", "Fleet")),
			String(contract.get("issuer", "Harbor")),
			distance_text,
			int(contract.get("reward", 0)),
		]
	if not _completed_contracts.is_empty():
		output += "\nCompleted"
		for i in range(mini(3, _completed_contracts.size())):
			var done: Dictionary = _completed_contracts[i]
			var local_title := String(done.get("local_title", ""))
			var prefix := "%s: " % local_title if not local_title.is_empty() else ""
			output += "\n- %s%s, reward %d silver" % [
				prefix,
				String(done.get("target", "Fleet")),
				int(done.get("reward", 0)),
			]
	return output


func _job_board_report() -> String:
	var location := get_selected_region()
	var faction := String(location.get("faction", "Independent"))
	var lines: Array[String] = []
	lines.append("Active contracts %d/3" % _active_contracts.size())
	if _active_contracts.is_empty():
		lines.append("[Empty Ledger]")
		lines.append("No active work. Take Job creates a visible target and Track Job plots a course.")
	else:
		for i in range(_active_contracts.size()):
			lines.append(_job_card_text(_active_contracts[i], i + 1))
	lines.append("")
	lines.append("Available offer")
	lines.append(_next_job_offer_preview(location, faction))
	lines.append("")
	lines.append("Actions")
	lines.append("- Take Job: accepts the offer and creates a map target.")
	lines.append("- Track Job: plots the active contract route on Captain's Course.")
	lines.append("- Ask News: buys a fleet lead if you need a target before committing.")
	return "\n".join(lines)


func _local_incident_report(location: Dictionary) -> String:
	var incident := _local_incident_snapshot(location)
	var existing_contract := _local_incident_contract(location)
	var existing_opportunity_index := _local_incident_opportunity_index(location)
	var status := "available"
	if not existing_contract.is_empty():
		status = "active contract - button tracks target"
	elif existing_opportunity_index >= 0:
		status = "marked at sea - button tracks marker"
	return "Local incident\n%s\nStatus: %s\nPressure: %s\nReward: %s\nAction: %s" % [
		String(incident.get("title", "Harbor lead")),
		status,
		String(incident.get("description", "Local captains are asking for help.")),
		String(incident.get("reward_text", "%d silver" % int(incident.get("reward", 0)))),
		String(incident.get("action", "Accept to create a visible map objective.")),
	]


func _local_incident_snapshot(location: Dictionary) -> Dictionary:
	var state := _get_settlement_state(location)
	var security := int(state.get("security", 50))
	var prosperity := int(state.get("prosperity", 50))
	var faction := String(location.get("faction", "Independent"))
	var location_name := String(location.get("name", "Harbor"))
	if security <= 46:
		var target := _find_contract_target(faction)
		if not target.is_empty():
			var reward := _contract_reward_for_target(target, faction) + maxi(4, int((52 - security) / 2))
			return {
				"type": "hunt",
				"title": "%s Harbor Watch Bounty" % location_name,
				"description": "Security is low; officials want a nearby threat removed before trade worsens.",
				"target_party": target,
				"reward": reward,
				"reward_text": "%d silver, renown and local security relief" % reward,
				"action": "Accept to mark %s as a hunt target." % String(target.get("name", "Fleet")),
			}
	if prosperity <= 54:
		var destination := _find_delivery_destination(String(location.get("id", "")), faction)
		if not destination.is_empty():
			var reward := 22 + int(_player_position.distance_to(destination.get("position", _player_position)) * 86.0) + maxi(0, int((58 - prosperity) / 3))
			return {
				"type": "delivery",
				"title": "%s Shortage Run" % location_name,
				"description": "Prosperity is strained; the harbor needs dispatches and supply promises carried to another port.",
				"destination": destination,
				"reward": reward,
				"reward_text": "%d silver and issuer trust" % reward,
				"action": "Accept to plot a delivery route to %s." % String(destination.get("name", "Port")),
			}
	return {
		"type": "opportunity",
		"title": "%s Offshore Lead" % location_name,
		"description": "Dockside pilots report a fresh lead just outside the sea lane.",
		"opportunity_type": "mystery" if security < 62 else "salvage",
		"risk": "medium" if security < 62 else "low",
		"reward_text": "supplies, silver or crew depending on the find",
		"action": "Accept to place a new sea opportunity marker near the harbor.",
	}


func _local_incident_button_label() -> String:
	var location := get_selected_region()
	if not _local_incident_contract(location).is_empty() or _local_incident_opportunity_index(location) >= 0:
		return "Track Local Incident"
	var incident := _local_incident_snapshot(location)
	return "Accept Local  %s" % String(incident.get("type", "lead")).capitalize()


func _local_incident_button_disabled() -> bool:
	var location := get_selected_region()
	if not _local_incident_contract(location).is_empty() or _local_incident_opportunity_index(location) >= 0:
		return false
	var incident := _local_incident_snapshot(location)
	return String(incident.get("type", "opportunity")) != "opportunity" and _active_contracts.size() >= 3


func _local_incident_contract(location: Dictionary) -> Dictionary:
	var origin_id := String(location.get("id", ""))
	for contract in _active_contracts:
		if String(contract.get("status", "active")) == "active" and String(contract.get("local_origin", "")) == origin_id:
			return contract.duplicate(true)
	return {}


func _local_incident_opportunity_index(location: Dictionary) -> int:
	var incident_id := _local_incident_id(location)
	for i in range(_sea_opportunities.size()):
		var opportunity: Dictionary = _sea_opportunities[i]
		if String(opportunity.get("id", "")) == incident_id:
			return i
	return -1


func _local_incident_id(location: Dictionary) -> String:
	return "local_%s" % String(location.get("id", "harbor"))


func _local_incident_position(location: Dictionary) -> Vector2:
	var index := _location_index_by_id(String(location.get("id", "")))
	var base: Vector2 = location.get("position", _player_position)
	var offset := Vector2(0.038 * float((index % 3) - 1), -0.046 + 0.024 * float(index % 4))
	return _clamp_map_position(base + offset)


func _location_index_by_id(location_id: String) -> int:
	for i in range(_locations.size()):
		var location: Dictionary = _locations[i]
		if String(location.get("id", "")) == location_id:
			return i
	return 0


func _job_card_text(contract: Dictionary, index: int) -> String:
	var is_delivery := String(contract.get("type", "hunt")) == "delivery"
	var target := _find_location_by_id(String(contract.get("target_id", ""))) if is_delivery else _find_party_by_name(String(contract.get("target", "")))
	var distance_text := "unknown"
	var status_text := "target missing"
	if not target.is_empty():
		distance_text = "%.1f days" % (_player_position.distance_to(target.get("position", _player_position)) * 12.0)
		status_text = "enter destination port" if is_delivery else "intercept and defeat/capture"
	var local_line := "\nLocal: %s" % String(contract.get("local_title", "")) if not String(contract.get("local_title", "")).is_empty() else ""
	var kind := "DELIVERY" if is_delivery else "HUNT"
	return "[%d] %s  %s%s\nTarget: %s\nIssuer: %s   Distance: %s   Reward: %d silver\nNext: %s" % [
		index,
		kind,
		String(contract.get("status", "active")).to_upper(),
		local_line,
		String(target.get("name", contract.get("target", "Unknown"))),
		String(contract.get("issuer", "Harbor")),
		distance_text,
		int(contract.get("reward", 0)),
		status_text,
	]


func _next_job_offer_preview(location: Dictionary, faction: String) -> String:
	if _active_contracts.size() >= 3:
		return "[Board Full]\nComplete or resolve an active contract before taking more work."
	var next_is_delivery := (_contract_sequence + 1) % 2 == 0
	if next_is_delivery:
		var destination := _find_delivery_destination(String(location.get("id", "")), faction)
		if destination.is_empty():
			return "[Delivery]\nNo safe destination available from this harbor."
		var reward := 18 + int(_player_position.distance_to(destination.get("position", _player_position)) * 80.0) + maxi(0, int(-int(_faction_reputation.get(faction, 0)) / 5.0))
		return "[Delivery]\nDispatches to %s\nDistance: %.1f days   Reward: %d silver\nRisk: port access and moving patrols" % [
			String(destination.get("name", "Port")),
			_player_position.distance_to(destination.get("position", _player_position)) * 12.0,
			reward,
		]
	var target := _find_contract_target(faction)
	if target.is_empty():
		return "[Hunt]\nNo suitable hostile or rival fleet currently visible."
	var reward := 24 + int(float(int(target.get("strength", 40))) / 2.0)
	return "[Hunt]\nTarget: %s\nRole: %s   Strength: %d   Reward: %d silver\nRisk: naval combat, but capture pays better." % [
		String(target.get("name", "Fleet")),
		String(target.get("role", "Fleet")),
		int(target.get("strength", 0)),
		reward,
	]


func _market_report() -> String:
	var market := _get_market_snapshot()
	var buy: Dictionary = market.get("buy_prices", {})
	var sell: Dictionary = market.get("sell_prices", {})
	var state := "open" if bool(market.get("available", false)) else "unavailable"
	return "Market %s at %s\nAccess: %s\nSecurity: %s (%d), Prosperity: %s (%d)\nBuy timber/canvas/powder: %d/%d/%d silver\nSell contraband/cannon parts: %d/%d silver" % [
		state,
		String(market.get("location", "Open Sea")),
		String(market.get("access_label", "open")),
		String(market.get("security_label", "watched")),
		int(market.get("security", 50)),
		String(market.get("prosperity_label", "steady")),
		int(market.get("prosperity", 50)),
		int(buy.get("timber", 0)),
		int(buy.get("canvas", 0)),
		int(buy.get("powder", 0)),
		int(sell.get("contraband", 0)),
		int(sell.get("cannon_parts", 0)),
	]


func _political_report() -> String:
	if _political_log.is_empty():
		return "Political ripples\n- None"
	var output := "Political ripples"
	for i in range(mini(4, _political_log.size())):
		output += "\n- %s" % String(_political_log[i])
	return output


func _factions_report() -> String:
	var ordered := ["Crown Dominion", "Free Captains", "Ironwake Compact", "Independent", "Unclaimed", "Uncharted"]
	var output := "Faction map state\nCombat, contracts and surrender decisions change this board. Relation affects port access; sea power affects patrol pressure.\n\nWarfront snapshot\n%s\n" % _warfront_report()
	for faction in ordered:
		var relation := int(_faction_reputation.get(faction, 0))
		var power := int(_faction_power.get(faction, 45))
		var pressure := _region_pressure_for_faction(faction)
		output += "\n%s\nRelation [%s] %s (%d)\nSea power [%s] %d/100\nPressure [%s] %d/100\nEffect: %s\n" % [
			faction,
			_status_bar(_relation_to_bar_value(relation)),
			_reputation_label(relation),
			relation,
			_status_bar(power),
			power,
			_status_bar(pressure),
			pressure,
			_faction_effect_text(faction, relation, pressure),
		]
	output += "\n%s" % _political_report()
	return output


func _relation_to_bar_value(value: int) -> int:
	return clampi(value + 50, 0, 100)


func _faction_effect_text(faction: String, relation: int, pressure: int) -> String:
	if relation <= -45:
		return "Ports may close; patrols hunt you in controlled waters."
	if relation <= -15:
		return "Hostile watch; prices worsen and patrol pressure climbs."
	if relation >= 35:
		return "Friendly access; patrols are less aggressive and hiring improves."
	if pressure >= 70:
		return "Waters are heavily watched even without open hostility."
	if faction == "Uncharted":
		return "Knowledge here can reveal locked waters."
	return "Neutral business; choices can still shift access and contracts."


func _character_report() -> String:
	return "Captain profile\nIndependent privateer\nRenown: %d\n\nFaction relations\n%s" % [
		_captain_renown,
		_reputation_lines(),
	]


func _reputation_lines() -> String:
	var ordered := ["Crown Dominion", "Free Captains", "Ironwake Compact", "Independent", "Unclaimed", "Uncharted"]
	var lines: Array[String] = []
	for faction in ordered:
		var value := int(_faction_reputation.get(faction, 0))
		var power := int(_faction_power.get(faction, 45))
		lines.append("%s: %s (%d), power %d" % [faction, _reputation_label(value), value, power])
	return "\n".join(lines)


func _reputation_label(value: int) -> String:
	if value >= 45:
		return "Ally"
	if value >= 15:
		return "Friendly"
	if value >= -14:
		return "Wary"
	if value >= -44:
		return "Hostile"
	return "Hunted"


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.86))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.86, 0.74, 0.50, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.0, 0.0, 0.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
