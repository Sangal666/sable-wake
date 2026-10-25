extends RefCounted

const MUZZLE_TEXTURE := preload("res://assets/vfx/kenney_particles/muzzle_01.png")
const POWDER_SMOKE_TEXTURE := preload("res://assets/vfx/kenney_particles/smoke_07.png")
const SPARK_TEXTURE := preload("res://assets/vfx/kenney_particles/spark_03.png")
const EXPLOSION_TEXTURE := preload("res://assets/vfx/kenney_smoke/explosion04.png")
const BLACK_SMOKE_TEXTURE := preload("res://assets/vfx/kenney_smoke/blackSmoke08.png")
const WATER_SPRAY_TEXTURE := preload("res://assets/vfx/kenney_smoke/whitePuff08.png")

static var _particle_mesh_cache: Dictionary = {}
static var _fx_budget_counts: Dictionary = {}
static var _fx_budget_frame := -1
static var _fx_budget_tree_id := 0
static var _ship_count_cache := 0
static var _ship_count_frame := -1
static var _ship_count_tree_id := 0

static func _fx_budget_available(parent: Node, group_name: StringName, limit: int) -> bool:
	if parent == null or parent.get_tree() == null:
		return parent != null
	var tree := parent.get_tree()
	var frame := Engine.get_process_frames()
	var tree_id := tree.get_instance_id()
	if _fx_budget_frame != frame or _fx_budget_tree_id != tree_id:
		_fx_budget_frame = frame
		_fx_budget_tree_id = tree_id
		_fx_budget_counts.clear()
	var key := StringName(group_name)
	var count := int(_fx_budget_counts.get(key, -1))
	if count < 0:
		count = tree.get_nodes_in_group(group_name).size()
	if count >= limit:
		_fx_budget_counts[key] = count
		return false
	_fx_budget_counts[key] = count + 1
	return true


static func _active_ship_count(parent: Node) -> int:
	if parent == null or parent.get_tree() == null:
		return 0
	var tree := parent.get_tree()
	var frame := Engine.get_process_frames()
	var tree_id := tree.get_instance_id()
	if _ship_count_frame != frame or _ship_count_tree_id != tree_id:
		_ship_count_frame = frame
		_ship_count_tree_id = tree_id
		_ship_count_cache = tree.get_nodes_in_group("ships").size()
	return _ship_count_cache


static func _fx_detail_scale(parent: Node, world_position: Vector3) -> float:
	if parent == null or parent.get_tree() == null:
		return 1.0
	var detail := 1.0
	var camera := parent.get_viewport().get_camera_3d()
	if camera:
		var distance := camera.global_position.distance_to(world_position)
		if distance > 175.0:
			detail = 0.36
		elif distance > 110.0:
			detail = 0.56
		elif distance > 68.0:
			detail = 0.78
	var ship_count := _active_ship_count(parent)
	if ship_count > 14:
		detail *= 0.68
	elif ship_count > 8:
		detail *= 0.82
	return clampf(detail, 0.28, 1.0)


static func _lod_particle_count(parent: Node, world_position: Vector3, base_count: int, minimum: int) -> int:
	return maxi(int(round(float(base_count) * _fx_detail_scale(parent, world_position))), minimum)


static func spawn_muzzle_burst(parent: Node, position: Vector3, direction: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "cannon", position, -1.5)
	if not _fx_budget_available(parent, &"muzzle_fx", 20):
		return

	var root := Node3D.new()
	root.name = "MuzzleBurst"
	parent.add_child(root)
	root.add_to_group("muzzle_fx")
	root.global_position = position

	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(0.92, 0.92)
	flash.mesh = flash_mesh
	flash.position = direction.normalized() * 0.18
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_texture = MUZZLE_TEXTURE
	flash_mat.albedo_color = Color(1.0, 0.72, 0.36, 0.92)
	flash_mat.emission_enabled = true
	flash_mat.emission_texture = MUZZLE_TEXTURE
	flash_mat.emission = Color(1.0, 0.48, 0.12)
	flash_mat.emission_energy_multiplier = 2.2
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.billboard_keep_scale = true
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = flash_mat
	root.add_child(flash)
	_fade_muzzle_flash(flash, flash_mat, 0.12)

	var smoke := GPUParticles3D.new()
	smoke.amount = _lod_particle_count(parent, position, 14, 5)
	smoke.one_shot = true
	smoke.explosiveness = 0.82
	smoke.lifetime = 1.0
	smoke.local_coords = false
	smoke.position = direction.normalized() * 0.42
	smoke.draw_pass_1 = _make_textured_particle_quad(0.52, POWDER_SMOKE_TEXTURE)
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = direction.normalized()
	smoke_mat.spread = 24.0
	smoke_mat.initial_velocity_min = 1.2
	smoke_mat.initial_velocity_max = 3.8
	smoke_mat.gravity = Vector3(0.0, 0.35, 0.0)
	smoke_mat.scale_min = 0.45
	smoke_mat.scale_max = 1.45
	smoke_mat.color = Color(0.25, 0.24, 0.22, 0.62)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.emitting = true

	_free_after(root, 1.1)


static func spawn_grape_muzzle_cone(parent: Node, position: Vector3, direction: Vector3) -> void:
	if parent == null:
		return

	var root := Node3D.new()
	root.name = "GrapeMuzzleCone"
	parent.add_child(root)
	root.global_position = position

	var pellet_flash := GPUParticles3D.new()
	pellet_flash.name = "LeadPelletFlash"
	pellet_flash.amount = 34
	pellet_flash.one_shot = true
	pellet_flash.explosiveness = 0.96
	pellet_flash.lifetime = 0.42
	pellet_flash.local_coords = false
	pellet_flash.draw_pass_1 = _make_particle_sphere(0.045)
	var process := ParticleProcessMaterial.new()
	process.direction = direction.normalized()
	process.spread = 34.0
	process.initial_velocity_min = 4.0
	process.initial_velocity_max = 9.0
	process.gravity = Vector3(0.0, -1.8, 0.0)
	process.scale_min = 0.40
	process.scale_max = 0.92
	process.color = Color(0.20, 0.18, 0.15, 0.72)
	pellet_flash.process_material = process
	root.add_child(pellet_flash)
	pellet_flash.emitting = true

	var dust := GPUParticles3D.new()
	dust.name = "GrapePowderDust"
	dust.amount = 42
	dust.one_shot = true
	dust.explosiveness = 0.72
	dust.lifetime = 0.92
	dust.local_coords = false
	dust.draw_pass_1 = _make_particle_sphere(0.10)
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = direction.normalized()
	dust_mat.spread = 46.0
	dust_mat.initial_velocity_min = 0.8
	dust_mat.initial_velocity_max = 3.6
	dust_mat.gravity = Vector3(0.0, 0.12, 0.0)
	dust_mat.scale_min = 0.55
	dust_mat.scale_max = 1.45
	dust_mat.color = Color(0.13, 0.12, 0.10, 0.46)
	dust.process_material = dust_mat
	root.add_child(dust)
	dust.emitting = true

	_free_after(root, 1.15)


