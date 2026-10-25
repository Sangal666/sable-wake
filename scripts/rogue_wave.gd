extends Node3D

signal expired(wave: Node3D)

@export var travel_speed := 15.5
@export var front_width := 260.0
@export var lifetime := 24.0

var travel_direction := Vector3.FORWARD
var age := 0.0
var height_scale := 1.0
var ocean_palette: Dictionary = {}


func configure(origin: Vector3, direction: Vector3, speed := 15.5, width := 260.0, wave_scale := 1.0, palette: Dictionary = {}) -> void:
	position = Vector3(origin.x, -0.12, origin.z)
	travel_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if travel_direction.length_squared() < 0.01:
		travel_direction = Vector3.FORWARD
	travel_speed = speed
	front_width = width
	height_scale = clampf(wave_scale, 0.75, 1.40)
	ocean_palette = palette.duplicate()
	var across := Vector3(travel_direction.z, 0.0, -travel_direction.x).normalized()
	basis = Basis(across, Vector3.UP, travel_direction).orthonormalized()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_wave_front()
	_update_integrated_ocean()


func _process(delta: float) -> void:
	age += delta
	global_position += travel_direction * travel_speed * delta
	_update_integrated_ocean()
	if age >= lifetime:
		expired.emit(self)
		queue_free()


func _exit_tree() -> void:
	for fluid in get_tree().get_nodes_in_group("fft_wave_fluid"):
		if fluid.has_method("clear_rogue_wave_data"):
			fluid.call("clear_rogue_wave_data", get_instance_id())


func distance_to_front(world_position: Vector3) -> float:
	return (world_position - global_position).dot(travel_direction)


func closest_front_point(world_position: Vector3) -> Vector3:
	return world_position - travel_direction * distance_to_front(world_position) + Vector3.UP * 2.8


func _build_wave_front() -> void:
	var foam_color := ocean_palette.get("foam_color", Color(0.66, 0.76, 0.70, 1.0)) as Color
	var spray := GPUParticles3D.new()
	spray.name = "StormBreakerSpray"
	spray.amount = int(96.0 * height_scale)
	spray.lifetime = 1.45
	spray.preprocess = 1.45
	spray.local_coords = true
	spray.visibility_aabb = AABB(Vector3(-front_width * 0.55, -1.0, -6.0), Vector3(front_width * 1.1, 11.0, 15.0))
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.13
	droplet_mesh.height = 0.24
	droplet_mesh.radial_segments = 6
	droplet_mesh.rings = 3
	spray.draw_pass_1 = droplet_mesh
	var spray_process := ParticleProcessMaterial.new()
	spray_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spray_process.emission_box_extents = Vector3(front_width * 0.47, 0.34, 1.45)
	spray_process.direction = Vector3(0.0, 0.88, 0.34)
	spray_process.spread = 34.0
	spray_process.initial_velocity_min = 2.6
	spray_process.initial_velocity_max = 7.4
	spray_process.gravity = Vector3(0.0, -4.8, 0.0)
	spray_process.scale_min = 0.35
	spray_process.scale_max = 1.25
	spray_process.color = Color(foam_color.r, foam_color.g, foam_color.b, 0.64)
	spray.process_material = spray_process
	spray.position = Vector3(0.0, 4.25 * height_scale, -0.25)
	add_child(spray)
	spray.emitting = true


func _update_integrated_ocean() -> void:
	for fluid in get_tree().get_nodes_in_group("fft_wave_fluid"):
		if fluid.has_method("set_rogue_wave_data"):
			fluid.call("set_rogue_wave_data", global_position, travel_direction, front_width, 4.8 * height_scale, get_instance_id())
