extends RefCounted
class_name HanabiUserSettings

const DEFAULT_PATH := "user://preferences.cfg"
const DEFAULTS := {"sound_enabled": false, "volume": 0.7, "fullscreen": false}
var storage_path: String
var values: Dictionary = DEFAULTS.duplicate()
var has_saved: bool = false
# Injectable writer for testing failure feedback without damaging real files.
var writer: Callable

func _init(path: String = DEFAULT_PATH) -> void:
	storage_path = path
	load_values()

static func normalise(raw: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for key in ["sound_enabled", "fullscreen"]:
		if typeof(raw.get(key)) == TYPE_BOOL: result[key] = raw[key]
	var volume = raw.get("volume")
	if typeof(volume) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(volume)):
		result.volume = clampf(float(volume), 0.0, 1.0)
	return result

func load_values() -> void:
	values = DEFAULTS.duplicate()
	has_saved = false
	if not FileAccess.file_exists(storage_path): return
	var config := ConfigFile.new()
	if config.load(storage_path) != OK: return
	values = normalise({"sound_enabled":config.get_value("audio", "enabled", false), "volume":config.get_value("audio", "volume", 0.7), "fullscreen":config.get_value("display", "fullscreen", false)})
	has_saved = true

func save_values(raw: Dictionary) -> Error:
	var snapshot := normalise(raw)
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("audio", "enabled", snapshot.sound_enabled)
	config.set_value("audio", "volume", snapshot.volume)
	config.set_value("display", "fullscreen", snapshot.fullscreen)
	var error: Error
	if writer.is_valid():
		error = writer.call(config, storage_path)
	else:
		var temporary := storage_path + ".tmp"
		error = config.save(temporary)
		if error == OK:
			error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	if error == OK:
		values = snapshot
		has_saved = true
	return error

func matches(raw: Dictionary) -> bool:
	var snapshot := normalise(raw)
	return snapshot.sound_enabled == values.sound_enabled and is_equal_approx(snapshot.volume, values.volume) and snapshot.fullscreen == values.fullscreen