static func spawn_grape_impact(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return

	var root := Node3D.new()
	root.name = "GrapeImpact"
	parent.add_child(root)
	root.global_position = position

	var impact_dir := -incoming_direction.normalized()
	if impact_dir.length_squared() < 0.01:
		impact_dir = Vector3.RIGHT

	var pellets := GPUParticles3D.new()
	pellets.name = "GrapePelletRicochet"
	pellets.amount = 28
	pellets.one_shot = true
	pellets.explosiveness = 0.98
	pellets.lifetime = 0.58
	pellets.local_coords = false
	pellets.draw_pass_1 = _make_particle_sphere(0.035)
	var pellet_mat := ParticleProcessMaterial.new()
	pellet_mat.direction = (impact_dir + Vector3.UP * 0.18).normalized()
	pellet_mat.spread = 58.0
	pellet_mat.initial_velocity_min = 2.2
	pellet_mat.initial_velocity_max = 7.8
	pellet_mat.gravity = Vector3(0.0, -4.2, 0.0)
	pellet_mat.scale_min = 0.35
	pellet_mat.scale_max = 0.88
	pellet_mat.color = Color(0.18, 0.16, 0.13, 0.78)
	pellets.process_material = pellet_mat
	root.add_child(pellets)
	pellets.emitting = true

	var dust := GPUParticles3D.new()
	dust.name = "GrapeImpactDust"
	dust.amount = 30
	dust.one_shot = true
	dust.explosiveness = 0.76
	dust.lifetime = 0.92
	dust.local_coords = false
	dust.draw_pass_1 = _make_particle_sphere(0.09)
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = (impact_dir + Vector3.UP * 0.35).normalized()
	dust_mat.spread = 64.0
	dust_mat.initial_velocity_min = 0.45
	dust_mat.initial_velocity_max = 2.2
	dust_mat.gravity = Vector3(0.0, -1.2, 0.0)
	dust_mat.scale_min = 0.55
	dust_mat.scale_max = 1.45
	dust_mat.color = Color(0.11, 0.10, 0.09, 0.42)
	dust.process_material = dust_mat
	root.add_child(dust)
	dust.emitting = true

	_free_after(root, 1.05)


static func add_cannon_trail(ball: Node3D, shot_mode := "round") -> void:
	var trail := GPUParticles3D.new()
	trail.name = "CannonTrail"
	trail.amount = 10
	trail.lifetime = 0.48
	trail.local_coords = false
	trail.emitting = true
	trail.draw_pass_1 = _make_particle_sphere(0.055)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.BACK
	process.spread = 180.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.0, 0.05, 0.0)
	process.scale_min = 0.25
	process.scale_max = 0.75
	match shot_mode:
		"chain":
			trail.name = "ChainShotTrail"
			trail.amount = 14
			process.spread = 125.0
			process.initial_velocity_min = 0.25
			process.initial_velocity_max = 0.9
			process.color = Color(0.23, 0.24, 0.22, 0.48)
		"grape":
			process.color = Color(0.11, 0.10, 0.09, 0.28)
		_:
			process.color = Color(0.14, 0.13, 0.12, 0.34)
	trail.process_material = process
	ball.add_child(trail)


static func spawn_broadside_smoke_bank(parent: Node, ship: Node3D, side: int, cannon_count := 4) -> void:
	if parent == null or ship == null or not is_instance_valid(ship) or side == 0:
		return
	var geometry := _get_broadside_geometry(ship, side, cannon_count)
	var class_weight := 1.0
	match String(ship.get("hull_class")):
		"Sloop": class_weight = 0.72
		"Frigate": class_weight = 1.08
		"Ship of the Line": class_weight = 1.34
		"Man o' War": class_weight = 1.62
	_play_audio(parent, "cannon", ship.global_position, lerpf(-0.5, 5.5, clampf((class_weight - 0.70) / 0.92, 0.0, 1.0)))
	if not _fx_budget_available(parent, &"broadside_smoke_fx", 6):
		return
	var muzzle_x := float(geometry.get("muzzle_x", 1.88 * float(side)))
	var muzzle_y := float(geometry.get("muzzle_y", 0.78))
	var cannon_positions: Array = geometry.get("cannon_positions", [])
	var flash_span := float(geometry.get("flash_span", 5.35))

	var root := Node3D.new()
	root.name = "BroadsideSmokeBank"
	parent.add_child(root)
	root.add_to_group("broadside_smoke_fx")
	root.global_transform = _get_ship_visual_transform(ship)

	var side_dir := Vector3.RIGHT * float(side)
	var smoke := GPUParticles3D.new()
	smoke.name = "PowderSmokeBank"
	var broadside_particle_count := clampi(int(float(cannon_count * 3) * class_weight), 20, 68)
	smoke.amount = _lod_particle_count(parent, ship.global_position, broadside_particle_count, 12)
	smoke.one_shot = true
	smoke.explosiveness = 0.64
	smoke.lifetime = 1.85 + class_weight * 0.48
	smoke.local_coords = true
	smoke.position = Vector3(muzzle_x, muzzle_y + 0.08, _layout_center(cannon_positions))
	smoke.draw_pass_1 = _make_textured_particle_quad(0.68, POWDER_SMOKE_TEXTURE)
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	smoke_mat.emission_box_extents = Vector3(0.10, 0.16, maxf(flash_span * 0.48, 0.8))
	smoke_mat.direction = (side_dir + Vector3.UP * 0.10).normalized()
	smoke_mat.spread = 58.0
	smoke_mat.initial_velocity_min = 1.1
	smoke_mat.initial_velocity_max = 3.7 + class_weight * 1.30
	smoke_mat.gravity = Vector3(0.0, 0.22, 0.0)
	smoke_mat.scale_min = 0.68 * class_weight
	smoke_mat.scale_max = 1.48 * class_weight
	smoke_mat.color = Color(0.34, 0.32, 0.29, 0.72)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.emitting = true

	var flash_line := MeshInstance3D.new()
	flash_line.name = "BroadsideFlashLine"
	var flash_mesh := BoxMesh.new()
	flash_mesh.size = Vector3(0.08 + class_weight * 0.035, 0.09 + class_weight * 0.04, flash_span)
	flash_line.mesh = flash_mesh
	flash_line.position = Vector3(muzzle_x, muzzle_y, _layout_center(cannon_positions))
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.52)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.30, 0.08)
	flash_mat.emission_energy_multiplier = 1.8
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_line.material_override = flash_mat
	root.add_child(flash_line)
	flash_line.visible = false

	var embers := GPUParticles3D.new()
	embers.name = "BroadsideEmbers"
	embers.amount = _lod_particle_count(parent, ship.global_position, clampi(cannon_count * 8, 16, 48), 8)
	embers.one_shot = true
	embers.explosiveness = 0.95
	embers.lifetime = 0.85
	embers.local_coords = true
	embers.position = Vector3(muzzle_x, muzzle_y, _layout_center(cannon_positions))
	embers.draw_pass_1 = _make_textured_particle_quad(0.11, SPARK_TEXTURE, true)
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_mat.emission_box_extents = Vector3(0.08, 0.10, maxf(flash_span * 0.48, 0.8))
	ember_mat.direction = (side_dir + Vector3.UP * 0.05).normalized()
	ember_mat.spread = 44.0
	ember_mat.initial_velocity_min = 1.6
	ember_mat.initial_velocity_max = 5.0
	ember_mat.gravity = Vector3(0.0, -2.8, 0.0)
	ember_mat.scale_min = 0.35
	ember_mat.scale_max = 0.90
	ember_mat.color = Color(1.0, 0.50, 0.12, 0.84)
	embers.process_material = ember_mat
	root.add_child(embers)
	embers.emitting = true

	_free_after(root, 3.05)


