extends TextureRect
class_name HanabiGamepadPrompt

const KEYS = ["a", "b", "x", "y", "l", "r", "menu", "view", "lb", "rb"]
var key_name: String = "a"
var action_id: String = ""
var app: Control
var preview_state: String = ""
var current_state: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	refresh_state()

func action_held() -> bool:
	if not is_instance_valid(app) or action_id.is_empty(): return false
	if app.screen == "game":
		if action_id == "pause":
			if Input.is_physical_key_pressed(KEY_P) or Input.is_physical_key_pressed(KEY_ESCAPE): return true
			for device in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(device, JOY_BUTTON_START): return true
		else:
			for slot in range(4):
				var command: Dictionary = app.router.raw_command(slot)
				if action_id == "move" and command.get("move", Vector2.ZERO).length() > 0.2: return true
				if action_id != "move" and command.get(action_id, false): return true
	elif action_id == "confirm": return Input.is_action_pressed("ui_accept")
	return false

func refresh_state() -> void:
	var next := preview_state if preview_state in ["normal", "hover", "pressed", "disabled"] else "pressed" if action_held() else "normal"
	if next == current_state: return
	current_state = next
	texture = HanabiUISkin.texture("gamepad-prompts/%s/%s.png" % [current_state, key_name])

func _process(_delta: float) -> void:
	refresh_state()
