extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_on_custom_battle_requested", {
		"player_type": "Frigate",
		"allies": {"Brig": 1},
		"enemies": {"Sloop": 1, "Ship of the Line": 1},
	})
	for frame in range(20):
		await physics_frame

	var player := game.get_node("PlayerShip") as RigidBody3D
	var ships := get_nodes_in_group("ships")
	if player == null or ships.size() != 4:
		return _fail("Combat floatable fleet failed to spawn")
	for ship in ships:
		if ship.get("fluid_interactor").fluid_area == null:
			return _fail("A combat ship did not enter the wave fluid")

	var initial_player_position := player.global_position
	var initial_enemy_positions := {}
	for enemy in get_nodes_in_group("enemies"):
		initial_enemy_positions[enemy.get_instance_id()] = enemy.global_position
	player.call("set_sail_step", 3, true)
	Input.action_press("rudder_left", 1.0)
	for frame in range(300):
		await physics_frame
	Input.action_release("rudder_left")

	var player_distance := Vector2(
		player.global_position.x - initial_player_position.x,
		player.global_position.z - initial_player_position.z
	).length()
	if player_distance < 8.0 or absf(player.rotation.y - PI) < 0.12:
		return _fail("Player combat hull did not establish a physical turn: distance %.2f yaw %.3f" % [player_distance, player.rotation.y])
	var moving_enemies := 0
	for enemy in get_nodes_in_group("enemies"):
		var start: Vector3 = initial_enemy_positions.get(enemy.get_instance_id(), enemy.global_position)
		if Vector2(enemy.global_position.x - start.x, enemy.global_position.z - start.z).length() > 3.0:
			moving_enemies += 1
	for ship in get_nodes_in_group("ships"):
		if not bool(ship.get("is_sunk")) and (ship.global_position.y < -2.6 or ship.global_position.y > 2.2):
			return _fail("Combat hull left the water envelope: %s y=%.2f" % [ship.name, ship.global_position.y])
	if moving_enemies <= 0:
		return _fail("Enemy AI did not propel a physical combat hull")

	var boarding_enemy: Node = get_nodes_in_group("enemies")[0]
	boarding_enemy.global_position = player.global_position + player.global_transform.basis.x.normalized() * 8.0
	boarding_enemy.global_transform.basis = player.global_transform.basis
	boarding_enemy.call("incapacitate_for_boarding")
	game.call("_start_boarding_sequence", boarding_enemy)
	for frame in range(420):
		await physics_frame
	if not is_instance_valid(game.get("boarding_resolution_target")):
		return _fail("Physical hull boarding alignment did not reach resolution")
	Input.action_press("shot_round", 1.0)
	await physics_frame
	Input.action_release("shot_round")
	for frame in range(4):
		await physics_frame
	if int(boarding_enemy.get("team_id")) != 0 or bool(boarding_enemy.get("is_sunk")):
		return _fail("Captured physical hull did not return as an allied ship")

	print("COMBAT_FLOATABLE_INTEGRATION_OK player_distance=%.2f player_y=%.2f moving_enemies=%d boarding=captured" % [
		player_distance, player.global_position.y, moving_enemies,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