static func spawn_broadside_telegraph(parent: Node, ship: Node3D, side: int, duration := 0.65) -> void:
	if parent == null or ship == null or not is_instance_valid(ship) or side == 0:
		return
	var geometry := _get_broadside_geometry(ship, side, 4)
	var muzzle_x := float(geometry.get("muzzle_x", 1.68 * float(side)))
	var muzzle_y := float(geometry.get("muzzle_y", 0.68))
	var cannon_positions: Array = geometry.get("cannon_positions", [-2.35, -0.9, 0.55, 2.0])

	var root := Node3D.new()
	root.name = "BroadsideTelegraph"
	parent.add_child(root)
	var ship_visual_transform := _get_ship_visual_transform(ship)
	root.global_position = ship_visual_transform.origin

	var side_dir := ship_visual_transform.basis.x.normalized() * float(side)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.42, 0.12, 0.72)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.32, 0.08)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for z_value in cannon_positions:
		var z := float(z_value)
		var ember := MeshInstance3D.new()
		ember.name = "GunPortWarning"
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.20
		mesh.radial_segments = 8
		mesh.rings = 4
		ember.mesh = mesh
		ember.material_override = flash_mat
		var ember_position := ship_visual_transform * Vector3(muzzle_x, muzzle_y, z)
		root.add_child(ember)
		ember.global_position = ember_position

	var smoke := GPUParticles3D.new()
	smoke.name = "BroadsideTelegraphSmoke"
	smoke.amount = 72
	smoke.one_shot = true
	smoke.explosiveness = 0.28
	smoke.lifetime = duration + 0.35
	smoke.local_coords = false
	smoke.draw_pass_1 = _make_particle_sphere(0.12)
	var smoke_position := ship_visual_transform * Vector3(muzzle_x, muzzle_y + 0.04, _layout_center(cannon_positions))
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = (side_dir + Vector3.UP * 0.16).normalized()
	smoke_mat.spread = 34.0
	smoke_mat.initial_velocity_min = 0.45
	smoke_mat.initial_velocity_max = 1.85
	smoke_mat.gravity = Vector3(0.0, 0.18, 0.0)
	smoke_mat.scale_min = 0.45
	smoke_mat.scale_max = 1.25
	smoke_mat.color = Color(0.18, 0.16, 0.13, 0.48)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.global_position = smoke_position
	smoke.emitting = true

	_free_after(root, duration + 0.55)


static func _get_broadside_geometry(ship: Node3D, side: int, fallback_count: int) -> Dictionary:
	if ship.has_method("get_broadside_fx_geometry"):
		var geometry: Dictionary = ship.call("get_broadside_fx_geometry", side)
		var positions: Array = geometry.get("cannon_positions", [])
		geometry["flash_span"] = _layout_span(positions, float(geometry.get("hull_length", 8.4)) * 0.56)
		return geometry

	var positions: Array = []
	var count := maxi(fallback_count, 1)
	if count == 1:
		positions.append(0.0)
	else:
		for i in range(count):
			positions.append(lerpf(-2.35, 2.0, float(i) / float(count - 1)))
	return {
		"muzzle_x": 1.72 * float(side),
		"muzzle_y": 0.70,
		"cannon_positions": positions,
		"flash_span": _layout_span(positions, 5.35),
	}


static func _get_ship_visual_transform(ship: Node3D) -> Transform3D:
	if ship != null and ship.has_method("get_broadside_fx_transform"):
		return ship.call("get_broadside_fx_transform")
	return ship.global_transform if ship != null else Transform3D.IDENTITY


static func _layout_center(positions: Array) -> float:
	if positions.is_empty():
		return 0.0
	return (float(positions.front()) + float(positions.back())) * 0.5


static func _layout_span(positions: Array, fallback: float) -> float:
	if positions.size() < 2:
		return maxf(fallback, 1.2)
	return maxf(absf(float(positions.back()) - float(positions.front())) + 0.70, 1.2)


