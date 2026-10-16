extends TextureRect
class_name HanabiUIIcon

var icon_name: String = ""
var interaction_owner: BaseButton
var current_state: String = ""
var rest_position: Vector2

func _ready() -> void:
	rest_position = position
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ancestor := get_parent()
	while ancestor:
		if ancestor is BaseButton:
			interaction_owner = ancestor
			break
		ancestor = ancestor.get_parent()
	refresh_state()
	set_process(is_instance_valid(interaction_owner))

func refresh_state() -> void:
	var next := "normal"
	if is_instance_valid(interaction_owner):
		if interaction_owner is HanabiSlantButton:
			next = interaction_owner.interaction_state()
		elif interaction_owner.disabled: next = "disabled"
		elif interaction_owner.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]: next = "pressed"
		elif interaction_owner.is_hovered() or interaction_owner.has_focus(): next = "hover"
	if next == current_state: return
	current_state = next
	texture = HanabiUISkin.icon(icon_name, current_state)
	modulate = Color("87958d") if next == "disabled" else Color.WHITE

func _process(_delta: float) -> void:
	refresh_state()
	if interaction_owner is HanabiSlantButton:
		position = rest_position + Vector2(0, interaction_owner.content_shift() - (1 if current_state == "pressed" and interaction_owner.kind in ["button", "ready", "seat"] else 0))
