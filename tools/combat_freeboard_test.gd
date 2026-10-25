extends SceneTree

const PlayerShip := preload("res://scripts/player_ship.gd")
const WaveFluid := preload("res://scripts/wave_fluid_area_3d.gd")

const CLASSES := ["Sloop", "Brig", "Frigate", "Ship of the Line", "Man o' War"]
const MINIMUM_CLEARANCE := {
	"Sloop": 0.18,
	"Brig": 0.28,
	"Frigate": 0.30,
	"Ship of the Line": 0.48,
	"Man o' War": 0.58,
}
const SEA_CONDITIONS := [
	{"name": "Rolling", "state": 0.95, "speed": 0.66, "chop": 0.90, "strict": true, "deck_avg_min": 0.50, "max_submerged_frames": 0},
	{"name": "High Seas", "state": 2.65, "speed": 0.88, "chop": 2.18, "strict": false, "deck_avg_min": 0.35, "max_submerged_frames": 120},
	{"name": "Storm High Seas", "state": 3.15, "speed": 0.95, "chop": 2.58, "strict": false, "deck_avg_min": 0.20, "max_submerged_frames": 150},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for condition in SEA_CONDITIONS:
		if not await _test_condition(condition):
			return
	print("COMBAT_FREEBOARD_TEST_OK")
	quit(0)


func _test_condition(condition: Dictionary) -> bool:
	var world := Node3D.new()
	root.add_child(world)
	var fluid := WaveFluid.new()
	fluid.name = "FreeboardWaveFluid_%s" % String(condition.name).replace(" ", "")
	fluid.sea_level = -0.18
	fluid.sea_state = float(condition.state)
	fluid.wave_speed = float(condition.speed)
	fluid.wave_chop = float(condition.chop)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1100.0, 40.0, 1100.0)
	collision.shape = shape
	collision.position.y = -20.18
	fluid.add_child(collision)
	world.add_child(fluid)

	var ships: Array[Node] = []
	for index in range(CLASSES.size()):
		var ship := PlayerShip.new()
		ship.name = CLASSES[index].replace(" ", "").replace("'", "")
		ship.hull_class = CLASSES[index]
		ship.accepts_player_input = false
		ship.position = Vector3((float(index) - 2.0) * 34.0, 0.0, float(index % 2) * 21.0)
		world.add_child(ship)
		ship.set_sail_step(0, true)
		ship.set_ocean_wave_profile(float(condition.state), float(condition.speed), float(condition.chop))
		ships.append(ship)

	var minimums := {}
	var sums := {}
	var gunport_minimums := {}
	var gunport_sums := {}
	var submerged_streaks := {}
	var maximum_submerged_streaks := {}
	var maximum_tilts := {}
	var maximum_vertical_speeds := {}
	var sample_count := 0
	for frame in range(660):
		fluid.simulation_time = float(frame) / 60.0
		await physics_frame
		if frame < 300:
			continue
		sample_count += 1
		for ship in ships:
			var clearance := _minimum_deck_clearance(ship, fluid)
			var gunport_clearance := _minimum_gunport_clearance(ship, fluid)
			var type_name := String(ship.hull_class)
			minimums[type_name] = minf(float(minimums.get(type_name, INF)), clearance)
			sums[type_name] = float(sums.get(type_name, 0.0)) + clearance
			gunport_minimums[type_name] = minf(float(gunport_minimums.get(type_name, INF)), gunport_clearance)
			gunport_sums[type_name] = float(gunport_sums.get(type_name, 0.0)) + gunport_clearance
			var streak := int(submerged_streaks.get(type_name, 0))
			streak = streak + 1 if clearance < -0.20 else 0
			submerged_streaks[type_name] = streak
			maximum_submerged_streaks[type_name] = maxi(int(maximum_submerged_streaks.get(type_name, 0)), streak)
			var tilt := maxf(absf(ship.rotation.x), absf(ship.rotation.z))
			maximum_tilts[type_name] = maxf(float(maximum_tilts.get(type_name, 0.0)), tilt)
			maximum_vertical_speeds[type_name] = maxf(float(maximum_vertical_speeds.get(type_name, 0.0)), absf(ship.linear_velocity.y))

	for ship in ships:
		var type_name := String(ship.hull_class)
		var minimum := float(minimums.get(type_name, -INF))
		var average := float(sums.get(type_name, 0.0)) / float(maxi(sample_count, 1))
		var gunport_minimum := float(gunport_minimums.get(type_name, -INF))
		var gunport_average := float(gunport_sums.get(type_name, 0.0)) / float(maxi(sample_count, 1))
		var maximum_submerged_streak := int(maximum_submerged_streaks.get(type_name, 0))
		var maximum_tilt := rad_to_deg(float(maximum_tilts.get(type_name, 0.0)))
		var maximum_vertical_speed := float(maximum_vertical_speeds.get(type_name, 0.0))
		print("COMBAT_FREEBOARD %s %s deck_min=%.2f deck_avg=%.2f gunport_min=%.2f gunport_avg=%.2f submerged_frames=%d tilt=%.1f heave_speed=%.2f root_y=%.2f" % [
			String(condition.name), type_name, minimum, average, gunport_minimum, gunport_average, maximum_submerged_streak, maximum_tilt, maximum_vertical_speed, ship.global_position.y,
		])
		if bool(condition.strict) and minimum < float(MINIMUM_CLEARANCE[type_name]):
			_fail("%s / %s deck entered the ocean: minimum clearance %.2f" % [condition.name, type_name, minimum])
			world.queue_free()
			return false
		if bool(condition.strict) and gunport_minimum < 0.16:
			_fail("%s / %s lower gun deck entered the ocean: minimum muzzle clearance %.2f" % [condition.name, type_name, gunport_minimum])
			world.queue_free()
			return false
		if average < float(condition.deck_avg_min):
			_fail("%s / %s remained too low in the water: average worst-point clearance %.2f" % [condition.name, type_name, average])
			world.queue_free()
			return false
		if maximum_submerged_streak > int(condition.max_submerged_frames):
			_fail("%s / %s deck stayed submerged for %d frames" % [condition.name, type_name, maximum_submerged_streak])
			world.queue_free()
			return false
		if maximum_tilt > 42.0 or maximum_vertical_speed > 9.0:
			_fail("%s / %s wave response became unstable: tilt %.1f, heave speed %.2f" % [condition.name, type_name, maximum_tilt, maximum_vertical_speed])
			world.queue_free()
			return false

	world.queue_free()
	await process_frame
	return true