static func spawn_damage_callout(parent: Node, position: Vector3, report: Dictionary) -> void:
	if parent == null:
		return

	var root := Node3D.new()
	root.name = "DamageCallout"
	parent.add_child(root)
	root.global_position = position + Vector3.UP * 1.45

	var zone := String(report.get("zone", "hull")).to_upper()
	var shot := String(report.get("shot_mode", "round")).to_upper()
	var amount := int(ceil(_get_report_zone_damage(report, zone)))
	var critical := bool(report.get("critical", false))
	var angle := String(report.get("hit_angle", "solid")).to_upper()
	var prefix := ""
	if critical:
		prefix = "CRITICAL "
	elif angle != "SOLID":
		prefix = "%s " % angle

	var label := Label3D.new()
	label.name = "DamageCalloutLabel"
	label.text = "%s%s %s  %d" % [prefix, shot, zone, amount]
	label.font_size = 42 if critical else 34
	label.outline_size = 8
	label.outline_modulate = Color(0.02, 0.015, 0.01, 0.92)
	label.modulate = _damage_callout_color(zone, critical)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)

	var marker := MeshInstance3D.new()
	marker.name = "DamageCalloutPip"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.12 if not critical else 0.18
	marker_mesh.height = 0.20 if not critical else 0.30
	marker_mesh.radial_segments = 10
	marker_mesh.rings = 4
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, -0.32, 0.0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = _damage_callout_color(zone, critical)
	marker_mat.emission_enabled = true
	marker_mat.emission = _damage_callout_color(zone, critical)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_mat
	root.add_child(marker)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "global_position", root.global_position + Vector3.UP * (1.3 if critical else 0.95), 0.86)
	tween.tween_property(label, "modulate:a", 0.0, 0.86).set_delay(0.18)
	tween.tween_property(marker_mat, "albedo_color:a", 0.0, 0.72).set_delay(0.22)

	_free_after(root, 1.15)


static func _get_report_zone_damage(report: Dictionary, zone: String) -> float:
	match zone:
		"SAILS":
			return float(report.get("sail_damage", 0.0))
		"RUDDER":
			return float(report.get("rudder_damage", 0.0))
		"CANNONS":
			return float(report.get("port_cannon_damage", 0.0)) + float(report.get("starboard_cannon_damage", 0.0))
	return float(report.get("health_damage", 0.0))


static func spawn_water_splash(parent: Node, position: Vector3, intensity := 1.0) -> void:
	if parent == null:
		return
	if not _fx_budget_available(parent, &"water_impact_fx", 4):
		return
	_play_audio(parent, "splash", position, -5.0)
	var impact_scale := clampf(intensity, 0.65, 2.0)

	var root := Node3D.new()
	root.name = "WaterSplash"
	parent.add_child(root)
	root.add_to_group("water_impact_fx")
	root.global_position = Vector3(position.x, 0.02, position.z)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.28 * impact_scale
	ring_mesh.outer_radius = 0.36 * impact_scale
	ring_mesh.ring_segments = 16
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.70, 0.88, 0.90, 0.30)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.roughness = 0.28
	ring.material_override = ring_mat
	root.add_child(ring)

	var column := GPUParticles3D.new()
	column.name = "WaterColumn"
	column.amount = _lod_particle_count(parent, position, clampi(int(round(6.0 * impact_scale)), 4, 11), 3)
	column.one_shot = true
	column.explosiveness = 0.94
	column.lifetime = 0.62
	column.local_coords = false
	column.draw_pass_1 = _make_particle_box(Vector3(0.035, 0.16, 0.035))
	var column_mat := ParticleProcessMaterial.new()
	column_mat.direction = Vector3.UP
	column_mat.spread = 11.0
	column_mat.initial_velocity_min = 2.2 * sqrt(impact_scale)
	column_mat.initial_velocity_max = 4.1 * sqrt(impact_scale)
	column_mat.gravity = Vector3(0.0, -8.8, 0.0)
	column_mat.scale_min = 0.65
	column_mat.scale_max = 1.15
	column_mat.color = Color(0.66, 0.86, 0.89, 0.62)
	column.process_material = column_mat
	root.add_child(column)
	column.emitting = true
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.65, 1.0, 1.65), 0.58 + 0.12 * (impact_scale - 1.0))
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.62).set_delay(0.08)

	_free_after(root, 0.82)


static func spawn_rogue_wave_impact(parent: Node, position: Vector3, force := 1.0) -> void:
	if parent == null or not _fx_budget_available(parent, &"rogue_wave_impact_fx", 4):
		return
	var strength := clampf(force, 0.2, 1.0)
	var root := Node3D.new()
	root.name = "RogueWaveImpact"
	parent.add_child(root)
	root.add_to_group("rogue_wave_impact_fx")
	root.global_position = Vector3(position.x, 0.02, position.z)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = lerpf(1.5, 2.6, strength)
	ring_mesh.outer_radius = lerpf(1.8, 3.1, strength)
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.72, 0.95, 0.94, 0.64)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.28, 0.54, 0.55)
	ring_mat.emission_energy_multiplier = 0.42
	ring.material_override = ring_mat
	root.add_child(ring)

	var spray := GPUParticles3D.new()
	spray.name = "DeckWashSpray"
	spray.amount = _lod_particle_count(parent, position, clampi(int(22.0 + strength * 24.0), 26, 46), 14)
	spray.one_shot = true
	spray.explosiveness = 0.82
	spray.lifetime = 1.35
	spray.local_coords = false
	spray.draw_pass_1 = _make_textured_particle_quad(0.34, WATER_SPRAY_TEXTURE)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 66.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = lerpf(5.0, 9.2, strength)
	process.gravity = Vector3(0.0, -6.4, 0.0)
	process.scale_min = 0.45
	process.scale_max = 1.45
	process.color = Color(0.70, 0.93, 0.94, 0.72)
	spray.process_material = process
	root.add_child(spray)
	spray.emitting = true

	root.scale = Vector3(0.72, 1.0, 0.72)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3(2.1, 1.0, 2.1), 0.82)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.92).set_delay(0.18)
	_free_after(root, 1.55)


static func spawn_mortar_target(parent: Node, position: Vector3, duration: float, radius: float) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "MortarTarget"
	parent.add_child(root)
	root.global_position = Vector3(position.x, 0.035, position.z)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.88
	ring_mesh.outer_radius = radius
	ring_mesh.ring_segments = 32
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.92, 0.74, 0.28, 0.18)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.92, 0.55, 0.10)
	ring_mat.emission_energy_multiplier = 0.75
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	root.add_child(ring)

	var inner := MeshInstance3D.new()
	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = radius * 0.16
	inner_mesh.bottom_radius = radius * 0.16
	inner_mesh.height = 0.025
	inner_mesh.radial_segments = 16
	inner.mesh = inner_mesh
	inner.material_override = ring_mat
	root.add_child(inner)

	root.scale = Vector3(1.35, 1.0, 1.35)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3(0.70, 1.0, 0.70), duration)
	tween.tween_property(ring_mat, "albedo_color:a", 0.68, duration * 0.82)
	_free_after(root, duration + 0.18)


