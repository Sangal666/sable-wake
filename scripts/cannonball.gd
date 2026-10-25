extends Area3D

const CombatFx := preload("res://scripts/combat_fx.gd")
const MAX_ACTIVE_PROJECTILES := 128
const MAX_POOLED_PROJECTILES := 72

static var _inactive_pool: Array[Area3D] = []
static var _ship_cache: Array[Node] = []
static var _ship_cache_tree_id := 0
static var _ship_cache_physics_frame := -1

@export var ballistic_gravity := 9.4
@export var hit_radius := 1.15
@export var near_miss_radius := 9.0
@export var lifetime := 4.2

var velocity := Vector3.ZERO
var damage := 10.0
var source_ship: Node
var shot_mode := "round"
var shot_profile := {}
var _age := 0.0
var _spent := false


static func acquire(parent: Node, mode: String, profile: Dictionary) -> Area3D:
	if parent == null or parent.get_tree() == null:
		return null
	if parent.get_tree().get_nodes_in_group("cannonballs").size() >= MAX_ACTIVE_PROJECTILES:
		return null
	while not _inactive_pool.is_empty():
		var pooled: Area3D = _inactive_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		if pooled.get_parent() != parent:
			pooled.reparent(parent)
		pooled.call("_activate_for_shot", mode, profile)
		return pooled
	var script: GDScript = load("res://scripts/cannonball.gd")
	var ball: Area3D = script.new()
	ball.call("configure_shot", mode, profile)
	parent.add_child(ball)
	return ball

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("cannonballs")
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_build_visual()
	if shot_mode == "mortar" or get_tree().get_nodes_in_group("cannonballs").size() <= 12:
		CombatFx.add_cannon_trail(self, shot_mode)