func _minimum_deck_clearance(ship: Node3D, fluid: Node) -> float:
	var deck_y := float(ship.get("_deck_y"))
	var half_width := float(ship.get("_hull_width")) * 0.34
	var half_length := float(ship.get("_hull_length")) * 0.30
	var minimum := INF
	for x in [-half_width, 0.0, half_width]:
		for z in [-half_length, 0.0, half_length]:
			var deck_point := ship.global_transform * Vector3(x, deck_y, z)
			minimum = minf(minimum, deck_point.y - float(fluid.get_height(deck_point)))
	return minimum


func _minimum_gunport_clearance(ship: Node3D, fluid: Node) -> float:
	var visual_root := ship.get("_visual_root") as Node3D
	if not is_instance_valid(visual_root):
		return -INF
	var minimum := INF
	for side in [-1, 1]:
		var placements: Array = ship.call("_get_active_cannon_placements", side)
		for placement in placements:
			var local_y := float(placement.get("y", 0.0))
			var local_z := float(placement.get("z", 0.0))
			var surface_x := float(ship.call("_get_hull_side_surface_x", local_y, local_z)) + 0.24
			var muzzle_point := visual_root.global_transform * Vector3(surface_x * float(side), local_y, local_z)
			minimum = minf(minimum, muzzle_point.y - float(fluid.get_height(muzzle_point)))
	return minimum


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