static func spawn_near_miss_splash(parent: Node, position: Vector3, _target_ship: Node3D = null) -> void:
	if parent == null:
		return
	if not _fx_budget_available(parent, &"water_impact_fx", 2):
		return

	var root := Node3D.new()
	root.name = "NearMissSplash"
	parent.add_child(root)
	root.add_to_group("water_impact_fx")
	root.global_position = Vector3(position.x, 0.02, position.z)

	var ring := MeshInstance3D.new()
	ring.name = "ShockRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.46
	ring_mesh.outer_radius = 0.58
	ring_mesh.ring_segments = 18
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.72, 0.90, 0.92, 0.34)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.roughness = 0.22
	ring.material_override = ring_mat
	root.add_child(ring)

	var column := GPUParticles3D.new()
	column.name = "WaterColumn"
	column.amount = _lod_particle_count(parent, position, 8, 4)
	column.one_shot = true
	column.explosiveness = 0.92
	column.lifetime = 0.82
	column.local_coords = false
	column.draw_pass_1 = _make_particle_box(Vector3(0.045, 0.22, 0.045))
	var column_mat := ParticleProcessMaterial.new()
	column_mat.direction = Vector3.UP
	column_mat.spread = 13.0
	column_mat.initial_velocity_min = 3.4
	column_mat.initial_velocity_max = 6.2
	column_mat.gravity = Vector3(0.0, -9.2, 0.0)
	column_mat.scale_min = 0.60
	column_mat.scale_max = 1.15
	column_mat.color = Color(0.68, 0.88, 0.90, 0.68)
	column.process_material = column_mat
	root.add_child(column)
	column.emitting = true

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.55, 1.0, 1.55), 0.72)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.78).set_delay(0.10)
	_free_after(root, 1.05)


static func spawn_hull_hit(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "hull_impact", position, 0.5)
	if not _fx_budget_available(parent, &"impact_fx", 14):
		return

	var root := Node3D.new()
	root.name = "HullHit"
	parent.add_child(root)
	root.add_to_group("impact_fx")
	root.global_position = position

	var splinters := GPUParticles3D.new()
	splinters.name = "WoodSplinters"
	splinters.amount = _lod_particle_count(parent, position, 13, 5)
	splinters.one_shot = true
	splinters.explosiveness = 0.94
	splinters.lifetime = 1.15
	splinters.local_coords = false
	splinters.draw_pass_1 = _make_particle_box(Vector3(0.025, 0.018, 0.22))
	var splinter_mat := ParticleProcessMaterial.new()
	splinter_mat.direction = -incoming_direction.normalized()
	splinter_mat.spread = 42.0
	splinter_mat.initial_velocity_min = 1.4
	splinter_mat.initial_velocity_max = 4.1
	splinter_mat.angular_velocity_min = -7.0
	splinter_mat.angular_velocity_max = 7.0
	splinter_mat.gravity = Vector3(0.0, -7.2, 0.0)
	splinter_mat.scale_min = 0.65
	splinter_mat.scale_max = 1.10
	splinter_mat.color = Color(0.42, 0.23, 0.10, 0.88)
	splinters.process_material = splinter_mat
	root.add_child(splinters)
	splinters.emitting = true

	var debris := GPUParticles3D.new()
	debris.name = "HullDebris"
	debris.amount = _lod_particle_count(parent, position, 3, 1)
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 1.45
	debris.local_coords = false
	debris.draw_pass_1 = _make_particle_box(Vector3(0.065, 0.035, 0.34))
	var debris_mat := ParticleProcessMaterial.new()
	debris_mat.direction = (-incoming_direction.normalized() + Vector3.UP * 0.45).normalized()
	debris_mat.spread = 34.0
	debris_mat.initial_velocity_min = 0.8
	debris_mat.initial_velocity_max = 2.4
	debris_mat.angular_velocity_min = -4.0
	debris_mat.angular_velocity_max = 4.0
	debris_mat.gravity = Vector3(0.0, -7.4, 0.0)
	debris_mat.scale_min = 0.7
	debris_mat.scale_max = 1.25
	debris_mat.color = Color(0.24, 0.13, 0.06, 0.92)
	debris.process_material = debris_mat
	root.add_child(debris)
	debris.emitting = true

	var dust := GPUParticles3D.new()
	dust.name = "WoodDust"
	dust.amount = _lod_particle_count(parent, position, 7, 3)
	dust.one_shot = true
	dust.explosiveness = 0.84
	dust.lifetime = 0.62
	dust.local_coords = false
	dust.draw_pass_1 = _make_particle_sphere(0.065)
	var dust_mat := ParticleProcessMaterial.new()
	var dust_direction := -incoming_direction.normalized()
	if dust_direction.length_squared() < 0.01:
		dust_direction = Vector3.RIGHT
	dust_mat.direction = (dust_direction + Vector3.UP * 0.28).normalized()
	dust_mat.spread = 48.0
	dust_mat.initial_velocity_min = 0.35
	dust_mat.initial_velocity_max = 1.35
	dust_mat.gravity = Vector3(0.0, -1.9, 0.0)
	dust_mat.scale_min = 0.45
	dust_mat.scale_max = 1.0
	dust_mat.color = Color(0.36, 0.22, 0.11, 0.42)
	dust.process_material = dust_mat
	root.add_child(dust)
	dust.emitting = true

	_free_after(root, 1.75)


