extends Node

var _streams: Dictionary = {}
var _impact_duck_serial := 0


func _ready() -> void:
	add_to_group("combat_audio")
	_streams = {
		"cannon": _recorded_sounds(["res://sesler/cannon_fire.ogg"], _make_sound(0.92, 54.0, 0.88, 4.1, 1101)),
		"impact": _recorded_sounds([
			"res://sesler/cannon_hit.ogg",
			"res://sesler/cannon_hit_ship_short.ogg",
		], _make_sound(0.44, 92.0, 0.74, 6.8, 2202)),
		"hull_impact": _recorded_sounds([
			"res://sesler/cannon_hit_ship_short.ogg",
			"res://sesler/cannon_hit_wall_no_splash.ogg",
		], _make_sound(0.44, 82.0, 0.78, 6.2, 2212)),
		"cannon_impact": _recorded_sounds([
			"res://sesler/cannon_hit_cannon.ogg",
			"res://sesler/cannon_hit_wall.ogg",
		], _make_sound(0.50, 106.0, 0.76, 6.8, 2222)),
		"sail": _make_sound(0.58, 410.0, 0.58, 5.2, 3303),
		"splash": _recorded_sounds(["res://sesler/cannon_miss.ogg"], _make_sound(0.72, 145.0, 0.66, 4.3, 4404)),
		"ram": _recorded_sounds([
			"res://sesler/ship_ram_ship_shortened.ogg",
			"res://sesler/ship_ram_ship.ogg",
		], _make_sound(0.70, 66.0, 0.80, 3.6, 4411)),
		"sinking": _recorded_sounds([
			"res://sesler/ship_destroyed_short.ogg",
			"res://sesler/ship_destroyed.ogg",
		], _make_sound(1.25, 48.0, 0.86, 2.4, 4422)),
		"reload": _make_sound(0.30, 820.0, 0.10, 7.8, 5505),
		"command": _make_sound(0.34, 610.0, 0.16, 5.5, 6606),
		"colors_struck": _make_colors_struck(),
		"boarding": _make_sound(0.74, 118.0, 0.44, 3.9, 7707),
		"creak": _make_sound(0.96, 68.0, 0.24, 2.8, 8808),
		"alarm": _make_sound(0.48, 520.0, 0.12, 4.6, 9909),
	}


func play_spatial(event_name: String, world_position: Vector3, volume_db := 0.0) -> void:
	if not _streams.has(event_name):
		return
	var event_limit := 12 if event_name == "cannon" else (8 if event_name == "impact" else (5 if event_name == "splash" else 6))
	var event_count := 0
	var active_spatial := 0
	for child in get_children():
		if child is AudioStreamPlayer3D and child.playing:
			active_spatial += 1
			if String(child.get_meta("combat_event", "")) == event_name:
				event_count += 1
	if active_spatial >= 28 or event_count >= event_limit:
		return
	var camera := get_viewport().get_camera_3d()
	var delay := 0.0
	if event_name == "cannon" and camera:
		delay = clampf((camera.global_position.distance_to(world_position) - 24.0) / 343.0, 0.0, 0.55)
	if delay > 0.01:
		await get_tree().create_timer(delay).timeout
	var player := _acquire_spatial_player()
	if player == null:
		return
	player.set_meta("combat_event", event_name)
	player.stream = _event_stream(event_name)
	if player.stream == null:
		_release_spatial_player(player)
		return
	player.volume_db = volume_db
	player.pitch_scale = _event_pitch(event_name)
	player.unit_size = 16.0
	player.max_distance = 260.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.global_position = world_position
	player.play()


func apply_impact_duck(strength: float) -> void:
	_impact_duck_serial += 1
	var serial := _impact_duck_serial
	var amount := clampf(strength, 0.0, 1.0)
	for child in get_children():
		if not (child is AudioStreamPlayer3D) or not child.playing:
			continue
		var base_volume := float(child.volume_db)
		var tween := child.create_tween()
		tween.tween_property(child, "volume_db", base_volume - lerpf(2.0, 6.0, amount), 0.045)
		tween.tween_property(child, "volume_db", base_volume, 0.24).set_delay(0.05)
	await get_tree().create_timer(0.34).timeout
	if serial == _impact_duck_serial:
		_impact_duck_serial = 0


