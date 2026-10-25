extends SceneTree

const PlayerShip := preload("res://scripts/player_ship.gd")

const SHIP_TYPES := ["Sloop", "Brig", "Frigate", "Ship of the Line", "Man o' War"]
const EXPECTED_GUNS := {
	"Sloop": 4,
	"Brig": 5,
	"Frigate": 8,
	"Ship of the Line": 12,
	"Man o' War": 16,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame

	var previous_speed := INF
	for type_name in SHIP_TYPES:
		var profile: Dictionary = game.call("_ship_profile", type_name)
		var speed := float(profile.get("max_speed", 0.0))
		if speed >= previous_speed:
			return _fail("Ship speed order is not descending at %s" % type_name)
		previous_speed = speed
		if type_name in ["Ship of the Line", "Man o' War"] and float(profile.get("turn_rate", 0.0)) < 0.70:
			return _fail("Heavy ship turn authority is still too low for arcade combat: %s" % type_name)

		var ship := PlayerShip.new()
		ship.max_health = float(profile.health)
		ship.cannon_damage = float(profile.damage)
		ship.base_cannons_per_side = int(profile.cannons)
		ship.set_hull_class(type_name)
		root.add_child(ship)
		await process_frame

		var gun_count := int(ship.call("_get_active_cannon_placements", 1).size())
		if gun_count != int(EXPECTED_GUNS[type_name]):
			return _fail("%s has %d active guns instead of %d" % [type_name, gun_count, EXPECTED_GUNS[type_name]])

		var hull_scale := float(ship.call("_get_class_hull_damage_scale"))
		var estimated_broadsides := ship.max_health / maxf(float(gun_count) * ship.cannon_damage * hull_scale, 0.01)
		if estimated_broadsides < 3.5 or estimated_broadsides > 7.2:
			return _fail("%s equal-class durability is outside target: %.2f broadsides" % [type_name, estimated_broadsides])

		ship.set_aim_focus(0.0)
		var loose_area := ship.get_salvo_area_radius_for_distance(72.0)
		ship.set_aim_focus(1.0)
		var focused_area := ship.get_salvo_area_radius_for_distance(72.0)
		if focused_area >= loose_area * 0.28:
			return _fail("%s broadside does not focus enough: %.2f -> %.2f" % [type_name, loose_area, focused_area])

		ship.set_sail_step(1, true)
		var battle_handling := float(ship.call("_get_sail_handling_multiplier"))
		ship.set_sail_step(3, true)
		var full_handling := float(ship.call("_get_sail_handling_multiplier"))
		if battle_handling < full_handling * 1.45:
			return _fail("%s sail steps do not create a meaningful combat-turn tradeoff" % type_name)

		var solid_angle: Dictionary = ship.call("_get_hit_angle_profile", Vector3.RIGHT)
		var raking_angle: Dictionary = ship.call("_get_hit_angle_profile", Vector3.FORWARD)
		var glancing_angle: Dictionary = ship.call("_get_hit_angle_profile", Vector3(1.0, 0.0, 1.0).normalized())
		if String(solid_angle.name) != "solid" or float(raking_angle.damage_scale) <= float(solid_angle.damage_scale) or float(glancing_angle.damage_scale) >= float(solid_angle.damage_scale):
			return _fail("%s impact-angle hierarchy is invalid" % type_name)

		var cap := float(ship.call("_get_round_salvo_health_cap"))
		var report := {
			"shot_mode": "round",
			"salvo_id": "balance-test",
			"health_damage": ship.max_health,
			"sail_damage": 0.0,
			"rudder_damage": 0.0,
			"port_cannon_damage": 0.0,
			"starboard_cannon_damage": 0.0,
			"crew_shock_gain": 0.0,
			"hit_position": ship.global_position,
			"incoming_direction": Vector3.RIGHT,
			"zone": "hull",
		}
		ship.call("_apply_damage_report", report)
		if absf(float(report.health_damage) - cap) > 0.02:
			return _fail("%s salvo cap mismatch: %.2f applied, %.2f expected" % [type_name, report.health_damage, cap])
		var health_after_first := ship.health
		ship.call("_apply_damage_report", report.duplicate(true))
		if not is_equal_approx(ship.health, health_after_first):
			return _fail("%s received excess damage from the same salvo" % type_name)

		print("BALANCE %s speed=%.2f turn=%.2f guns=%d durability=%.2f focus=%.2f->%.2f handling=%.2f/%.2f cap=%.1f" % [
			type_name, speed, profile.turn_rate, gun_count, estimated_broadsides, loose_area, focused_area, battle_handling, full_handling, cap,
		])
		ship.free()

	print("COMBAT_BALANCE_TEST_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
