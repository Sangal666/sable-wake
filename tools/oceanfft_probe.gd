extends SceneTree


const OUTPUT_PATH := "/private/tmp/oceanfft_probe.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "OceanFFTProbe"
	root.add_child(scene)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.near = 0.2
	camera.far = 2400.0
	camera.fov = 66.0
	camera.position = Vector3(0.0, 13.5, 38.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.5, -34.0))
	scene.add_child(camera)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.095, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.19, 0.27, 0.34)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.19, 0.25, 0.29)
	environment.fog_density = 0.0022
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color(0.76, 0.84, 0.90)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	scene.add_child(sun)

	var ocean_script := load("res://addons/tessarakkt.oceanfft/components/Ocean3D.gd")
	var ocean = ocean_script.new()
	ocean.material = (load("res://addons/tessarakkt.oceanfft/Ocean.tres") as ShaderMaterial).duplicate(true)
	ocean.fft_resolution = 64
	ocean.horizontal_dimension = 420
	ocean.time_scale = 0.42
	ocean.choppiness = 1.72
	ocean.wind_direction_degrees = 208.0
	ocean.wind_speed = 29.0
	ocean.simulation_frameskip = 3
	ocean.heightmap_sync_frameskip = -1
	ocean.planetary_curve_strength = 0.0
	ocean.amplitude_scale_min = 1.0
	ocean.amplitude_scale_max = 1.0
	ocean.material.set_shader_parameter("deep_color", Color(0.005, 0.035, 0.052, 1.0))
	ocean.material.set_shader_parameter("shallow_color", Color(0.04, 0.29, 0.31, 1.0))
	ocean.material.set_shader_parameter("foam_jacobian_limit", 0.28)
	ocean.material.set_shader_parameter("foam_coverage", 0.52)
	ocean.material.set_shader_parameter("foam_mix_strength", 0.82)
	ocean.material.set_shader_parameter("fresnel_strength", 0.22)
	ocean.material.set_shader_parameter("fresnel_exposure", 0.36)
	ocean.material.set_shader_parameter("fresnel_sky_color", Color(0.34, 0.48, 0.57, 1.0))
	ocean.initialize_simulation()

	for frame in range(120):
		await process_frame
		if ocean.initialized:
			break
	if not ocean.initialized:
		return _fail("OceanFFT did not initialize on the render thread")

	var quad_script := load("res://addons/tessarakkt.oceanfft/components/QuadTree3D.gd")
	var ocean_mesh := Node3D.new()
	ocean_mesh.name = "OceanFFTMesh"
	ocean_mesh.set_script(quad_script)
	var lod_ranges: Array[float] = [140.0, 360.0, 900.0, 1880.0]
	ocean_mesh.set("lod_level", 3)
	ocean_mesh.set("quad_size", 2048.0)
	ocean_mesh.set("mesh_vertex_resolution", 64)
	ocean_mesh.set("ranges", lod_ranges)
	ocean_mesh.set("material", ocean.material)
	scene.add_child(ocean_mesh)

	_add_scale_reference(scene)
	for frame in range(36):
		ocean.simulate(1.0 / 60.0)
		await process_frame
	ocean.force_simulate(0.15, true)
	for frame in range(12):
		await process_frame
	var min_height := INF
	var max_height := -INF
	for x in range(-36, 37, 6):
		var height: float = ocean.get_wave_height(camera, Vector3(float(x), 0.0, -22.0), 3, 3)
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)

	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(OUTPUT_PATH) != OK:
		return _fail("Could not save OceanFFT probe screenshot")
	var height_range := max_height - min_height
	print("OCEANFFT_HEIGHT_RANGE %.3f MIN %.3f MAX %.3f" % [height_range, min_height, max_height])
	if height_range < 0.35:
		return _fail("OceanFFT produced insufficient visible displacement")
	print("OCEANFFT_PROBE_OK %s" % OUTPUT_PATH)
	quit(0)


func _add_scale_reference(parent: Node3D) -> void:
	var hull := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(9.0, 2.8, 28.0)
	hull.mesh = mesh
	hull.position = Vector3(0.0, 1.8, -22.0)
	hull.rotation_degrees.y = -9.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.075, 0.045)
	hull.material_override = material
	parent.add_child(hull)
	for mast_z in [-29.0, -20.0, -12.0]:
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.13
		mast_mesh.bottom_radius = 0.18
		mast_mesh.height = 16.0
		mast.mesh = mast_mesh
		mast.position = Vector3(0.0, 9.0, mast_z)
		mast.material_override = material
		parent.add_child(mast)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
