extends SceneTree

const CombatFx := preload("res://scripts/combat_fx.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_on_custom_battle_requested", {
		"player_type": "Man o' War",
		"allies": {"Frigate": 3, "Ship of the Line": 2},
		"enemies": {"Sloop": 4, "Brig": 4, "Frigate": 3, "Ship of the Line": 1},
	})
	for frame in range(12):
		await physics_frame

	var ships := get_nodes_in_group("ships")
	if ships.size() != 18:
		_fail("Custom fleet did not spawn the expected 18 ships: %d" % ships.size())
		return
	var player_ship := game.get_node_or_null("PlayerShip") as Node3D
	var impact_count_before := get_nodes_in_group("impact_fx").size()
	var deck_y := float(player_ship.get("_deck_y"))
	var hull_depth := float(player_ship.get("_hull_depth"))
	var hull_width := float(player_ship.get("_hull_width"))
	var hull_hit := player_ship.to_global(Vector3(hull_width * 0.48, deck_y - hull_depth * 0.18, 0.0))
	player_ship.call("take_projectile_hit", 10.0, null, hull_hit, Vector3.LEFT, "round", {"salvo_id": "stress-single-hit"})
	await process_frame
	if get_nodes_in_group("impact_fx").size() - impact_count_before != 1:
		_fail("A single projectile created duplicate impact effects.")
		return

	for index in range(ships.size()):
		var ship := ships[index] as Node3D
		if ship == null:
			continue
		CombatFx.spawn_broadside_smoke_bank(game, ship, -1 if index % 2 == 0 else 1, 16)
		for hit_index in range(3):
			var offset := Vector3(float(hit_index) * 0.25, 1.0, float(hit_index) * 0.35)
			CombatFx.spawn_hull_hit(game, ship.global_position + offset, Vector3.RIGHT)
			CombatFx.spawn_near_miss_splash(game, ship.global_position + Vector3(3.0 + hit_index, 0.0, 0.0), ship)
			CombatFx.spawn_water_splash(game, ship.global_position + Vector3(-3.0 - hit_index, 0.0, 0.0))

	await process_frame
	if get_nodes_in_group("broadside_smoke_fx").size() > 6:
		_fail("Broadside FX budget was exceeded.")
		return
	if get_nodes_in_group("impact_fx").size() > 14:
		_fail("Impact FX budget was exceeded.")
		return
	if get_nodes_in_group("water_impact_fx").size() > 4:
		_fail("Water FX budget was exceeded.")
		return
	if get_nodes_in_group("cannonballs").size() > 128:
		_fail("Projectile budget was exceeded.")
		return
	var combat_audio := game.get_node_or_null("CombatAudio")
	var active_audio := 0
	if combat_audio:
		for child in combat_audio.get_children():
			if child is AudioStreamPlayer3D:
				active_audio += 1
	if active_audio > 28:
		_fail("Spatial audio budget was exceeded: %d" % active_audio)
		return

	await create_timer(3.2).timeout
	if not get_nodes_in_group("impact_fx").is_empty() or not get_nodes_in_group("water_impact_fx").is_empty():
		_fail("Short-lived combat effects were not released after the stress burst.")
		return

	game.queue_free()
	await process_frame
	print("COMBAT_STRESS_OK ships=18 broadside_cap=6 impact_cap=14 water_cap=4 projectile_cap=128 audio_cap=28")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
