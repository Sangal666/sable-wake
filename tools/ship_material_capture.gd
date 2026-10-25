extends SceneTree

const OUTPUT_FRIGATE := "/private/tmp/blackflag_material_frigate.png"
const OUTPUT_FRIGATE_STERN := "/private/tmp/blackflag_material_frigate_stern.png"
const OUTPUT_MAN_O_WAR := "/private/tmp/blackflag_material_man_o_war.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested := OS.get_cmdline_user_args()
	if not requested.is_empty():
		var ship_type := String(requested[0]).replace("_", " ")
		var slug := ship_type.to_lower().replace(" ", "_").replace("'", "")
		var output_path := "/private/tmp/blackflag_class_%s.png" % slug
		var view := _get_class_capture_view(ship_type)
		if not await _capture_ship(ship_type, output_path, view.offset, view.look):
			return
		print("SHIP_CLASS_CAPTURE_OK class=%s output=%s" % [ship_type, output_path])
		quit(0)
		return
	if not await _capture_ship("Frigate", OUTPUT_FRIGATE, Vector3(13.8, 6.4, 12.6), Vector3.UP * 2.35):
		return
	if not await _capture_ship("Frigate", OUTPUT_FRIGATE_STERN, Vector3(-10.8, 5.3, 14.6), Vector3.UP * 1.75):
		return
	if not await _capture_ship("Man o' War", OUTPUT_MAN_O_WAR, Vector3(15.5, 7.5, 13.5), Vector3.UP * 2.55):
		return
	print("SHIP_MATERIAL_CAPTURE_OK frigate=%s frigate_stern=%s man_o_war=%s" % [OUTPUT_FRIGATE, OUTPUT_FRIGATE_STERN, OUTPUT_MAN_O_WAR])
	quit(0)


func _get_class_capture_view(ship_type: String) -> Dictionary:
	match ship_type:
		"Sloop":
			return {"offset": Vector3(9.0, 4.2, 8.0), "look": Vector3.UP * 1.45}
		"Brig":
			return {"offset": Vector3(11.2, 5.0, 9.8), "look": Vector3.UP * 1.75}
		"Ship of the Line":
			return {"offset": Vector3(17.5, 8.0, 15.5), "look": Vector3.UP * 3.0}
		"Man o' War":
			return {"offset": Vector3(32.5, 15.5, 29.5), "look": Vector3.UP * 4.05}
		_:
			return {"offset": Vector3(13.8, 6.4, 12.6), "look": Vector3.UP * 2.35}


func _capture_ship(ship_type: String, output_path: String, camera_offset: Vector3, look_offset: Vector3) -> bool:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_on_custom_battle_requested", {
		"player_type": ship_type,
		"allies": {},
		"enemies": {"Brig": 1},
		"weather": "Clear",
		"time_of_day": "Day",
		"sea_condition": "Rolling",
	})
	for frame in range(24):
		await physics_frame

	var player_ship := game.get_node_or_null("PlayerShip") as Node3D
	var camera := game.get_node_or_null("ShipCamera") as Camera3D
	if not is_instance_valid(player_ship) or not is_instance_valid(camera):
		push_error("Material capture could not find the player ship or camera for %s." % ship_type)
		quit(1)
		return false

	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	player_ship.call("set_sail_step", 3, true)
	player_ship.set("speed", 0.0)
	player_ship.set("velocity", Vector3.ZERO)
	player_ship.set_physics_process(false)
	if player_ship is RigidBody3D:
		(player_ship as RigidBody3D).freeze = true
	player_ship.rotation.y = deg_to_rad(-18.0)

	var hud := game.get_node_or_null("HUD") as CanvasLayer
	if is_instance_valid(hud):
		hud.visible = false
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.fov = 48.0
	camera.global_position = player_ship.global_position + camera_offset
	camera.look_at(player_ship.global_position + look_offset)
	game.set_process(false)
	await create_timer(0.18).timeout
	var saved := await _save_frame(output_path)
	game.free()
	await process_frame
	return saved


func _save_frame(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Ship material capture failed: %s" % error_string(error))
		quit(1)
		return false
	return true
