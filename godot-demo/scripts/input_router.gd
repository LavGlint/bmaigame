extends Node
class_name HanabiInputRouter

signal devices_changed
signal controller_lost(slot: int)

var modes: Array[String] = ["key1", "ai", "ai", "ai"]
var devices: Array[int] = [-1, -1, -1, -1]
var locked: bool = false
var selection_active: bool = false
var tap_keys: Dictionary = {}
var deadzone: float = 0.2
# Optional input source for recorded/simulated device states; native polling is the default.
var device_reader: Callable
var connection_reader: Callable
var keyboard_aim: Vector2 = Vector2.ZERO
var mouse_throw_tap: bool = false
var mouse_throw_held := false
var mouse_dash_tap: bool = false
var blocked_actions: Array[Dictionary] = [{}, {}, {}, {}]
var run_latches: Dictionary = {}
var held_run_keys: Dictionary = {}

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_connection)
	for device in Input.get_connected_joypads():
		_assign(device)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode in [KEY_R, KEY_KP_0]:
		if event.pressed: held_run_keys[event.physical_keycode] = true
		else: held_run_keys.erase(event.physical_keycode)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_SLASH, KEY_SHIFT, KEY_CTRL]:
			tap_keys[event.physical_keycode] = true

func _on_connection(device: int, connected: bool) -> void:
	run_latches.erase(device)
	if connected and not locked:
		_assign(device)
	elif not connected:
		for slot in range(4):
			if modes[slot] == "pad" and devices[slot] == device:
				if locked:
					controller_lost.emit(slot)
				elif not selection_active:
					modes[slot] = "ai"
					devices[slot] = -1
	devices_changed.emit()

func _assign(device: int) -> void:
	if device in devices:
		return
	for slot in range(4):
		if modes[slot] != "pad":
			modes[slot] = "pad"
			devices[slot] = device
			break

func set_mode(slot: int, mode: String, device: int = -1) -> void:
	if locked:
		return
	for other in range(4):
		if other == slot:
			continue
		if (mode == "pad" and modes[other] == "pad" and devices[other] == device) or (mode.begins_with("key") and modes[other] == mode):
			modes[other] = "ai"
			devices[other] = -1
	modes[slot] = mode
	devices[slot] = device
	devices_changed.emit()

func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code) or tap_keys.has(code) or held_run_keys.has(code)

func raw_command(slot: int) -> Dictionary:
	if modes[slot] == "key1":
		return {"move": Vector2(float(_key(KEY_D)) - float(_key(KEY_A)), float(_key(KEY_S)) - float(_key(KEY_W))).limit_length(), "aim": keyboard_aim, "throw": _key(KEY_SPACE) or mouse_throw_tap or mouse_throw_held, "dash": _key(KEY_SHIFT) or mouse_dash_tap, "slash": _key(KEY_E), "run": _key(KEY_R)}
	if modes[slot] == "key2":
		return {"move": Vector2(float(_key(KEY_RIGHT)) - float(_key(KEY_LEFT)), float(_key(KEY_DOWN)) - float(_key(KEY_UP))).limit_length(), "aim": Vector2.ZERO, "throw": _key(KEY_ENTER), "dash": _key(KEY_CTRL), "slash": _key(KEY_SLASH), "run": _key(KEY_KP_0)}
	if modes[slot] == "pad":
		return pad_command(devices[slot])
	return {}

func arm_gameplay() -> void:
	for slot in range(4):
		blocked_actions[slot].clear()
		var state := raw_command(slot)
		for action in ["throw", "dash", "slash"]:
			if state.get(action, false): blocked_actions[slot][action] = true

func command(slot: int) -> Dictionary:
	var state := raw_command(slot)
	for action in blocked_actions[slot].keys():
		if not state.get(action, false): blocked_actions[slot].erase(action)
		else: state[action] = false
	return state

func pad_command(device: int) -> Dictionary:
	var state: Dictionary
	if device_reader.is_valid():
		state = device_reader.call(device)
	else:
		state = {"move": Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)), "aim": Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)), "right": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT), "left": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT), "down": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN), "up": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP), "throw": Input.is_joy_button_pressed(device, JOY_BUTTON_A), "dash": Input.is_joy_button_pressed(device, JOY_BUTTON_B), "slash": Input.is_joy_button_pressed(device, JOY_BUTTON_X), "run": Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK)}
	var move: Vector2 = state.get("move", Vector2.ZERO)
	var aim: Vector2 = state.get("aim", Vector2.ZERO)
	move = filter_stick(move)
	aim = filter_stick(aim)
	# Separate enter/leave thresholds prevent flicker near the stick boundary.
	if move.length() >= 0.78: run_latches[device] = true
	elif move.length() <= 0.64: run_latches[device] = false
	var run := bool(state.get("run", false)) or bool(run_latches.get(device, false))
	if move.is_zero_approx():
		move = Vector2(float(state.get("right", false)) - float(state.get("left", false)), float(state.get("down", false)) - float(state.get("up", false))).limit_length()
	return {"move": move, "aim": aim, "throw": state.get("throw", false), "dash": state.get("dash", false), "slash": state.get("slash", false), "run": run}

func menu_command(device: int) -> Dictionary:
	# Preserve raw axes and digital directions separately. Combat movement merges
	# them, which made a D-pad press move the roster twice through two code paths.
	if device_reader.is_valid():
		var recorded: Dictionary = device_reader.call(device)
		return {"move": recorded.get("move", Vector2.ZERO), "left": recorded.get("left", false), "right": recorded.get("right", false)}
	return {"move": Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)), "left": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT), "right": Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)}

func filter_stick(stick: Vector2) -> Vector2:
	var magnitude := stick.length()
	if magnitude <= deadzone:
		return Vector2.ZERO
	return stick.normalized() * minf(1.0, (magnitude - deadzone) / (1.0 - deadzone))

func end_frame() -> void:
	tap_keys.clear()
	mouse_throw_tap = false
	mouse_dash_tap = false

func all_connected() -> bool:
	var connected: PackedInt32Array = connection_reader.call() if connection_reader.is_valid() else Input.get_connected_joypads()
	for slot in range(4):
		if modes[slot] == "pad" and devices[slot] not in connected:
			return false
	return true

func slot_connected(slot: int) -> bool:
	if modes[slot] != "pad": return true
	var connected: PackedInt32Array = connection_reader.call() if connection_reader.is_valid() else Input.get_connected_joypads()
	return devices[slot] in connected

func label_for(slot: int) -> String:
	match modes[slot]:
		"key1": return "键盘 1 · WASD"
		"key2": return "键盘 2 · 方向键"
		"pad": return "手柄 %d" % (devices[slot] + 1)
	return "电脑陪练"