func play_ui(event_name: String, volume_db := -3.0) -> void:
	if not _streams.has(event_name):
		return
	var player := _acquire_ui_player()
	if player == null:
		return
	player.stream = _event_stream(event_name)
	if player.stream == null:
		_release_ui_player(player)
		return
	player.volume_db = volume_db
	player.pitch_scale = _event_pitch(event_name)
	player.play()


func _acquire_spatial_player() -> AudioStreamPlayer3D:
	var spatial_count := 0
	for child in get_children():
		if not (child is AudioStreamPlayer3D):
			continue
		spatial_count += 1
		if not child.playing:
			return child as AudioStreamPlayer3D
	if spatial_count >= 28:
		return null
	var player := AudioStreamPlayer3D.new()
	player.finished.connect(_release_spatial_player.bind(player))
	add_child(player)
	return player


func _release_spatial_player(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
	player.set_meta("combat_event", "")


func _acquire_ui_player() -> AudioStreamPlayer:
	var ui_count := 0
	for child in get_children():
		if not (child is AudioStreamPlayer) or child is AudioStreamPlayer3D:
			continue
		ui_count += 1
		if not child.playing:
			return child as AudioStreamPlayer
	if ui_count >= 4:
		return null
	var player := AudioStreamPlayer.new()
	player.finished.connect(_release_ui_player.bind(player))
	add_child(player)
	return player


func _release_ui_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null


func _recorded_sounds(paths: Array[String], fallback: AudioStream) -> Variant:
	var loaded: Array[AudioStream] = []
	for path in paths:
		var stream := load(path) as AudioStream
		if stream != null:
			loaded.append(stream)
	if loaded.is_empty():
		return fallback
	if loaded.size() == 1:
		return loaded[0]
	return loaded


func _event_stream(event_name: String) -> AudioStream:
	var entry: Variant = _streams.get(event_name)
	if entry is Array:
		var variants: Array = entry
		return variants.pick_random() as AudioStream if not variants.is_empty() else null
	return entry as AudioStream


func _event_pitch(event_name: String) -> float:
	match event_name:
		"cannon":
			return randf_range(0.94, 1.055)
		"impact", "hull_impact", "cannon_impact":
			return randf_range(0.965, 1.035)
		"splash", "ram":
			return randf_range(0.95, 1.05)
		"sinking":
			return randf_range(0.975, 1.02)
	return 1.0


func _make_sound(duration: float, frequency: float, noise_mix: float, decay: float, seed: int) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * float(sample_rate))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var filtered_noise := 0.0
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var envelope := exp(-decay * time) * minf(time * 32.0, 1.0)
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.22)
		var tone := sin(TAU * frequency * time) + sin(TAU * frequency * 1.51 * time) * 0.28
		var sample := (tone * (1.0 - noise_mix) + filtered_noise * noise_mix) * envelope * 0.82
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _make_colors_struck() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.75
	var sample_count := int(duration * float(sample_rate))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1665
	var drum_noise := 0.0
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var sample := 0.0
		for beat in [0.0, 0.34, 0.68]:
			var beat_time: float = time - beat
			if beat_time >= 0.0 and beat_time < 0.30:
				var drum_env := exp(-beat_time * 13.0) * minf(beat_time * 80.0, 1.0)
				drum_noise = lerpf(drum_noise, rng.randf_range(-1.0, 1.0), 0.08)
				sample += (sin(TAU * (72.0 - beat_time * 34.0) * beat_time) * 0.78 + drum_noise * 0.22) * drum_env * 0.36
		for call in [[0.14, 196.0], [0.48, 246.94], [0.82, 293.66]]:
			var call_time: float = time - float(call[0])
			if call_time >= 0.0 and call_time < 0.70:
				var brass_env := minf(call_time * 18.0, 1.0) * exp(-call_time * 3.1)
				var frequency: float = float(call[1])
				var brass := sin(TAU * frequency * call_time) + sin(TAU * frequency * 2.0 * call_time) * 0.24 + sin(TAU * frequency * 3.0 * call_time) * 0.08
				sample += brass * brass_env * 0.16
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
