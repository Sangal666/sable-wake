extends SceneTree

const Cannonball := preload("res://scripts/cannonball.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.player_ship.global_position = Vector3(140.0, 0.0, 140.0)

	var attacker: Node = game.call("_spawn_ai_ship", {
		"name": "Boarding Escort",
		"role": "Escort",
		"hull_class": "Brig",
		"pos": Vector3.ZERO,
	}, 0, null)
	var target: Node = game.call("_spawn_ai_ship", {
		"name": "Disabled Raider",
		"role": "Raider",
		"hull_class": "Brig",
		"pos": Vector3(12.0, 0.0, 0.0),
	}, 1, null)
	target.call("incapacitate_for_boarding")
	game.call("_assign_ai_boarding_orders")

	if game.ai_boarding_operations.size() != 1:
		return _fail("AI did not reserve exactly one disabled prize")
	if not bool(attacker.get("boarding_order_active")) or attacker.get("boarding_order_target") != target:
		return _fail("Allied AI did not receive a boarding approach order")
	if attacker.call("_get_fire_request") != 0:
		return _fail("Boarding AI can still fire at its protected prize")

	var ball := Cannonball.new()
	ball.source_ship = attacker
	if not bool(ball.call("_is_ai_prize_protected", target)):
		return _fail("An allied projectile can still damage the boarding prize")
	ball.free()

	for step in range(100):
		if game.ai_boarding_operations.is_empty():
			break
		game.call("_update_ai_boarding_operation", game.ai_boarding_operations[0], 0.10)

	if int(target.get("team_id")) != 0 or not game.allies.has(target) or game.enemies.has(target):
		return _fail("Captured AI prize did not change teams")
	if bool(target.get_meta("boarding_protected", false)):
		return _fail("Boarding protection remained after capture")

	print("AI_BOARDING_TEST_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
