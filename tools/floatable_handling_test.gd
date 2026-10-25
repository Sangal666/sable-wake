extends SceneTree

const FloatableShip := preload("res://scripts/floatable_lab_ship.gd")
const WaveFluid := preload("res://scripts/wave_fluid_area_3d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_ensure_action("rudder_left")
	_ensure_action("rudder_right")
	_ensure_action("sail_up")
	_ensure_action("sail_down")

	var world := Node3D.new()
	root.add_child(world)
	var fluid := WaveFluid.new()
	fluid.position.y = -20.18
	var area_shape := CollisionShape3D.new()
	var water_box := BoxShape3D.new()
	water_box.size = Vector3(1000.0, 40.0, 1000.0)
	area_shape.shape = water_box
	fluid.add_child(area_shape)
	world.add_child(fluid)

	for hull_class in ["Brig", "Frigate", "Ship of the Line", "Man o' War"]:
		var result := await _measure_ship(world, hull_class)
		print("FLOATABLE_HANDLING %s speed=%.2f turn=%.3f yaw_release=%.3f yaw_carry=%.3f slip=%.2f height=%.2f" % [
			hull_class,
			float(result.speed),
			float(result.turn),
			float(result.yaw_release),
			float(result.yaw_carry),
			float(result.slip),
			float(result.height),
		])
		if float(result.speed) < 5.0:
			return _fail("%s failed to establish sailing speed" % hull_class)
		var minimum_turn := 0.82
		match hull_class:
			"Frigate":
				minimum_turn = 0.70
			"Ship of the Line":
				minimum_turn = 0.52
			"Man o' War":
				minimum_turn = 0.40
		if float(result.turn) < minimum_turn:
			return _fail("%s did not establish a physical turn arc" % hull_class)
		if float(result.yaw_carry) < float(result.yaw_release) * 0.28:
			return _fail("%s loses yaw too abruptly when helm is released" % hull_class)
		if absf(float(result.height)) > 3.5:
			return _fail("%s did not settle near the ocean surface" % hull_class)

	print("FLOATABLE_HANDLING_TEST_OK")
	quit(0)


func _measure_ship(world: Node3D, hull_class: String) -> Dictionary:
	var ship := FloatableShip.new()
	ship.hull_class = hull_class
	ship.position = Vector3(0.0, 1.2, 0.0)
	world.add_child(ship)
	await physics_frame
	ship.set_sail_step(3)
	for frame in range(480):
		await physics_frame

	var forward_before := -ship.global_transform.basis.z.normalized()
	Input.action_press("rudder_left", 1.0)
	for frame in range(240):
		await physics_frame
	Input.action_release("rudder_left")
	var forward_after := -ship.global_transform.basis.z.normalized()
	var turn := absf(atan2(forward_before.cross(forward_after).y, forward_before.dot(forward_after)))
	var yaw_release := absf(ship.angular_velocity.y)
	var slip := absf(float(ship.get_telemetry().get("lateral_slip", 0.0)))
	for frame in range(12):
		await physics_frame
	var yaw_carry := absf(ship.angular_velocity.y)
	var result := {
		"speed": absf(float(ship.get_telemetry().get("speed", 0.0))),
		"turn": turn,
		"yaw_release": yaw_release,
		"yaw_carry": yaw_carry,
		"slip": slip,
		"height": ship.global_position.y,
	}
	ship.queue_free()
	await physics_frame
	return result


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
