extends GPUParticles3D
class_name StormRain


func _ready() -> void:
	name = "StormRain"
	local_coords = false
	amount = 620
	lifetime = 0.95
	randomness = 0.28
	visibility_aabb = AABB(Vector3(-45.0, -24.0, -45.0), Vector3(90.0, 48.0, 90.0))

	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(34.0, 8.0, 34.0)
	rain_process.direction = Vector3(-0.20, -1.0, -0.10).normalized()
	rain_process.spread = 5.0
	rain_process.initial_velocity_min = 25.0
	rain_process.initial_velocity_max = 32.0
	rain_process.gravity = Vector3(0.0, -7.0, 0.0)
	process_material = rain_process

	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.92)
	var streak_material := StandardMaterial3D.new()
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak_material.albedo_color = Color(0.68, 0.79, 0.82, 0.30)
	streak.material = streak_material
	draw_pass_1 = streak


func _process(_delta: float) -> void:
	var active_camera := get_viewport().get_camera_3d() if get_viewport() else null
	if is_instance_valid(active_camera):
		global_position = active_camera.global_position + Vector3(0.0, 9.0, 0.0)
