extends SceneTree

const PirateKitAssets := preload("res://scripts/pirate_kit_assets.gd")
const CombatFx := preload("res://scripts/combat_fx.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var ship := game.get_node_or_null("PlayerShip")
	var crew_model := ship.find_child("PirateModel", true, false) if ship else null
	var kit_cannon := ship.find_child("*PirateKitCannon", true, false) if ship else null
	var kit_barrel := ship.find_child("PirateKitBarrel", true, false) if ship else null
	if crew_model == null or kit_cannon == null or kit_barrel == null:
		push_error("Pirate Kit ship visuals were not instantiated.")
		quit(1)
		return
	var crew_root := crew_model.get_parent() as Node3D
	if crew_root == null or String(crew_root.get_meta("asset_animation", "")) != "Idle":
		var animator := PirateKitAssets.find_animation_player(crew_model)
		push_error("Pirate Kit crew animation was not connected. Available: %s" % [animator.get_animation_list() if animator else []])
		quit(1)
		return
	if game.find_child("PirateKitPalm", true, false) == null or game.find_child("PirateKitRock", true, false) == null:
		push_error("Pirate Kit island visuals were not instantiated.")
		quit(1)
		return
	game.call("_on_custom_battle_requested", {
		"player_type": "Man o' War",
		"allies": {},
		"enemies": {"Brig": 1},
	})
	for frame in range(8):
		await process_frame
	if game.get_node_or_null("ShipCamera") == null:
		push_error("Interpolated combat camera was not created.")
		quit(1)
		return
	ship = game.get_node_or_null("PlayerShip")
	if ship == null or ship.find_child("PoopDeck", true, false) == null or ship.find_child("SternTurbulence", true, false) == null:
		push_error("Man o' War deck architecture or organic wake was not instantiated.")
		quit(1)
		return
	ship.set("sail_setting", 0.0)
	ship.call("_update_sail_damage_visual")
	var furled_sail := ship.find_child("FurledCourseSail", true, false)
	if furled_sail == null or not furled_sail.visible:
		push_error("Furled sail rolls were not activated.")
		quit(1)
		return
	var port_recesses: Array[Node] = []
	for recess in ship.find_children("*GunportRecess*", "MeshInstance3D", true, false):
		if recess.position.x < 0.0:
			port_recesses.append(recess)
	var row_heights: Dictionary = {}
	for recess in port_recesses:
		row_heights[snappedf(recess.position.y, 0.01)] = true
	if row_heights.size() != 4:
		push_error("Man o' War gunports were not separated into four visible battery decks: %s" % [row_heights.keys()])
		quit(1)
		return
	var battery_counts := [0, 0, 0, 0]
	var port_battery: Array = ship.get("_port_gunport_visuals")
	for placement in port_battery:
		var deck_row := int(placement.get("deck_row", -1))
		if deck_row >= 0 and deck_row < battery_counts.size():
			battery_counts[deck_row] += 1
	if battery_counts != [3, 4, 4, 5]:
		push_error("Man o' War battery was not distributed across the hull: %s" % [battery_counts])
		quit(1)
		return
	if ship.find_child("PortBatteryDeck4", true, false) == null or ship.find_child("StarboardUpperWale4", true, false) == null:
		push_error("Conforming heavy-ship battery bands were not instantiated.")
		quit(1)
		return
	for placement in port_battery:
		var recess := placement.get("door") as MeshInstance3D
		var expected_surface := float(ship.call("_get_hull_side_surface_x", float(placement.y), float(placement.z)))
		if recess == null or absf(absf(recess.position.x) - (expected_surface + 0.012)) > 0.025:
			push_error("Gunport did not conform to the curved hull surface.")
			quit(1)
			return
	var ready_marker := ship.find_child("PortCannonReady", true, false)
	if ready_marker == null or ready_marker.visible:
		push_error("Legacy emissive cannon readiness markers are still visible.")
		quit(1)
		return
	var internal_cannon := ship.find_child("*PirateKitCannon", true, false) as Node3D
	var hull_width := float(ship.get("_hull_width"))
	if internal_cannon == null or absf(internal_cannon.position.x) >= hull_width * 0.40:
		push_error("Cannon carriage was not moved inside the hull.")
		quit(1)
		return
	var gunport_lid := ship.find_child("PortDeck1GunportLid", true, false) as MeshInstance3D
	if gunport_lid == null:
		push_error("Physical gunport lid was not instantiated.")
		quit(1)
		return
	CombatFx.spawn_muzzle_burst(game, Vector3.ZERO, Vector3.RIGHT)
	CombatFx.spawn_broadside_smoke_bank(game, ship, -1, 8)
	await process_frame
	var muzzle_flash := game.find_child("MuzzleFlash", true, false) as MeshInstance3D
	var broadside_flash := game.find_child("BroadsideFlashLine", true, false) as MeshInstance3D
	if muzzle_flash == null or broadside_flash == null:
		push_error("Cannon flash lifecycle fixtures were not instantiated.")
		quit(1)
		return
	var muzzle_material := muzzle_flash.material_override as StandardMaterial3D
	var powder_smoke := game.find_child("PowderSmokeBank", true, false) as GPUParticles3D
	var powder_quad := powder_smoke.draw_pass_1 as QuadMesh if powder_smoke else null
	var powder_material := powder_quad.material as StandardMaterial3D if powder_quad else null
	if not (muzzle_flash.mesh is QuadMesh) or muzzle_material == null or muzzle_material.albedo_texture == null:
		push_error("Kenney muzzle texture was not connected to the cannon flash.")
		quit(1)
		return
	if powder_material == null or powder_material.albedo_texture == null:
		push_error("Kenney smoke texture was not connected to the broadside bank.")
		quit(1)
		return
	var combat_audio := game.get_node_or_null("CombatAudio")
	var combat_streams: Dictionary = combat_audio.get("_streams") if combat_audio else {}
	if not (combat_streams.get("cannon") is AudioStreamOggVorbis):
		push_error("Recorded cannon audio was not loaded; synthetic fallback is active.")
		quit(1)
		return
	await create_timer(0.18).timeout
	if muzzle_flash.visible or broadside_flash.visible:
		push_error("Cannon flashes outlived their muzzle burst window.")
		quit(1)
		return
	if powder_smoke == null or not is_instance_valid(powder_smoke):
		push_error("Broadside smoke was removed together with the short muzzle flash.")
		quit(1)
		return
	game.queue_free()
	await process_frame
	await process_frame

	print("PIRATE_KIT_SMOKE_OK crew=true cannon=true deck_props=true islands=true camera=true heavy_ship=true furled_sails=true wake=true gun_decks=3+4+4+5 internal_carriages=true short_muzzle_flash=true textured_vfx=true recorded_audio=true")
	quit(0)