static func spawn_powder_explosion(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	if not _fx_budget_available(parent, &"explosion_fx", 6):
		return

	var root := Node3D.new()
	root.name = "PowderExplosion"
	parent.add_child(root)
	root.add_to_group("explosion_fx")
	root.global_position = position

	var flash := MeshInstance3D.new()
	flash.name = "PowderFlash"
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(3.8, 3.8)
	flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_texture = EXPLOSION_TEXTURE
	flash_mat.albedo_color = Color(1.0, 0.78, 0.48, 0.88)
	flash_mat.emission_enabled = true
	flash_mat.emission_texture = EXPLOSION_TEXTURE
	flash_mat.emission = Color(1.0, 0.34, 0.06)
	flash_mat.emission_energy_multiplier = 1.8
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.billboard_keep_scale = true
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = flash_mat
	root.add_child(flash)
	_fade_muzzle_flash(flash, flash_mat, 0.22)

	var blast_dir := -incoming_direction.normalized()
	if blast_dir.length_squared() < 0.01:
		blast_dir = Vector3.RIGHT

	var sparks := GPUParticles3D.new()
	sparks.name = "PowderSparks"
	sparks.amount = _lod_particle_count(parent, position, 90, 24)
	sparks.one_shot = true
	sparks.explosiveness = 0.98
	sparks.lifetime = 1.0
	sparks.local_coords = false
	sparks.draw_pass_1 = _make_particle_sphere(0.055)
	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = (blast_dir + Vector3.UP * 0.24).normalized()
	spark_mat.spread = 70.0
	spark_mat.initial_velocity_min = 3.2
	spark_mat.initial_velocity_max = 10.5
	spark_mat.gravity = Vector3(0.0, -5.2, 0.0)
	spark_mat.scale_min = 0.45
	spark_mat.scale_max = 1.15
	spark_mat.color = Color(1.0, 0.48, 0.10, 0.90)
	sparks.process_material = spark_mat
	root.add_child(sparks)
	sparks.emitting = true

	var smoke := GPUParticles3D.new()
	smoke.name = "PowderSmoke"
	smoke.amount = _lod_particle_count(parent, position, 132, 36)
	smoke.one_shot = true
	smoke.explosiveness = 0.78
	smoke.lifetime = 2.25
	smoke.local_coords = false
	smoke.draw_pass_1 = _make_textured_particle_quad(0.58, BLACK_SMOKE_TEXTURE)
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = (blast_dir + Vector3.UP * 0.62).normalized()
	smoke_mat.spread = 64.0
	smoke_mat.initial_velocity_min = 1.1
	smoke_mat.initial_velocity_max = 4.8
	smoke_mat.gravity = Vector3(0.0, 0.18, 0.0)
	smoke_mat.scale_min = 1.0
	smoke_mat.scale_max = 2.8
	smoke_mat.color = Color(0.045, 0.040, 0.035, 0.70)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.emitting = true

	var debris := GPUParticles3D.new()
	debris.name = "PowderDebris"
	debris.amount = _lod_particle_count(parent, position, 22, 8)
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 1.65
	debris.local_coords = false
	debris.draw_pass_1 = _make_particle_box(Vector3(0.16, 0.07, 0.32))
	var debris_mat := ParticleProcessMaterial.new()
	debris_mat.direction = (blast_dir + Vector3.UP * 0.42).normalized()
	debris_mat.spread = 62.0
	debris_mat.initial_velocity_min = 2.0
	debris_mat.initial_velocity_max = 7.2
	debris_mat.angular_velocity_min = -20.0
	debris_mat.angular_velocity_max = 20.0
	debris_mat.gravity = Vector3(0.0, -6.8, 0.0)
	debris_mat.scale_min = 0.75
	debris_mat.scale_max = 1.35
	debris_mat.color = Color(0.22, 0.11, 0.045, 0.95)
	debris.process_material = debris_mat
	root.add_child(debris)
	debris.emitting = true

	_free_after(root, 2.65)


static func spawn_sail_rip(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "sail", position, -2.0)

	var root := Node3D.new()
	root.name = "SailRip"
	parent.add_child(root)
	root.global_position = position

	var cloth := GPUParticles3D.new()
	cloth.name = "CanvasShreds"
	cloth.amount = _lod_particle_count(parent, position, 34, 12)
	cloth.one_shot = true
	cloth.explosiveness = 0.92
	cloth.lifetime = 1.25
	cloth.local_coords = false
	cloth.draw_pass_1 = _make_particle_box(Vector3(0.18, 0.018, 0.055))
	var cloth_mat := ParticleProcessMaterial.new()
	var rip_dir := -incoming_direction.normalized()
	if rip_dir.length_squared() < 0.01:
		rip_dir = Vector3.RIGHT
	cloth_mat.direction = (rip_dir + Vector3.DOWN * 0.10).normalized()
	cloth_mat.spread = 46.0
	cloth_mat.initial_velocity_min = 1.4
	cloth_mat.initial_velocity_max = 5.6
	cloth_mat.angular_velocity_min = -18.0
	cloth_mat.angular_velocity_max = 18.0
	cloth_mat.gravity = Vector3(0.0, -2.2, 0.0)
	cloth_mat.scale_min = 0.65
	cloth_mat.scale_max = 1.45
	cloth_mat.color = Color(0.64, 0.59, 0.48, 0.86)
	cloth.process_material = cloth_mat
	root.add_child(cloth)
	cloth.emitting = true

	var dust := GPUParticles3D.new()
	dust.name = "CanvasDust"
	dust.amount = _lod_particle_count(parent, position, 28, 10)
	dust.one_shot = true
	dust.explosiveness = 0.76
	dust.lifetime = 0.95
	dust.local_coords = false
	dust.draw_pass_1 = _make_particle_sphere(0.075)
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3.UP
	dust_mat.spread = 62.0
	dust_mat.initial_velocity_min = 0.25
	dust_mat.initial_velocity_max = 1.3
	dust_mat.gravity = Vector3(0.0, -0.75, 0.0)
	dust_mat.scale_min = 0.7
	dust_mat.scale_max = 1.6
	dust_mat.color = Color(0.44, 0.41, 0.34, 0.42)
	dust.process_material = dust_mat
	root.add_child(dust)
	dust.emitting = true

	_free_after(root, 1.45)


static func spawn_deck_hit(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "hull_impact", position, -0.5)
	if not _fx_budget_available(parent, &"impact_fx", 14):
		return

	var root := Node3D.new()
	root.name = "DeckHit"
	parent.add_child(root)
	root.add_to_group("impact_fx")
	root.global_position = position

	var out_dir := -incoming_direction.normalized()
	if out_dir.length_squared() < 0.01:
		out_dir = Vector3.RIGHT
	var chips := GPUParticles3D.new()
	chips.name = "DeckChips"
	chips.amount = _lod_particle_count(parent, position, 14, 5)
	chips.one_shot = true
	chips.explosiveness = 0.94
	chips.lifetime = 0.92
	chips.local_coords = false
	chips.draw_pass_1 = _make_particle_box(Vector3(0.04, 0.025, 0.16))
	var chip_mat := ParticleProcessMaterial.new()
	chip_mat.direction = (out_dir * 0.42 + Vector3.UP).normalized()
	chip_mat.spread = 58.0
	chip_mat.initial_velocity_min = 1.0
	chip_mat.initial_velocity_max = 3.8
	chip_mat.angular_velocity_min = -9.0
	chip_mat.angular_velocity_max = 9.0
	chip_mat.gravity = Vector3(0.0, -7.5, 0.0)
	chip_mat.scale_min = 0.58
	chip_mat.scale_max = 1.05
	chip_mat.color = Color(0.46, 0.28, 0.12, 0.90)
	chips.process_material = chip_mat
	root.add_child(chips)
	chips.emitting = true

	var dust := GPUParticles3D.new()
	dust.name = "DeckDust"
	dust.amount = _lod_particle_count(parent, position, 6, 2)
	dust.one_shot = true
	dust.explosiveness = 0.80
	dust.lifetime = 0.52
	dust.local_coords = false
	dust.draw_pass_1 = _make_particle_sphere(0.055)
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3.UP
	dust_mat.spread = 64.0
	dust_mat.initial_velocity_min = 0.25
	dust_mat.initial_velocity_max = 1.0
	dust_mat.gravity = Vector3(0.0, -1.5, 0.0)
	dust_mat.scale_min = 0.45
	dust_mat.scale_max = 0.9
	dust_mat.color = Color(0.40, 0.27, 0.15, 0.34)
	dust.process_material = dust_mat
	root.add_child(dust)
	dust.emitting = true

	_free_after(root, 1.08)


static func spawn_cannon_deck_hit(parent: Node, position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "cannon_impact", position, 1.0)
	if not _fx_budget_available(parent, &"impact_fx", 14):
		return

	var root := Node3D.new()
	root.name = "CannonDeckHit"
	parent.add_child(root)
	root.add_to_group("impact_fx")
	root.global_position = position

	var burst := GPUParticles3D.new()
	burst.name = "GunDeckSparks"
	burst.amount = _lod_particle_count(parent, position, 16, 6)
	burst.one_shot = true
	burst.explosiveness = 0.94
	burst.lifetime = 0.72
	burst.local_coords = false
	burst.draw_pass_1 = _make_textured_particle_quad(0.12, SPARK_TEXTURE, true)
	var burst_mat := ParticleProcessMaterial.new()
	var out_dir := -incoming_direction.normalized()
	if out_dir.length_squared() < 0.01:
		out_dir = Vector3.RIGHT
	burst_mat.direction = (out_dir + Vector3.UP * 0.20).normalized()
	burst_mat.spread = 48.0
	burst_mat.initial_velocity_min = 2.0
	burst_mat.initial_velocity_max = 6.6
	burst_mat.gravity = Vector3(0.0, -3.6, 0.0)
	burst_mat.scale_min = 0.32
	burst_mat.scale_max = 0.82
	burst_mat.color = Color(1.0, 0.50, 0.14, 0.88)
	burst.process_material = burst_mat
	root.add_child(burst)
	burst.emitting = true

	var smoke := GPUParticles3D.new()
	smoke.name = "GunDeckSmoke"
	smoke.amount = _lod_particle_count(parent, position, 10, 4)
	smoke.one_shot = true
	smoke.explosiveness = 0.68
	smoke.lifetime = 0.78
	smoke.local_coords = false
	smoke.draw_pass_1 = _make_textured_particle_quad(0.34, BLACK_SMOKE_TEXTURE)
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3.UP
	smoke_mat.spread = 46.0
	smoke_mat.initial_velocity_min = 0.5
	smoke_mat.initial_velocity_max = 1.4
	smoke_mat.gravity = Vector3(0.0, 0.22, 0.0)
	smoke_mat.scale_min = 0.7
	smoke_mat.scale_max = 1.15
	smoke_mat.color = Color(0.07, 0.065, 0.058, 0.42)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.emitting = true

	var shutters := GPUParticles3D.new()
	shutters.name = "GunportShards"
	shutters.amount = _lod_particle_count(parent, position, 4, 2)
	shutters.one_shot = true
	shutters.explosiveness = 1.0
	shutters.lifetime = 1.0
	shutters.local_coords = false
	shutters.draw_pass_1 = _make_particle_box(Vector3(0.06, 0.04, 0.20))
	var shutter_mat := ParticleProcessMaterial.new()
	shutter_mat.direction = (out_dir + Vector3.UP * 0.35).normalized()
	shutter_mat.spread = 38.0
	shutter_mat.initial_velocity_min = 1.1
	shutter_mat.initial_velocity_max = 3.1
	shutter_mat.angular_velocity_min = -11.0
	shutter_mat.angular_velocity_max = 11.0
	shutter_mat.gravity = Vector3(0.0, -6.8, 0.0)
	shutter_mat.color = Color(0.20, 0.11, 0.055, 0.94)
	shutters.process_material = shutter_mat
	root.add_child(shutters)
	shutters.emitting = true

	_free_after(root, 1.25)


static func spawn_sinking_burst(parent: Node, position: Vector3, hull_class := "Brig", stage := 0) -> void:
	if parent == null:
		return
	if not _fx_budget_available(parent, &"sinking_fx", 4):
		return
	var class_scale := 1.0
	match hull_class:
		"Sloop": class_scale = 0.62
		"Frigate": class_scale = 1.12
		"Ship of the Line": class_scale = 1.38
		"Man o' War": class_scale = 1.62
	var splash_count := clampi(int(round(2.0 + class_scale + float(stage))), 2, 5)

	for i in range(splash_count):
		var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-3.2, 3.2)) * class_scale
		spawn_water_splash(parent, position + offset)

	var root := Node3D.new()
	root.name = "SinkingBurst"
	parent.add_child(root)
	root.add_to_group("sinking_fx")
	root.global_position = position + Vector3.UP * 1.0

	var smoke := GPUParticles3D.new()
	smoke.amount = _lod_particle_count(parent, position, clampi(int(38.0 * class_scale) + stage * 10, 30, 82), 18)
	smoke.one_shot = true
	smoke.explosiveness = 0.72
	smoke.lifetime = 2.4
	smoke.local_coords = false
	smoke.draw_pass_1 = _make_textured_particle_quad(0.52, BLACK_SMOKE_TEXTURE)
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3.UP
	smoke_mat.spread = 52.0
	smoke_mat.initial_velocity_min = 1.0
	smoke_mat.initial_velocity_max = 3.4
	smoke_mat.gravity = Vector3(0.0, 0.32, 0.0)
	smoke_mat.scale_min = 0.72 * class_scale
	smoke_mat.scale_max = 1.82 * class_scale
	smoke_mat.color = Color(0.035, 0.032, 0.03, 0.68)
	smoke.process_material = smoke_mat
	root.add_child(smoke)
	smoke.emitting = true

	_free_after(root, 2.8)


