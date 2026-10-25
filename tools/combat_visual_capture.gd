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
		"player_type": "Frigate",
		"allies": {},
		"enemies": {"Brig": 1},
	})
	for frame in range(20):
		await physics_frame
	var player_ship := game.get_node("PlayerShip") as Node3D
	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		push_error("Visual capture could not find an enemy ship.")
		quit(1)
		return
	var enemy := enemies[0] as Node3D
	enemy.global_position = player_ship.global_position + Vector3(25.0, 0.0, -5.0)
	enemy.rotation.y = player_ship.rotation.y + PI
	enemy.set("speed", 0.0)
	enemy.set("velocity", Vector3.ZERO)
	enemy.set_physics_process(false)
	if enemy is RigidBody3D:
		(enemy as RigidBody3D).freeze = true
	var camera := game.get_node("ShipCamera") as Camera3D
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = player_ship.global_position + Vector3(31.0, 12.5, 10.0)
	camera.look_at(player_ship.global_position.lerp(enemy.global_position, 0.32) + Vector3.UP * 1.3)
	player_ship.call("set_aim_focus", 0.90)
	var aim_point := enemy.global_position + Vector3.UP * 0.72
	var aim_direction := (aim_point - player_ship.global_position).normalized()
	var aim_guide := game.get_node("AimGuide") as Node3D
	var hud := game.get_node("HUD") as CanvasLayer
	game.set_process(false)
	aim_guide.call("show_solution", player_ship, 1, aim_point, true)
	hud.call("set_aim_state", true, 1, true, 0.90, false, 0.0)
	await create_timer(0.08).timeout
	if not await _save_frame("/private/tmp/blackflag_combat_aim_qa.png"):
		return
	aim_guide.call("hide_solution")
	hud.call("set_aim_state", false, 0, false, 0.0, false, 0.0)
	if not bool(player_ship.call("fire_camera_broadside", aim_direction, 1, aim_point)):
		push_error("Visual capture could not fire a focused broadside.")
		quit(1)
		return
	CombatFx.spawn_hull_hit(game, enemy.global_position + Vector3(-2.0, 1.1, 0.0), Vector3.RIGHT)
	CombatFx.spawn_near_miss_splash(game, enemy.global_position + Vector3(3.2, 0.0, 1.8), enemy)
	await create_timer(0.06).timeout
	if not await _save_frame("/private/tmp/blackflag_combat_flash_qa.png"):
		return
	await create_timer(0.24).timeout
	if not await _save_frame("/private/tmp/blackflag_combat_smoke_qa.png"):
		return
	await create_timer(1.35).timeout
	if not await _save_frame("/private/tmp/blackflag_combat_result_qa.png"):
		return
	print("COMBAT_VISUAL_CAPTURE_OK aim=/private/tmp/blackflag_combat_aim_qa.png flash=/private/tmp/blackflag_combat_flash_qa.png smoke=/private/tmp/blackflag_combat_smoke_qa.png result=/private/tmp/blackflag_combat_result_qa.png")
	quit(0)


func _save_frame(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Combat visual capture failed: %s" % error_string(error))
		quit(1)
		return false
	return true
