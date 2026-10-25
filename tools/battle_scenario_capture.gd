extends SceneTree

const BattleScenarios := preload("res://scripts/battle_scenarios.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := await _new_game()
	var menu := game.get_node("MainMenu")
	menu.call("_show_battle_builder")
	var scenario_selector := menu.get("_scenario_selector") as OptionButton
	scenario_selector.select(5)
	menu.call("_on_scenario_selected", 5)
	await _save("/private/tmp/battle_scenarios_menu_qa.png")

	game = await _capture_scenario(
		game,
		"blackglass_bastion",
		"/private/tmp/blackglass_bastion_qa.png",
		Vector3(108.0, 58.0, 88.0),
		Vector3(0.0, 4.0, -96.0)
	)
	var phase_fort := get_nodes_in_group("scenario_fort")[0] as Node3D
	phase_fort.call("take_damage", float(phase_fort.get("max_health")) * 0.81, game.player_ship)
	var phase_camera := game.get_node("ShipCamera") as Camera3D
	phase_camera.global_position = phase_fort.global_position + Vector3(28.0, 18.0, 31.0)
	phase_camera.look_at(phase_fort.global_position + Vector3(0.0, 3.0, 0.0))
	await _save("/private/tmp/blackglass_magazine_phase_qa.png")
	phase_fort.call("take_damage", float(phase_fort.get("_magazine_max_health")) + 1.0, game.player_ship)
	phase_fort.call("_physics_process", 2.0)
	for _frame in range(12):
		await process_frame
	await _save("/private/tmp/blackglass_fort_assault_qa.png")
	phase_fort.call("_physics_process", 1.8)
	for _frame in range(6):
		await process_frame
	await _save("/private/tmp/blackglass_fort_colors_qa.png")
	game.mortar_targeting_ui.call("open", game.player_ship, game.enemies, 168.0)
	await process_frame
	await _save("/private/tmp/blackglass_mortar_map_qa.png")
	game.mortar_targeting_ui.call("close")
	game = await _capture_scenario(
		game,
		"redwater_dominion",
		"/private/tmp/redwater_dominion_qa.png",
		Vector3(122.0, 72.0, 106.0),
		Vector3(0.0, 2.5, -35.0)
	)
	await _capture_scenario(
		game,
		"storm_crown_armada",
		"/private/tmp/storm_crown_armada_qa.png",
		Vector3(118.0, 54.0, 124.0),
		Vector3(0.0, 3.5, -38.0)
	)
	print("BATTLE_SCENARIO_CAPTURE_OK")
	quit(0)


func _new_game() -> Node:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	return game


func _capture_scenario(
	current_game: Node,
	scenario_id: String,
	path: String,
	camera_position: Vector3,
	look_target: Vector3
) -> Node:
	current_game.queue_free()
	await process_frame
	var game := await _new_game()
	game.call("_on_custom_battle_requested", BattleScenarios.get_definition(scenario_id))
	for frame in range(50):
		await physics_frame
	var camera := game.get_node("ShipCamera") as Camera3D
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = camera_position
	camera.look_at(look_target)
	await _save(path)
	return game


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		push_error("Could not save %s" % path)
		quit(1)
