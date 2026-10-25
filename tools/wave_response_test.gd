extends SceneTree

const PlayerShip := preload("res://scripts/player_ship.gd")
const WaveFluid := preload("res://scripts/wave_fluid_area_3d.gd")
const CLASSES := ["Sloop", "Frigate", "Man o' War"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var fluid := WaveFluid.new()
	fluid.sea_level = -0.18
	fluid.sea_state = 2.65
	fluid.wave_speed = 0.88
	fluid.wave_chop = 2.18
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(900.0, 40.0, 900.0)
	collision.shape = shape
	collision.position.y = -20.18
	fluid.add_child(collision)
	world.add_child(fluid)

	var ships: Array[Node3D] = []
	for index in range(CLASSES.size()):
		var ship := PlayerShip.new()
		ship.hull_class = CLASSES[index]
		ship.accepts_player_input = false
		ship.position = Vector3(float(index) * 62.0 - 62.0, 0.8, float(index) * 19.0)
		ship.rotation.y = deg_to_rad(24.0 + float(index) * 17.0)
		world.add_child(ship)
		ship.set_sail_step(0, true)
		ship.set_ocean_wave_profile(2.65, 0.88, 2.18)
		ships.append(ship)

	var records := {}
	for ship in ships:
		records[String(ship.hull_class)] = {"water": [], "ship": [], "heave": [], "max_tilt": 0.0}
	for frame in range(1080):
		fluid.simulation_time = float(frame) / 60.0
		await physics_frame
		if frame < 300:
			continue
		for ship in ships:
			var basis := ship.global_transform.basis.orthonormalized()
			var horizontal_forward := -basis.z
			horizontal_forward.y = 0.0
			horizontal_forward = horizontal_forward.normalized()
			var sample_distance := float(ship.get("_hull_length")) * 0.42
			var bow := ship.global_position + horizontal_forward * sample_distance
			var stern := ship.global_position - horizontal_forward * sample_distance
			var water_pitch := atan2(fluid.get_height(bow) - fluid.get_height(stern), sample_distance * 2.0)
			var ship_forward := -basis.z.normalized()
			var ship_pitch := asin(clampf(ship_forward.y, -1.0, 1.0))
			var record: Dictionary = records[String(ship.hull_class)]
			(record.water as Array).append(water_pitch)
			(record.ship as Array).append(ship_pitch)
			(record.heave as Array).append(ship.global_position.y)
			record.max_tilt = maxf(float(record.max_tilt), maxf(absf(ship.rotation.x), absf(ship.rotation.z)))

	for ship in ships:
		var type_name := String(ship.hull_class)
		var record: Dictionary = records[type_name]
		var ship_range := _range(record.ship)
		var heave_range := _range(record.heave)
		var correlation := _best_lagged_correlation(record.water, record.ship, 75)
		var max_tilt := rad_to_deg(float(record.max_tilt))
		print("WAVE_RESPONSE %s pitch_range=%.1f heave_range=%.2f correlation=%.2f max_tilt=%.1f" % [
			type_name, rad_to_deg(ship_range), heave_range, correlation, max_tilt,
		])
		var minimum_pitch := 5.0
		match type_name:
			"Frigate": minimum_pitch = 3.6
			"Man o' War": minimum_pitch = 2.2
		if rad_to_deg(ship_range) < minimum_pitch:
			return _fail("%s is visually disconnected from the wave slope" % type_name)
		if heave_range < 0.45:
			return _fail("%s has no meaningful physical heave" % type_name)
		if correlation < 0.20:
			return _fail("%s pitch does not track passing wave trains" % type_name)
		if max_tilt > 38.0:
			return _fail("%s wave response is unstable" % type_name)

	print("WAVE_RESPONSE_TEST_OK")
	quit(0)


func _range(values: Array) -> float:
	var minimum := INF
	var maximum := -INF
	for value in values:
		minimum = minf(minimum, float(value))
		maximum = maxf(maximum, float(value))
	return maximum - minimum


func _best_lagged_correlation(first: Array, second: Array, maximum_lag: int) -> float:
	var best := 0.0
	for lag in range(maximum_lag + 1):
		best = maxf(best, absf(_correlation(first, second, lag)))
	return best


func _correlation(first: Array, second: Array, lag: int) -> float:
	var count := mini(first.size(), second.size() - lag)
	if count < 30:
		return 0.0
	var mean_a := 0.0
	var mean_b := 0.0
	for index in range(count):
		mean_a += float(first[index])
		mean_b += float(second[index + lag])
	mean_a /= float(count)
	mean_b /= float(count)
	var covariance := 0.0
	var variance_a := 0.0
	var variance_b := 0.0
	for index in range(count):
		var a := float(first[index]) - mean_a
		var b := float(second[index + lag]) - mean_b
		covariance += a * b
		variance_a += a * a
		variance_b += b * b
	return covariance / maxf(sqrt(variance_a * variance_b), 0.000001)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
