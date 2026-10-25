extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--manowar-spawn" in OS.get_cmdline_user_args():
		await _capture_manowar_spawn()
		return
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	var menu := game.get_node("MainMenu")
	menu.call("_show_battle_builder")
	await _save("/private/tmp/custom_battle_conditions_qa.png")
	menu.call("_show_lab_builder")
	await _save("/private/tmp/lab_conditions_qa.png")

	game.call("_on_custom_battle_requested", {
		"player_type": "Frigate",
		"allies": {},
		"enemies": {"Raider": 1},
		"weather": "Storm",
		"time_of_day": "Day",
		"sea_condition": "Rough",
	})
	for frame in range(45):
		await physics_frame
	await _save("/private/tmp/custom_storm_day_qa.png")
	var fluid := game.get_node_or_null("CombatWaveFluid")
	if fluid == null or absf(float(fluid.get("sea_state")) - 2.05) > 0.01:
		return _fail("Custom battle did not apply the selected rough storm sea state")

	game.queue_free()
	await _capture_lab("Calm", "Clear", "Day", "/private/tmp/lab_calm_day_qa.png", 0.38)
	await _capture_lab("Rolling", "Clear", "Day", "/private/tmp/lab_rolling_day_qa.png", 0.95)
	await _capture_lab("Rough", "Clear", "Day", "/private/tmp/lab_rough_day_qa.png", 1.55)
	await _capture_lab("High Seas", "Clear", "Day", "/private/tmp/lab_high_seas_day_qa.png", 2.65)
	await _capture_lab("Rough", "Storm", "Day", "/private/tmp/lab_storm_day_qa.png", 2.05)
	await _capture_lab("High Seas", "Storm", "Day", "/private/tmp/lab_storm_high_seas_qa.png", 3.15)
	await _capture_lab("Rolling", "Clear", "Sunset", "/private/tmp/lab_sunset_qa.png", 0.95)
	print("BATTLE_ENVIRONMENT_CAPTURE_OK")
	quit(0)


func _capture_manowar_spawn() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	game.call("_on_custom_battle_requested", {
		"player_type": "Man o' War",
		"allies": {},
		"enemies": {"Raider": 1},
		"weather": "Storm",
		"time_of_day": "Day",
		"sea_condition": "High Seas",
	})
	var ship := game.get_node("PlayerShip") as RigidBody3D
	var fluid := game.get_node("CombatWaveFluid")
	var minimum_center_freeboard := INF
	var maximum_pitch := 0.0
	var maximum_roll := 0.0
	for frame in range(240):
		await physics_frame
		if not ship.visible:
			continue
		var water := float(fluid.call("get_surface_sample", ship.global_position).get("height", -0.18))
		var deck_height := (ship.global_transform * Vector3(0.0, float(ship.get("_deck_y")), 0.0)).y
		minimum_center_freeboard = minf(minimum_center_freeboard, deck_height - water)
		var basis := ship.global_transform.basis.orthonormalized()
		maximum_pitch = maxf(maximum_pitch, absf(rad_to_deg(asin(clampf(basis.z.y, -1.0, 1.0)))))
		maximum_roll = maxf(maximum_roll, absf(rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0)))))
		if frame == 45:
			await _save("/private/tmp/manowar_spawn_qa.png")
	await _save("/private/tmp/manowar_after_qa.png")
	print("MANOWAR_SPAWN_QA freeboard=%.2f pitch=%.1f roll=%.1f y=%.2f" % [minimum_center_freeboard, maximum_pitch, maximum_roll, ship.global_position.y])
	if minimum_center_freeboard < -0.55:
		return _fail("Man o' War center deck remained below the FFT surface")
	if maximum_pitch > 30.0 or maximum_roll > 32.0:
		return _fail("Man o' War exceeded the playable storm attitude envelope")
	print("MANOWAR_SPAWN_CAPTURE_OK")
	quit(0)


