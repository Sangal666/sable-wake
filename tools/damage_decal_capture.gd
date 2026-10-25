extends SceneTree

const OUTPUT_PATH := "/private/tmp/blackflag_damage_decals.png"


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
		"allies": {},
		"enemies": {"Brig": 1},
		"weather": "Clear",
		"time_of_day": "Day",
		"sea_condition": "Rolling",
	})
	for frame in range(24):
		await physics_frame

	var ship := game.get_node_or_null("PlayerShip") as Node3D
	var camera := game.get_node_or_null("ShipCamera") as Camera3D
	if not is_instance_valid(ship) or not is_instance_valid(camera):
		push_error("Damage decal capture could not find the player ship or camera.")
		quit(1)
		return
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	ship.call("set_sail_step", 3, true)
	ship.set("speed", 0.0)
	ship.set("velocity", Vector3.ZERO)
	ship.set_physics_process(false)
	if ship is RigidBody3D:
		(ship as RigidBody3D).freeze = true
	ship.rotation.y = deg_to_rad(-18.0)
	var hull_width := float(ship.get("_hull_width"))
	var deck_y := float(ship.get("_deck_y"))
	for data in [
		{"z": -2.6, "y": deck_y - 0.55, "damage": 5.0},
		{"z": -0.8, "y": deck_y - 0.38, "damage": 12.0},
		{"z": 1.1, "y": deck_y - 0.68, "damage": 8.0},
		{"z": 2.7, "y": deck_y - 0.46, "damage": 15.0},
	]:
		var hit_position := ship.to_global(Vector3(hull_width * 0.51, float(data.y), float(data.z)))
		ship.call("_add_persistent_hit_damage", {
			"health_damage": float(data.damage),
			"hit_position": hit_position,
			"zone": "hull",
		})
	var deck_hit := ship.to_global(Vector3(hull_width * 0.15, deck_y + 0.02, -0.4))
	ship.call("_add_persistent_hit_damage", {
		"health_damage": 10.0,
		"hit_position": deck_hit,
		"zone": "deck",
	})

	var hud := game.get_node_or_null("HUD") as CanvasLayer
	if is_instance_valid(hud):
		hud.visible = false
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.fov = 43.0
	camera.global_position = ship.global_position + Vector3(11.5, 4.4, 9.2)
	camera.look_at(ship.global_position + Vector3.UP * 1.65)
	game.set_process(false)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Damage decal capture failed: %s" % error_string(error))
		quit(1)
		return
	print("DAMAGE_DECAL_CAPTURE_OK output=%s" % OUTPUT_PATH)
	quit(0)