func _activate_for_shot(mode: String, profile: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_age = 0.0
	_spent = false
	velocity = Vector3.ZERO
	damage = 10.0
	source_ship = null
	ballistic_gravity = 9.4
	hit_radius = 1.15
	near_miss_radius = 9.0
	lifetime = 4.2
	configure_shot(mode, profile)
	visible = true
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 1
	set_physics_process(true)
	if not is_in_group("cannonballs"):
		add_to_group("cannonballs")
	_build_visual()
	if shot_mode == "mortar" or get_tree().get_nodes_in_group("cannonballs").size() <= 12:
		CombatFx.add_cannon_trail(self, shot_mode)


func _retire() -> void:
	if not is_instance_valid(self) or bool(get_meta("pooled", false)):
		return
	_spent = true
	set_meta("pooled", true)
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	visible = false
	remove_from_group("cannonballs")
	call_deferred("_store_in_pool")


func _store_in_pool() -> void:
	if not is_instance_valid(self):
		return
	if _inactive_pool.size() >= MAX_POOLED_PROJECTILES:
		queue_free()
		return
	_inactive_pool.append(self)


func _clear_pool_marker() -> void:
	set_meta("pooled", false)


func configure_shot(mode: String, profile: Dictionary) -> void:
	shot_mode = mode
	shot_profile = profile
	hit_radius = float(profile.get("hit_radius", hit_radius))


func launch(direction: Vector3, inherited_velocity: Vector3, shot_speed: float, source: Node, shot_damage: float, vertical_boost := 3.6) -> void:
	launch_velocity(direction.normalized() * shot_speed + inherited_velocity + Vector3.UP * vertical_boost, source, shot_damage)


func launch_velocity(initial_velocity: Vector3, source: Node, shot_damage: float) -> void:
	source_ship = source
	damage = shot_damage
	velocity = initial_velocity


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		_retire()
		return

	global_position += velocity * delta
	velocity.y -= ballistic_gravity * delta
	rotation += Vector3(8.0, 5.0, 3.0) * delta

	if global_position.y < -0.45:
		if shot_mode == "mortar":
			_explode_mortar()
			return
		var near_ship := _find_near_miss_ship()
		if near_ship:
			CombatFx.spawn_near_miss_splash(_effect_parent(), global_position, near_ship)
			if near_ship.has_method("register_near_miss"):
				near_ship.register_near_miss(global_position, source_ship)
		else:
			CombatFx.spawn_water_splash(_effect_parent(), global_position)
		_retire()
		return

	for ship in _combat_ships():
		if ship == source_ship or ship.get("is_sunk") or _is_friendly(ship) or _is_ai_prize_protected(ship):
			continue
		if ship.has_method("is_projectile_point_inside"):
			if bool(ship.is_projectile_point_inside(global_position, shot_mode)):
				_hit(ship)
				return
			continue
		var target_radius := hit_radius
		if ship.has_method("get_projectile_hit_radius"):
			target_radius = minf(float(ship.get_projectile_hit_radius(shot_mode)), hit_radius * 1.65)
		if global_position.distance_to(ship.global_position + Vector3.UP * 0.45) <= target_radius:
			_hit(ship)
			return


func _on_body_entered(body: Node) -> void:
	if body == source_ship or _is_friendly(body) or _is_ai_prize_protected(body):
		return
	_hit(body)


func _is_friendly(body: Node) -> bool:
	if source_ship == null or body == null:
		return false
	var source_team = source_ship.get("team_id")
	var body_team = body.get("team_id")
	return source_team != null and body_team != null and int(source_team) == int(body_team)


func _is_ai_prize_protected(body: Node) -> bool:
	if source_ship == null or body == null or bool(source_ship.get("accepts_player_input")):
		return false
	if bool(body.get("is_incapacitated")):
		return true
	if not bool(body.get_meta("boarding_protected", false)):
		return false
	return int(body.get_meta("boarding_protecting_team", -99)) == int(source_ship.get("team_id"))


func _hit(body: Node) -> void:
	if _spent:
		return
	if shot_mode == "mortar":
		_explode_mortar()
		return
	_spent = true
	if body and body.has_method("take_projectile_hit"):
		body.take_projectile_hit(damage, source_ship, global_position, velocity.normalized(), shot_mode, shot_profile)
	elif body and body.has_method("take_hit"):
		CombatFx.spawn_hull_hit(_effect_parent(), global_position, velocity.normalized())
		body.take_hit(damage, source_ship, global_position, velocity.normalized())
	elif body and body.has_method("take_damage"):
		CombatFx.spawn_hull_hit(_effect_parent(), global_position, velocity.normalized())
		body.take_damage(damage, source_ship)
	_retire()


func _explode_mortar() -> void:
	if _spent:
		return
	_spent = true
	var radius := float(shot_profile.get("explosion_radius", 8.5))
	var water_impact := global_position.y < 0.15
	if water_impact:
		CombatFx.spawn_water_splash(_effect_parent(), global_position, 1.8)
	else:
		CombatFx.spawn_powder_explosion(_effect_parent(), global_position, velocity.normalized())
	for ship in _combat_ships():
		if ship == source_ship or ship.get("is_sunk") or _is_friendly(ship) or _is_ai_prize_protected(ship) or not (ship is Node3D):
			continue
		var impact_center := (ship as Node3D).global_position + Vector3.UP * 0.45
		var distance := global_position.distance_to(impact_center)
		if distance > radius:
			continue
		var falloff := lerpf(0.34, 1.0, 1.0 - distance / radius)
		var profile := shot_profile.duplicate(true)
		profile["salvo_critical"] = distance < radius * 0.22
		if ship.has_method("take_projectile_hit"):
			ship.take_projectile_hit(damage * falloff, source_ship, global_position, velocity.normalized(), shot_mode, profile)
	_retire()


func _effect_parent() -> Node:
	if get_tree().current_scene:
		return get_tree().current_scene
	return get_parent()


func _find_near_miss_ship() -> Node3D:
	var best_ship: Node3D = null
	var best_distance := near_miss_radius
	var impact := Vector3(global_position.x, 0.0, global_position.z)
	for ship in _combat_ships():
		if ship == source_ship or ship.get("is_sunk") or _is_friendly(ship) or not (ship is Node3D):
			continue
		var ship_pos: Vector3 = ship.global_position
		var horizontal := Vector3(ship_pos.x, 0.0, ship_pos.z)
		var distance := impact.distance_to(horizontal)
		if distance < best_distance and distance > hit_radius * 1.15:
			best_distance = distance
			best_ship = ship
	return best_ship


func _combat_ships() -> Array[Node]:
	var tree := get_tree()
	if tree == null:
		return []
	var tree_id := tree.get_instance_id()
	var physics_frame := Engine.get_physics_frames()
	if _ship_cache_tree_id != tree_id or _ship_cache_physics_frame != physics_frame:
		_ship_cache_tree_id = tree_id
		_ship_cache_physics_frame = physics_frame
		_ship_cache = tree.get_nodes_in_group("ships")
	return _ship_cache


func _build_visual() -> void:
	if shot_mode == "chain":
		_build_chain_visual()
		return

	var ball_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28 if shot_mode == "mortar" else 0.18
	sphere.height = 0.56 if shot_mode == "mortar" else 0.36
	sphere.radial_segments = 12
	sphere.rings = 6
	ball_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	match shot_mode:
		"chain":
			mat.albedo_color = Color(0.09, 0.085, 0.075)
		"grape":
			mat.albedo_color = Color(0.045, 0.040, 0.034)
		"mortar":
			mat.albedo_color = Color(0.16, 0.11, 0.055)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.28, 0.05)
			mat.emission_energy_multiplier = 1.8
		_:
			mat.albedo_color = Color(0.025, 0.022, 0.02)
	mat.roughness = 0.55
	ball_mesh.material_override = mat
	add_child(ball_mesh)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.30 if shot_mode == "mortar" else 0.2
	collider.shape = shape
	add_child(collider)


func _build_chain_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.075, 0.070, 0.064)
	mat.roughness = 0.48

	for offset in [-0.22, 0.22]:
		var weight := MeshInstance3D.new()
		weight.name = "ChainShotWeight"
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.26
		sphere.radial_segments = 10
		sphere.rings = 5
		weight.mesh = sphere
		weight.position = Vector3(offset, 0.0, 0.0)
		weight.material_override = mat
		add_child(weight)

	var chain_bar := MeshInstance3D.new()
	chain_bar.name = "ChainShotLink"
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.48, 0.045, 0.045)
	chain_bar.mesh = bar_mesh
	chain_bar.material_override = mat
	add_child(chain_bar)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.24
	collider.shape = shape
	add_child(collider)
