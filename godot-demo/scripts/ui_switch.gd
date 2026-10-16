extends CheckButton
class_name HanabiUISwitch

var amount: float = 0.0
var held: bool = false

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color", "font_shadow_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		add_theme_icon_override(state, ImageTexture.new())
	amount = 1.0 if button_pressed else 0.0
	button_down.connect(func(): held = true)
	button_up.connect(func(): held = false)
	toggled.connect(func(_value): queue_redraw())

func _process(delta: float) -> void:
	amount = move_toward(amount, 1.0 if button_pressed else 0.0, delta * 8.0)
	queue_redraw()

func _draw() -> void:
	var color := Color("85968b") if disabled else Color("edf0eb")
	draw_string(get_theme_default_font(), Vector2(13, size.y / 2 + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
	var track := Rect2(size.x - 78, size.y / 2 - 14, 66, 28)
	var outline := Color("d7ea45") if button_pressed and not disabled else Color("486257")
	draw_colored_polygon(HanabiUIBevel.chamfer(track), Color("0a1411"))
	draw_line(track.position + Vector2(3, 1), Vector2(track.end.x-3, track.position.y+1), Color("050c09"), 2.0, false)
	draw_line(Vector2(track.position.x+3,track.end.y-1), track.end-Vector2(3,1), outline, 1.0, false)
	var thumb := Rect2(track.position + Vector2(4 + roundf(amount * 17) * 2, 3), Vector2(24, 22))
	var body := Color("d7ea45") if button_pressed else Color("aabeb7")
	if disabled: body = Color("54665b")
	elif is_hovered() or has_focus(): body = body.lightened(0.13)
	var face := Rect2(thumb.position + Vector2(0, 2 if held else 0), Vector2(24, 20 if held else 18))
	draw_colored_polygon(HanabiUIBevel.chamfer(thumb), body.darkened(0.45))
	draw_colored_polygon(HanabiUIBevel.chamfer(face), body.darkened(0.08) if held else body)
	draw_line(face.position+Vector2(3,1), Vector2(face.end.x-3,face.position.y+1), body.darkened(0.2) if held else body.lightened(0.5), 2.0, false)
	draw_line(Vector2(face.position.x+3,face.end.y-1), face.end-Vector2(3,1), body.darkened(0.3), 2.0, false)
	for x in [10, 13]:
		draw_line(face.position+Vector2(x,5),face.position+Vector2(x,12),body.darkened(0.30),1.0,false)
	if (has_focus() or is_hovered()) and not disabled:
		var focus_ring := HanabiUIBevel.chamfer(track.grow(2))
		focus_ring.append(focus_ring[0])
		draw_polyline(focus_ring, Color("d7ea45"), 1.0, false)
