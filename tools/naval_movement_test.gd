extends SceneTree

const PlayerShip := preload("res://scripts/player_ship.gd")
const WaveFluid := preload("res://scripts/wave_fluid_area_3d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action in ["sail_up", "sail_down", "rudder_left", "rudder_right", "aim_hold", "fire_port", "fire_starboard", "emergency_repair", "brace"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	var fluid := WaveFluid.new()
	fluid.name = "MovementTestFluid"
	var fluid_collision := CollisionShape3D.new()
	var fluid_shape := BoxShape3D.new()
	fluid_shape.size = Vector3(500.0, 40.0, 500.0)
	fluid_collision.shape = fluid_shape
	fluid_collision.position.y = -20.18
	fluid.add_child(fluid_collision)
	root.add_child(fluid)

	var ship := PlayerShip.new()
	ship.max_speed = 9.5
	ship.acceleration = 3.55
	ship.deceleration = 3.2
	ship.turn_rate = 0.94
	ship.wind_direction = Vector3(0.0, 0.0, -1.0)
	ship.set_hull_class("Frigate")
	root.add_child(ship)
	for frame in range(20):
		fluid.simulation_time += 1.0 / 60.0
		await physics_frame
	ship.set_sail_step(3, true)

	Input.action_press("rudder_left", 1.0)
	for frame in range(180):
		fluid.simulation_time += 1.0 / 60.0
		await physics_frame
	Input.action_release("rudder_left")

	var turn_heading := absf(ship.rotation.y)
	var turn_distance := Vector2(ship.global_position.x, ship.global_position.z).length()
	var release_yaw := absf(float(ship.get("_yaw_velocity")))
	var release_slip := absf(float(ship.get("_lateral_slip")))
	for frame in range(8):
		fluid.simulation_time += 1.0 / 60.0
		await physics_frame
	var carried_yaw := absf(float(ship.get("_yaw_velocity")))
	for frame in range(90):
		fluid.simulation_time += 1.0 / 60.0
		await physics_frame
	var settled_yaw := absf(float(ship.get("_yaw_velocity")))

	if turn_distance < 5.0 or turn_heading < 0.18:
		return _fail("Frigate did not establish a moving turn arc: distance %.2f heading %.3f" % [turn_distance, turn_heading])
	if release_slip < 0.01:
		return _fail("Turn produced no measurable hull slip")
	if carried_yaw < release_yaw * 0.18:
		return _fail("Rudder release stopped yaw too abruptly: %.3f -> %.3f" % [release_yaw, carried_yaw])
	if settled_yaw >= carried_yaw:
		return _fail("Yaw inertia did not settle after rudder release")

	ship.stop_water_motion()
	ship.set_sail_step(0, true)
	ship.rotation = Vector3.ZERO
	Input.action_press("rudder_left", 1.0)
	for frame in range(60):
		fluid.simulation_time += 1.0 / 60.0
		await physics_frame
	Input.action_release("rudder_left")
	var stationary_heading := absf(ship.rotation.y)
	if stationary_heading > 0.24:
		return _fail("Furled ship pivots in place too freely: %.3f radians" % stationary_heading)

	print("NAVAL_MOVEMENT_TEST_OK distance=%.2f heading=%.3f slip=%.3f yaw=%.3f->%.3f->%.3f stationary=%.3f" % [
		turn_distance, turn_heading, release_slip, release_yaw, carried_yaw, settled_yaw, stationary_heading,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
