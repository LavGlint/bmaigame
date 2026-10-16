extends RefCounted
class_name HanabiMenuInput

var stick_latches: Array[int] = [0, 0, 0, 0]
var stick_repeat: Array[float] = [0.0, 0.0, 0.0, 0.0]
var digital_latches: Array[int] = [0, 0, 0, 0]
var digital_repeat: Array[float] = [0.0, 0.0, 0.0, 0.0]
var waiting_neutral: Array[bool] = [false, false, false, false]
var turn_slot: int = -1
var turn_device: int = -1
const STICK_PRESS := 0.40
const STICK_RELEASE := 0.22
const INITIAL_REPEAT := 0.45
const HELD_REPEAT := 0.32

func bind_turn(router: HanabiInputRouter, current_slot: int) -> void:
	turn_slot = current_slot
	turn_device = router.devices[current_slot] if current_slot in range(4) else -1
	for slot in range(4):
		stick_latches[slot] = 0
		stick_repeat[slot] = 0.0
		digital_latches[slot] = 0
		digital_repeat[slot] = 0.0
		waiting_neutral[slot] = false
	if current_slot in range(4) and router.modes[current_slot] == "pad":
		var state := router.menu_command(turn_device)
		waiting_neutral[current_slot] = state.move.length() > 0.25 or state.left or state.right

func ensure_turn(router: HanabiInputRouter, current_slot: int) -> void:
	if current_slot >= 0 and (turn_slot != current_slot or turn_device != router.devices[current_slot]):
		bind_turn(router, current_slot)

func suspend_sticks(router: HanabiInputRouter, current_slot: int) -> void:
	bind_turn(router, current_slot)
	if current_slot in range(4): waiting_neutral[current_slot] = true

func stick_event(event: InputEventJoypadMotion, router: HanabiInputRouter, current_slot: int) -> Dictionary:
	ensure_turn(router, current_slot)
	if current_slot not in range(4) or router.modes[current_slot] != "pad" or event.device != router.devices[current_slot] or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: return {}
	if not router.slot_connected(current_slot): return {}
	if waiting_neutral[current_slot]:
		var state := router.menu_command(event.device)
		var position: Vector2 = state.move
		if event.axis == JOY_AXIS_LEFT_X: position.x = event.axis_value
		else: position.y = event.axis_value
		if position.length() <= 0.25 and not state.left and not state.right: waiting_neutral[current_slot] = false
		return {}
	if event.axis != JOY_AXIS_LEFT_X: return {}
	return _stick_sample(current_slot, event.axis_value, 0.0)

func _stick_sample(slot: int, axis: float, delta: float) -> Dictionary:
	if absf(axis) <= STICK_RELEASE:
		stick_latches[slot] = 0
		stick_repeat[slot] = 0.0
		return {}
	var direction := 1 if axis >= STICK_PRESS else -1 if axis <= -STICK_PRESS else 0
	if direction == 0: return {}
	stick_repeat[slot] -= delta
	if stick_latches[slot] == direction and stick_repeat[slot] > 0.0: return {}
	stick_repeat[slot] = HELD_REPEAT if stick_latches[slot] == direction else INITIAL_REPEAT
	stick_latches[slot] = direction
	return {"slot": slot, "action": "select", "direction": direction}

func _digital_sample(slot: int, direction: int, delta: float) -> Dictionary:
	if direction == 0:
		digital_latches[slot] = 0
		digital_repeat[slot] = 0.0
		return {}
	digital_repeat[slot] -= delta
	if digital_latches[slot] == direction and digital_repeat[slot] > 0.0: return {}
	digital_repeat[slot] = HELD_REPEAT if digital_latches[slot] == direction else INITIAL_REPEAT
	digital_latches[slot] = direction
	return {"slot": slot, "action": "select", "direction": direction}

static func configure_native_menu() -> void:
	# Current Godot defaults contain keyboard-only UI actions. Retain those
	# bindings and add any-device controller events for native focused controls.
	for entry in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = entry[1]
		if not InputMap.action_has_event(entry[0], event): InputMap.action_add_event(entry[0], event)
	for entry in [["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = entry[1]
		event.axis_value = entry[2]
		if not InputMap.action_has_event(entry[0], event): InputMap.action_add_event(entry[0], event)

func decode(event: InputEvent, router: HanabiInputRouter) -> Dictionary:
	for slot in range(4):
		if event is InputEventKey and event.pressed and not event.echo:
			var key: int = event.physical_keycode
			if router.modes[slot] == "key1":
				if key == KEY_A: return {"slot": slot, "action": "select", "direction": -1}
				if key == KEY_D: return {"slot": slot, "action": "select", "direction": 1}
				if key == KEY_SPACE: return {"slot": slot, "action": "ready"}
				if key == KEY_Q: return {"slot": slot, "action": "cancel"}
			if router.modes[slot] == "key2":
				if key == KEY_LEFT: return {"slot": slot, "action": "select", "direction": -1}
				if key == KEY_RIGHT: return {"slot": slot, "action": "select", "direction": 1}
				if key == KEY_ENTER: return {"slot": slot, "action": "ready"}
				if key == KEY_BACKSPACE: return {"slot": slot, "action": "cancel"}
		if event is InputEventJoypadButton and router.modes[slot] == "pad" and router.devices[slot] == event.device:
			if not event.pressed:
				if event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
					digital_latches[slot] = 0
					digital_repeat[slot] = 0.0
				return {}
			match event.button_index:
				JOY_BUTTON_DPAD_LEFT:
					if waiting_neutral[slot]: return {}
					return _digital_sample(slot, -1, 0.0)
				JOY_BUTTON_DPAD_RIGHT:
					if waiting_neutral[slot]: return {}
					return _digital_sample(slot, 1, 0.0)
				JOY_BUTTON_A: return {"slot": slot, "action": "ready"}
				JOY_BUTTON_B: return {"slot": slot, "action": "cancel"}
				JOY_BUTTON_Y: return {"slot": slot, "action": "device"}
				JOY_BUTTON_START: return {"slot": slot, "action": "start"}
	return {}

func poll_sticks(router: HanabiInputRouter, delta: float, current_slot: int = -1) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	ensure_turn(router, current_slot)
	for slot in range(4):
		if current_slot >= 0 and slot != current_slot:
			stick_latches[slot] = 0
			stick_repeat[slot] = 0.0
			continue
		if router.modes[slot] != "pad" or not router.slot_connected(slot): continue
		var state := router.menu_command(router.devices[slot])
		var direction := int(state.right) - int(state.left)
		if waiting_neutral[slot]:
			if state.move.length() <= 0.25 and direction == 0: waiting_neutral[slot] = false
			continue
		var digital := _digital_sample(slot, direction, delta)
		if direction != 0:
			if not digital.is_empty(): actions.append(digital)
			continue
		var analog := _stick_sample(slot, state.move.x, delta)
		if not analog.is_empty(): actions.append(analog)
	return actions