static func spawn_boarding_capture(parent: Node, position: Vector3) -> void:
	if parent == null:
		return
	_play_audio(parent, "boarding", position, 0.0)

	var root := Node3D.new()
	root.name = "BoardingCapture"
	parent.add_child(root)
	root.global_position = position + Vector3.UP * 2.15

	var banner := Label3D.new()
	banner.name = "BoardingCaptureLabel"
	banner.text = "CAPTURED"
	banner.font_size = 44
	banner.outline_size = 8
	banner.outline_modulate = Color(0.02, 0.015, 0.01, 0.92)
	banner.modulate = Color(1.0, 0.84, 0.40, 0.96)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.no_depth_test = true
	root.add_child(banner)

	var flare := GPUParticles3D.new()
	flare.name = "BoardingCaptureSparks"
	flare.amount = 54
	flare.one_shot = true
	flare.explosiveness = 0.92
	flare.lifetime = 0.95
	flare.local_coords = false
	flare.draw_pass_1 = _make_textured_particle_quad(0.14, SPARK_TEXTURE, true)
	var flare_mat := ParticleProcessMaterial.new()
	flare_mat.direction = Vector3.UP
	flare_mat.spread = 72.0
	flare_mat.initial_velocity_min = 1.1
	flare_mat.initial_velocity_max = 4.8
	flare_mat.gravity = Vector3(0.0, -2.5, 0.0)
	flare_mat.scale_min = 0.35
	flare_mat.scale_max = 0.95
	flare_mat.color = Color(1.0, 0.72, 0.22, 0.86)
	flare.process_material = flare_mat
	root.add_child(flare)
	flare.emitting = true

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "global_position", root.global_position + Vector3.UP * 1.0, 1.05)
	tween.tween_property(banner, "modulate:a", 0.0, 1.0).set_delay(0.32)

	_free_after(root, 1.45)


