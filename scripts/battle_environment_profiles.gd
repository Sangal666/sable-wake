extends RefCounted
class_name BattleEnvironmentProfiles

const WEATHER_OPTIONS := ["Clear", "Overcast", "Storm"]
const TIME_OPTIONS := ["Day", "Sunset", "Night"]
const SEA_OPTIONS := ["Calm", "Rolling", "Rough", "High Seas"]

static var pending_lab_config: Dictionary = {}


static func default_config() -> Dictionary:
	return {
		"weather": "Clear",
		"time_of_day": "Day",
		"sea_condition": "Rolling",
	}


static func normalize_config(config: Dictionary) -> Dictionary:
	var normalized := default_config()
	var weather := String(config.get("weather", normalized.weather))
	var time_of_day := String(config.get("time_of_day", normalized.time_of_day))
	var sea_condition := String(config.get("sea_condition", normalized.sea_condition))
	if weather in WEATHER_OPTIONS:
		normalized.weather = weather
	if time_of_day in TIME_OPTIONS:
		normalized.time_of_day = time_of_day
	if sea_condition in SEA_OPTIONS:
		normalized.sea_condition = sea_condition
	return normalized


static func set_pending_lab_config(config: Dictionary) -> void:
	pending_lab_config = normalize_config(config)
	if config.has("player_type"):
		pending_lab_config.player_type = String(config.player_type)


static func consume_lab_config() -> Dictionary:
	var config := pending_lab_config.duplicate(true) if not pending_lab_config.is_empty() else default_config()
	pending_lab_config.clear()
	return config


