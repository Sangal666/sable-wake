extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_combat_sandbox_requested")
	await process_frame
	await process_frame

	if String(game.get("custom_scenario_id")) != "combat_sandbox":
		return _fail("Combat Sandbox did not become the active scenario")
	if not is_instance_valid(game.get("combat_sandbox")):
		return _fail("Combat Sandbox control panel was not created")
	var targets: Array = game.call("get_combat_sandbox_targets")
	if targets.size() != 4:
		return _fail("Sandbox expected three ships and one fort, found %d" % targets.size())
	if bool(game.call("_is_current_battle_complete")):
		return _fail("Sandbox incorrectly completed its battle objective")

	var ship: Node
	var fort: Node
	for target in targets:
		if target.is_in_group("scenario_fort"):
			fort = target
		elif ship == null:
			ship = target
	if ship == null or fort == null:
		return _fail("Sandbox targets did not include both ship and fort mechanics")
	if ship.process_mode != Node.PROCESS_MODE_DISABLED or float(fort.get("_reload")) < 900.0:
		return _fail("Sandbox did not begin with passive test targets")

	var ship_health := float(ship.get("health"))
	game.call("combat_sandbox_action", "target_light_hit", ship)
	if float(ship.get("health")) >= ship_health:
		return _fail("Target damage trigger did not use the live damage system")
	game.call("combat_sandbox_action", "target_boarding_ready", ship)
	if not bool(ship.get("is_incapacitated")):
		return _fail("Boarding-ready trigger did not incapacitate the target")
	game.call("combat_sandbox_action", "reload_all")
	if float(game.player_ship.get("_port_reload")) > 0.0 or float(game.player_ship.get("_mortar_reload")) > 0.0:
		return _fail("Instant reload trigger did not reset player batteries")
	game.call("combat_sandbox_action", "expose_fort", fort)
	if int(fort.get("fort_phase")) != 2:
		return _fail("Fort trigger did not expose the magazine")
	game.call("combat_sandbox_action", "reset_lab")
	await process_frame
	if game.call("get_combat_sandbox_targets").size() != 4:
		return _fail("Reset did not rebuild the full combat laboratory")

	print("COMBAT_SANDBOX_TEST_OK targets=4 damage=live boarding=ready fort=exposed reset=clean")
	quit(0)


func _fail(message: String) -> void:
	push_error("COMBAT_SANDBOX_TEST_FAILED: %s" % message)
	quit(1)