static func spawn_boarding_clash(parent: Node, position: Vector3) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "BoardingClash"
	parent.add_child(root)
	root.global_position = position + Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.40), randf_range(-0.55, 0.55))

	var sparks := GPUParticles3D.new()
	sparks.name = "SteelSparks"
	sparks.amount = 12
	sparks.one_shot = true
	sparks.explosiveness = 0.96
	sparks.lifetime = 0.42
	sparks.local_coords = false
	sparks.draw_pass_1 = _make_textured_particle_quad(0.08, SPARK_TEXTURE, true)
	var sparks_mat := ParticleProcessMaterial.new()
	sparks_mat.direction = Vector3.UP
	sparks_mat.spread = 82.0
	sparks_mat.initial_velocity_min = 0.8
	sparks_mat.initial_velocity_max = 2.7
	sparks_mat.gravity = Vector3(0.0, -4.2, 0.0)
	sparks_mat.scale_min = 0.35
	sparks_mat.scale_max = 0.82
	sparks_mat.color = Color(1.0, 0.72, 0.24, 0.82)
	sparks.process_material = sparks_mat
	root.add_child(sparks)
	sparks.emitting = true

	var flash := MeshInstance3D.new()
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(0.32, 0.32)
	flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_texture = SPARK_TEXTURE
	flash_mat.albedo_color = Color(1.0, 0.55, 0.16, 0.72)
	flash_mat.emission_enabled = true
	flash_mat.emission_texture = SPARK_TEXTURE
	flash_mat.emission = Color(1.0, 0.28, 0.06)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.billboard_keep_scale = true
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = flash_mat
	root.add_child(flash)
	var tween := root.create_tween()
	tween.tween_property(flash, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
	_free_after(root, 0.62)


static func _make_textured_particle_quad(size: float, texture: Texture2D, additive := false) -> QuadMesh:
	var cache_key := "quad:%s:%.3f:%s" % [texture.resource_path, size, additive]
	if _particle_mesh_cache.has(cache_key):
		return _particle_mesh_cache[cache_key] as QuadMesh
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	_particle_mesh_cache[cache_key] = mesh
	return mesh


static func _make_particle_sphere(radius: float) -> SphereMesh:
	var cache_key := "sphere:%.3f" % radius
	if _particle_mesh_cache.has(cache_key):
		return _particle_mesh_cache[cache_key] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_particle_mesh_cache[cache_key] = mesh
	return mesh


static func _make_particle_box(size: Vector3) -> BoxMesh:
	var cache_key := "box:%.3f:%.3f:%.3f" % [size.x, size.y, size.z]
	if _particle_mesh_cache.has(cache_key):
		return _particle_mesh_cache[cache_key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_particle_mesh_cache[cache_key] = mesh
	return mesh


static func _damage_callout_color(zone: String, critical: bool) -> Color:
	if critical:
		return Color(1.0, 0.42, 0.18, 0.96)
	match zone:
		"SAILS":
			return Color(0.66, 0.92, 1.0, 0.92)
		"CANNONS":
			return Color(1.0, 0.74, 0.32, 0.94)
		"RUDDER":
			return Color(0.78, 0.88, 1.0, 0.92)
	return Color(0.96, 0.84, 0.48, 0.92)


static func _play_audio(parent: Node, event_name: String, position: Vector3, volume_db := 0.0) -> void:
	if parent == null or parent.get_tree() == null:
		return
	var audio := parent.get_tree().get_first_node_in_group("combat_audio")
	if audio == null:
		return
	if audio.has_method("play_spatial"):
		audio.play_spatial(event_name, position, volume_db)


static func _fade_muzzle_flash(flash: MeshInstance3D, material: StandardMaterial3D, duration: float) -> void:
	if flash == null:
		return
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", flash.scale * 0.06, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if material != null:
		var faded_color := material.albedo_color
		faded_color.a = 0.0
		tween.tween_property(material, "albedo_color", faded_color, duration)
		tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(flash.hide)


static func _free_after(node: Node, seconds: float) -> void:
	if node == null:
		return
	node.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
