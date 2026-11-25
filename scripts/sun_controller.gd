@tool
extends Node3D

enum WeatherSeason { CLEAR_TROPICAL, PARTLY_CLOUDY, OVERCAST_RAIN, TROPICAL_STORM }

@export_group("Time & Sun")
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 10.5:
	set(v):
		time_of_day = v
		_update_atmosphere()

@export_range(-90.0, 90.0, 0.1) var latitude: float = 15.0:
	set(v):
		latitude = v
		_update_atmosphere()

@export_group("Season & Cloud Path")
@export var weather_season: WeatherSeason = WeatherSeason.PARTLY_CLOUDY:
	set(v):
		weather_season = v
		_apply_season_preset()

@export var cloud_position: Vector2 = Vector2(0.18, -0.12):
	set(v):
		cloud_position = v
		_update_atmosphere()

@export_range(0.0, 360.0, 1.0) var wind_heading_deg: float = 45.0:
	set(v):
		wind_heading_deg = v
		_update_atmosphere()

@export_range(0.0, 0.3, 0.005) var wind_speed: float = 0.05:
	set(v):
		wind_speed = v
		_update_atmosphere()

func _ready() -> void:
	_apply_season_preset()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		time_of_day = fmod(time_of_day + delta * 0.02, 24.0)

func _apply_season_preset() -> void:
	var mat := _get_sky_mat()
	if mat:
		match weather_season:
			WeatherSeason.CLEAR_TROPICAL:
				mat.set_shader_parameter("storm_intensity", 0.0)
				mat.set_shader_parameter("cloud_coverage", 0.32)
				mat.set_shader_parameter("cirrus_density", 0.40)
			WeatherSeason.PARTLY_CLOUDY:
				mat.set_shader_parameter("storm_intensity", 0.0)
				mat.set_shader_parameter("cloud_coverage", 0.52)
				mat.set_shader_parameter("cirrus_density", 0.35)
			WeatherSeason.OVERCAST_RAIN:
				mat.set_shader_parameter("storm_intensity", 0.65)
				mat.set_shader_parameter("cloud_coverage", 0.85)
				mat.set_shader_parameter("cirrus_density", 0.15)
			WeatherSeason.TROPICAL_STORM:
				mat.set_shader_parameter("storm_intensity", 1.0)
				mat.set_shader_parameter("cloud_coverage", 1.0)
				mat.set_shader_parameter("cirrus_density", 0.05)
	_update_atmosphere()

func _get_sky_mat() -> ShaderMaterial:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.sky:
		return we.environment.sky.sky_material as ShaderMaterial
	return null

func _update_atmosphere() -> void:
	var sun := get_node_or_null("Illuminaries/Sun") as DirectionalLight3D
	if sun:
		var angle := ((time_of_day - 6.0) / 24.0) * TAU
		var elev := sin(angle)
		sun.rotation_degrees = Vector3(-rad_to_deg(asin(clamp(elev, -1.0, 1.0))), latitude, 0.0)
		var day_f := clampf((elev + 0.12) / 0.35, 0.0, 1.0)
		var storm := 0.0
		var mat := _get_sky_mat()
		if mat:
			storm = float(mat.get_shader_parameter("storm_intensity"))
		sun.light_energy = lerpf(0.0, 1.41 * (1.0 - storm * 0.72), day_f)

	var mat := _get_sky_mat()
	if mat:
		var rad := deg_to_rad(wind_heading_deg)
		mat.set_shader_parameter("cloud_position_offset", cloud_position)
		mat.set_shader_parameter("wind_dir", Vector2(cos(rad), sin(rad)))
		mat.set_shader_parameter("wind_speed", wind_speed)

# --- Moon & Stars sync for shaders/sky_bruneton.gdshader ---
@export_group("Moon & Stars (Bruneton)")
@export var moon_tex_override: Texture2D
@export var stars_tex_override: Texture2D
@export var moon_color_val: Color = Color(0.78, 0.86, 1.0, 1.0)
@export var moon_intensity_val: float = 2.6
@export var moon_size_val: float = 0.036
@export var stars_intensity_val: float = 1.35
@export var night_haziness_val: float = 0.5

func _sync_bruneton_moon_stars(sky_mat: ShaderMaterial, night_factor: float = 1.0) -> void:
	if sky_mat == null:
		return
	var nf: float = clampf(night_factor, 0.0, 1.0)
	if moon_tex_override != null:
		sky_mat.set_shader_parameter("moon_tex", moon_tex_override)
	if stars_tex_override != null:
		sky_mat.set_shader_parameter("stars_tex", stars_tex_override)
	sky_mat.set_shader_parameter("moon_color", moon_color_val)
	sky_mat.set_shader_parameter("moon_intensity", moon_intensity_val * nf)
	sky_mat.set_shader_parameter("moon_size", moon_size_val)
	sky_mat.set_shader_parameter("stars_intensity", stars_intensity_val * nf)
	sky_mat.set_shader_parameter("night_haziness", night_haziness_val)

func _process(_delta: float) -> void:
	_apply_moon_stars_for_time(0.0)

func _get_active_sky_shader_material() -> ShaderMaterial:
	for child in get_children():
		if child is WorldEnvironment and child.environment and child.environment.sky:
			var sm := child.environment.sky.sky_material as ShaderMaterial
			if sm != null:
				return sm
	var parent := get_parent()
	if parent != null:
		for n in parent.find_children("*", "WorldEnvironment", true, false):
			var we := n as WorldEnvironment
			if we and we.environment and we.environment.sky:
				var sm := we.environment.sky.sky_material as ShaderMaterial
				if sm != null:
					return sm
	return null

func _apply_moon_stars_for_time(sun_elevation_norm: float = 0.0) -> void:
	var sm := _get_active_sky_shader_material()
	if sm == null:
		return
	# When sun_elevation_norm <= 0 (dusk/night/dawn), ramp night_factor up cleanly
	var nf: float = clampf((-sun_elevation_norm + 0.12) / 0.45, 0.0, 1.0)
	_sync_bruneton_moon_stars(sm, nf)

# --- Moon direction sign helper (flip if light/moon is inverted) ---
@export var moon_dir_invert: bool = false

func _resolve_moon_dir(raw_moon_dir: Vector3) -> Vector3:
	var d := raw_moon_dir.normalized()
	return -d if moon_dir_invert else d