func _capture_lab(sea_condition: String, weather: String, time_of_day: String, path: String, expected_state: float) -> void:
	for frame in range(3):
		await process_frame
	var profiles := load("res://scripts/battle_environment_profiles.gd")
	profiles.set_pending_lab_config({
		"player_type": "Frigate",
		"weather": weather,
		"time_of_day": time_of_day,
		"sea_condition": sea_condition,
	})
	var lab := (load("res://scenes/ship_handling_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for frame in range(30):
		await physics_frame
	if weather == "Storm":
		lab.call("_spawn_storm_breaker", Vector3.LEFT)
		await physics_frame
		var breaker := lab.get_node_or_null("StormBreaker") as Node3D
		var ship := lab.get_node_or_null("LabFrigate") as Node3D
		if breaker != null and ship != null:
			breaker.global_position = ship.global_position + Vector3.LEFT * 42.0
	for frame in range(25):
		await physics_frame
	await _save(path)
	if sea_condition == "High Seas" and weather == "Clear" and time_of_day == "Day":
		await _measure_fft_ship_classes(lab)
	var lab_fluid := lab.get_node_or_null("WaveFluid")
	if lab_fluid == null or absf(float(lab_fluid.get("sea_state")) - expected_state) > 0.01:
		_fail("Handling lab did not receive %s sea state" % sea_condition)
	if weather == "Storm":
		var rain := lab.get_node_or_null("StormRain") as GPUParticles3D
		if rain == null or not rain.emitting:
			_fail("Handling lab did not enable storm rain")
		if lab.get_node_or_null("StormBreaker") == null:
			_fail("Handling lab did not create a storm breaker")
	elif lab.get_node_or_null("StormBreaker") != null:
		_fail("Handling lab created a storm breaker outside storm weather")
	lab.queue_free()


func _measure_fft_ship_classes(lab: Node) -> void:
	var class_cases := [
		{"index": 1, "name": "Frigate", "max_pitch": 31.0, "max_roll": 36.0, "max_heave": 12.5},
		{"index": 2, "name": "Ship of the Line", "max_pitch": 25.0, "max_roll": 29.0, "max_heave": 12.5},
		{"index": 3, "name": "Man o' War", "max_pitch": 23.0, "max_roll": 26.0, "max_heave": 12.5},
	]
	var results: Array[Dictionary] = []
	for ship_case in class_cases:
		lab.call("_select_ship", int(ship_case.index))
		for frame in range(60):
			await physics_frame
		var ship := lab.get("_ship") as RigidBody3D
		if ship == null:
			return _fail("Handling lab did not expose its active FFT ship")
		var min_y := INF
		var max_y := -INF
		var max_pitch := 0.0
		var max_roll := 0.0
		var pitch_activity := 0.0
		var previous_pitch := 0.0
		for frame in range(120):
			await physics_frame
			var basis := ship.global_transform.basis.orthonormalized()
			var pitch := asin(clampf(basis.z.y, -1.0, 1.0))
			var roll := asin(clampf(basis.x.y, -1.0, 1.0))
			min_y = minf(min_y, ship.global_position.y)
			max_y = maxf(max_y, ship.global_position.y)
			max_pitch = maxf(max_pitch, absf(rad_to_deg(pitch)))
			max_roll = maxf(max_roll, absf(rad_to_deg(roll)))
			pitch_activity += absf(pitch - previous_pitch)
			previous_pitch = pitch
		var heave_range := max_y - min_y
		var average_pitch_activity := rad_to_deg(pitch_activity / 120.0)
		results.append({
			"class": String(ship_case.name),
			"heave_range": heave_range,
			"max_pitch": max_pitch,
			"max_roll": max_roll,
			"pitch_activity": average_pitch_activity,
		})
		if heave_range < 0.18 or heave_range > float(ship_case.max_heave):
			return _fail("%s FFT heave is outside the playable envelope: %.3f m" % [ship_case.name, heave_range])
		if max_pitch > float(ship_case.max_pitch) or max_roll > float(ship_case.max_roll):
			return _fail("%s FFT rotation exceeds its class envelope: pitch %.2f, roll %.2f" % [ship_case.name, max_pitch, max_roll])
		if average_pitch_activity < 0.015:
			return _fail("%s does not continuously react to the FFT surface" % ship_case.name)
	print("FFT_WAVE_RESPONSE %s" % JSON.stringify(results))
	print("FFT_WAVE_RESPONSE_OK")


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		_fail("Could not save %s" % path)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