static func build_profile(config: Dictionary) -> Dictionary:
	var selected := normalize_config(config)
	var weather := String(selected.weather)
	var time_of_day := String(selected.time_of_day)
	var sea_condition := String(selected.sea_condition)

	var sea_state := 0.95
	var sea_wind_scale := 1.0
	var wave_speed := 0.66
	var wave_chop := 0.90
	var foam_strength := 0.85
	match sea_condition:
		"Calm":
			sea_state = 0.38
			sea_wind_scale = 0.78
			wave_speed = 0.48
			wave_chop = 0.34
			foam_strength = 0.22
		"Rough":
			sea_state = 1.55
			sea_wind_scale = 1.16
			wave_speed = 0.78
			wave_chop = 1.48
			foam_strength = 1.46
		"High Seas":
			sea_state = 2.65
			sea_wind_scale = 1.30
			wave_speed = 0.88
			wave_chop = 2.18
			foam_strength = 2.16

	var profile := {
		"weather": weather,
		"time_of_day": time_of_day,
		"sea_condition": sea_condition,
		"sea_state": sea_state,
		"wave_speed": wave_speed,
		"wave_chop": wave_chop,
		"foam_strength": foam_strength,
		"wind_strength": sea_wind_scale,
		"wind_direction": Vector3(0.85, 0.0, -0.35).normalized(),
		"sky_top": Color(0.025, 0.115, 0.225),
		"sky_horizon": Color(0.48, 0.70, 0.76),
		"ground_bottom": Color(0.012, 0.028, 0.036),
		"ground_horizon": Color(0.075, 0.205, 0.225),
		"sky_energy": 1.08,
		"use_color_ambient": true,
		"ambient_color": Color(0.52, 0.63, 0.68),
		"ambient_energy": 0.74,
		"fog_color": Color(0.31, 0.53, 0.59),
		"fog_density": 0.00145,
		"fog_aerial": 0.56,
		"fog_sky_affect": 0.62,
		"exposure": 1.08,
		"brightness": 1.02,
		"contrast": 1.08,
		"saturation": 1.08,
		"sun_energy": 1.52,
		"sun_color": Color(1.0, 0.90, 0.72),
		"sun_rotation": Vector3(-43.0, -31.0, 0.0),
		"abyss_color": Color(0.008, 0.068, 0.098, 1.0),
		"deep_color": Color(0.010, 0.135, 0.175, 1.0),
		"face_color": Color(0.032, 0.305, 0.335, 1.0),
		"foam_color": Color(0.78, 0.90, 0.84, 1.0),
		"ocean_emission": 0.02,
		"storm_breakers_enabled": false,
		"storm_breaker_interval_min": 24.0,
		"storm_breaker_interval_max": 36.0,
		"storm_breaker_scale": 1.0,
	}

	match time_of_day:
		"Sunset":
			profile.sky_top = Color(0.055, 0.075, 0.155)
			profile.sky_horizon = Color(0.88, 0.40, 0.20)
			profile.ground_bottom = Color(0.018, 0.025, 0.040)
			profile.ground_horizon = Color(0.24, 0.12, 0.10)
			profile.sky_energy = 0.98
			profile.use_color_ambient = true
			profile.ambient_color = Color(0.58, 0.40, 0.34)
			profile.ambient_energy = 0.69
			profile.fog_color = Color(0.40, 0.27, 0.27)
			profile.exposure = 1.15
			profile.brightness = 1.08
			profile.sun_energy = 1.42
			profile.sun_color = Color(1.0, 0.53, 0.28)
			profile.sun_rotation = Vector3(-12.0, -66.0, 0.0)
			profile.deep_color = Color(0.018, 0.105, 0.145, 1.0)
			profile.face_color = Color(0.18, 0.235, 0.245, 1.0)
			profile.ocean_emission = 0.075
		"Night":
			profile.sky_top = Color(0.010, 0.022, 0.052)
			profile.sky_horizon = Color(0.085, 0.15, 0.215)
			profile.ground_bottom = Color(0.002, 0.006, 0.012)
			profile.ground_horizon = Color(0.028, 0.075, 0.105)
			profile.sky_energy = 0.58
			profile.use_color_ambient = true
			profile.ambient_color = Color(0.24, 0.34, 0.56)
			profile.ambient_energy = 0.78
			profile.fog_color = Color(0.075, 0.145, 0.20)
			profile.fog_density = 0.00175
			profile.fog_aerial = 0.72
			profile.exposure = 1.04
			profile.brightness = 1.0
			profile.contrast = 1.13
			profile.saturation = 0.88
			profile.sun_energy = 0.72
			profile.sun_color = Color(0.58, 0.72, 1.0)
			profile.sun_rotation = Vector3(-31.0, 38.0, 0.0)
			profile.abyss_color = Color(0.003, 0.028, 0.055, 1.0)
			profile.deep_color = Color(0.008, 0.075, 0.115, 1.0)
			profile.face_color = Color(0.028, 0.17, 0.225, 1.0)
			profile.foam_color = Color(0.60, 0.75, 0.80, 1.0)
			profile.ocean_emission = 0.24

	match weather:
		"Overcast":
			profile.sky_top = (profile.sky_top as Color).darkened(0.34)
			profile.sky_horizon = (profile.sky_horizon as Color).lerp(Color(0.28, 0.38, 0.42), 0.58)
			profile.sky_energy = float(profile.sky_energy) * 0.72
			profile.ambient_energy = float(profile.ambient_energy) * 0.88
			profile.fog_color = (profile.fog_color as Color).lerp(Color(0.25, 0.34, 0.37), 0.58)
			profile.fog_density = maxf(float(profile.fog_density), 0.00215)
			profile.fog_aerial = 0.75
			profile.saturation = float(profile.saturation) * 0.78
			profile.sun_energy = float(profile.sun_energy) * 0.52
			profile.wind_strength = float(profile.wind_strength) * 1.08
			profile.deep_color = (profile.deep_color as Color).darkened(0.12)
			profile.face_color = (profile.face_color as Color).lerp(Color(0.12, 0.22, 0.23), 0.48)
		"Storm":
			var storm_mix := 0.62 if time_of_day == "Day" else (0.48 if time_of_day == "Sunset" else 0.34)
			profile.sky_top = (profile.sky_top as Color).lerp(Color(0.065, 0.13, 0.17), storm_mix)
			profile.sky_horizon = (profile.sky_horizon as Color).lerp(Color(0.30, 0.39, 0.41), storm_mix)
			profile.ground_horizon = (profile.ground_horizon as Color).lerp(Color(0.075, 0.14, 0.15), storm_mix)
			profile.sky_energy = float(profile.sky_energy) * 0.72
			profile.ambient_energy = float(profile.ambient_energy) * 0.90
			profile.fog_color = (profile.fog_color as Color).lerp(Color(0.20, 0.30, 0.32), 0.68)
			profile.fog_density = maxf(float(profile.fog_density), 0.00275)
			profile.fog_aerial = 0.84
			profile.fog_sky_affect = 0.78
			profile.exposure = float(profile.exposure) * 0.98
			profile.brightness = float(profile.brightness) * 0.98
			profile.contrast = 1.12
			profile.saturation = float(profile.saturation) * 0.78
			profile.sun_energy = float(profile.sun_energy) * 0.42
			profile.wind_strength = float(profile.wind_strength) * 1.34
			profile.wind_direction = Vector3(0.62, 0.0, -0.78).normalized()
			profile.sea_state = minf(float(profile.sea_state) * 1.18 + 0.22, 3.15)
			profile.wave_speed = minf(float(profile.wave_speed) * 1.08, 0.96)
			profile.wave_chop = minf(float(profile.wave_chop) + 0.42, 2.58)
			profile.foam_strength = minf(float(profile.foam_strength) + 0.52, 2.62)
			profile.abyss_color = Color(0.004, 0.032, 0.045, 1.0)
			profile.deep_color = Color(0.012, 0.075, 0.085, 1.0)
			profile.face_color = Color(0.075, 0.17, 0.17, 1.0)
			profile.foam_color = Color(0.66, 0.76, 0.70, 1.0)
			profile.storm_breakers_enabled = true
			match sea_condition:
				"Calm":
					profile.storm_breaker_interval_min = 30.0
					profile.storm_breaker_interval_max = 44.0
					profile.storm_breaker_scale = 0.88
				"Rough":
					profile.storm_breaker_interval_min = 19.0
					profile.storm_breaker_interval_max = 29.0
					profile.storm_breaker_scale = 1.12
				"High Seas":
					profile.storm_breaker_interval_min = 13.0
					profile.storm_breaker_interval_max = 21.0
					profile.storm_breaker_scale = 1.35
			if time_of_day != "Night":
				profile.use_color_ambient = true
				profile.ambient_color = Color(0.46, 0.54, 0.55) if time_of_day == "Day" else Color(0.48, 0.40, 0.37)
				profile.ambient_energy = maxf(float(profile.ambient_energy), 0.82 if time_of_day == "Day" else 0.72)
				profile.exposure = maxf(float(profile.exposure), 1.08)
				profile.brightness = maxf(float(profile.brightness), 1.03)
				profile.sun_energy = maxf(float(profile.sun_energy), 0.62)
				profile.abyss_color = Color(0.008, 0.055, 0.064, 1.0)
				profile.deep_color = Color(0.025, 0.135, 0.145, 1.0)
				profile.face_color = Color(0.105, 0.245, 0.245, 1.0)
				profile.ocean_emission = maxf(float(profile.ocean_emission), 0.10)

	if time_of_day == "Night":
		profile.sky_top = Color(0.012, 0.030, 0.070) if weather == "Storm" else profile.sky_top
		profile.sky_horizon = Color(0.075, 0.14, 0.205) if weather == "Storm" else profile.sky_horizon
		profile.sky_energy = maxf(float(profile.sky_energy), 0.58)
		profile.use_color_ambient = true
		profile.ambient_color = Color(0.30, 0.40, 0.66) if weather == "Storm" else Color(0.28, 0.39, 0.64)
		profile.ambient_energy = maxf(float(profile.ambient_energy), 1.05)
		profile.exposure = maxf(float(profile.exposure), 1.08)
		profile.brightness = maxf(float(profile.brightness), 1.04)
		profile.sun_energy = maxf(float(profile.sun_energy), 0.90)
		profile.ocean_emission = maxf(float(profile.ocean_emission), 0.68)

	var sea_label := sea_condition if sea_condition == "High Seas" else "%s Sea" % sea_condition
	profile.label = "%s / %s / %s" % [time_of_day, weather, sea_label]
	return profile
