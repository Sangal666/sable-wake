extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_custom_battle_requested", {
		"player_type": "Brig",
		"allies": {"Frigate": 3},
		"enemies": {"Frigate": 3},
		"sea_state": "rolling",
		"time_of_day": "day",
	})
	await process_frame

	var allies: Array[Node] = game.allies
	var enemies: Array[Node] = game.enemies
	if allies.size() != 3 or enemies.size() != 3:
		return _fail("Fleet coordination fixture did not spawn 3v3 AI ships")

	for ally in allies:
		ally.set("target_ship", null)
		ally.set("_target_commitment_timer", 0.0)
	for ally in allies:
		ally.call("_acquire_target")
	var assigned_targets := {}
	for ally in allies:
		var target: Node = ally.get("target_ship")
		if is_instance_valid(target):
			assigned_targets[target.get_instance_id()] = true
	if assigned_targets.size() < 2:
		return _fail("Three allied ships still collapsed onto one target")

	var lead := allies[0] as Node3D
	var follower := allies[1] as Node3D
	lead.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -6.0))
	follower.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	lead.set("velocity", Vector3(0.0, 0.0, -3.0))
	follower.set("velocity", Vector3(0.0, 0.0, -6.0))
	follower.set("_fleet_awareness_timer", 0.0)
	follower.call("_update_fleet_awareness", 0.2)
	var avoidance: Vector3 = follower.get("_fleet_avoidance")
	if avoidance.length() < 0.2 or float(follower.get("_traffic_brake")) < 0.12:
		return _fail("Following ship did not create separation and traffic braking")

	var prize := enemies[0] as Node3D
	prize.global_position = Vector3(5.0, 0.0, 0.0)
	prize.call("incapacitate_for_boarding")
	game.call("_mark_boarding_protection", prize, 0, game.player_ship)
	follower.global_position = Vector3(10.0, 0.0, 0.0)
	follower.set("_fleet_avoidance", Vector3.ZERO)
	follower.set("_fleet_awareness_timer", 0.0)
	follower.call("_update_fleet_awareness", 0.2)
	var prize_avoidance: Vector3 = follower.get("_fleet_avoidance")
	if prize_avoidance.dot((follower.global_position - prize.global_position).normalized()) <= 0.15:
		return _fail("Non-boarding AI did not clear the protected prize corridor")

	if is_equal_approx(float(allies[0].call("_get_coordinated_desired_range")), float(allies[1].call("_get_coordinated_desired_range"))):
		return _fail("Fleet ships were not assigned staggered combat lanes")

	print("FLEET_AI_COORDINATION_TEST_OK targets=%d brake=%.2f avoidance=%.2f" % [
		assigned_targets.size(),
		float(follower.get("_traffic_brake")),
		prize_avoidance.length(),
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
