extends Button
class_name HanabiSlantButton

var fill: Color = Color("1a2825")
var accent: Color = Color("53645d")
var primary: bool = false
var art: Texture2D
var art_uv: PackedVector2Array
var caption: Label
var shade: float = 0.0
var hover_amount: float = 0.0
var variant: String = "secondary"
var preview_state: String = ""
var kind: String = "button"
var lean_override: float = -1.0
var selected: bool = false
var art_focus := Vector2(0.5, 0.5)
var background_art: Texture2D
var icon_name: String = ""
var leading_icon: String = ""
var wordmark: TextureRect

func points() -> PackedVector2Array:
	var lean := size.x * 0.06 if lean_override < 0.0 else lean_override
	return PackedVector2Array([Vector2(lean, 0), Vector2(size.x, 0), Vector2(size.x - lean, size.y), Vector2(0, size.y)])

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, points())

func interaction_state() -> String:
	if disabled: return "disabled"
	if preview_state in ["normal", "hover", "pressed", "disabled"]: return preview_state
	if get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]: return "pressed"
	if is_hovered() or has_focus(): return "hover"
	return "normal"

func surface_state() -> String:
	return "pressed" if selected and variant == "tab" and not disabled else interaction_state()

func face_points() -> PackedVector2Array:
	if kind not in ["button", "ready", "seat"]: return points()
	return HanabiUIBevel.face(size, points()[0].x, surface_state())

func content_shift() -> float:
	if kind not in ["button", "ready", "seat"]: return 0.0
	var front := face_points()
	return roundf((front[0].y + front[2].y - size.y) / 2.0)

func _process(delta: float) -> void:
	var target := 1.0 if (is_hovered() or has_focus() or preview_state == "hover") and not disabled else 0.0
	hover_amount = move_toward(hover_amount, target, delta * 8.0)
	if caption:
		caption.position.y = content_shift()
		caption.text = text
		caption.modulate = Color.WHITE
		caption.add_theme_color_override("font_color", Color("85968b") if disabled else Color("101617") if primary or (variant == "tab" and preview_state == "pressed") else Color("edf0eb"))
	if wordmark:
		wordmark.modulate = Color("85968b") if disabled else Color("101617") if primary else Color("edf0eb")
	queue_redraw()

func _draw() -> void:
	var icon_state := interaction_state()
	var polygon := face_points()
	var relief := kind in ["button", "ready", "seat"]
	var background := Color("d7ea45") if primary else fill
	if disabled: background = Color("1a211f")
	elif button_pressed: background = background.darkened(0.15)
	else: background = background.lightened(hover_amount * 0.06)
	if relief: HanabiUIBevel.draw_body(self, points(), polygon, background)
	else: draw_colored_polygon(polygon, background)
	if background_art:
		draw_polygon(polygon, PackedColorArray([Color(0.65, 0.75, 0.68, 0.24)]), HanabiUISkin.cover_uv(polygon, size, background_art.get_size()), background_art)
	if not art and kind == "button":
		var state := surface_state()
		var skin := HanabiUISkin.button("tab" if variant == "tab" else "primary" if primary else variant, state)
		var uv := PackedVector2Array()
		for point in polygon: uv.append(Vector2(point.x / size.x, (point.y - polygon[0].y) / (polygon[2].y - polygon[0].y)))
		draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, skin)
	if art:
		var tint := Color.WHITE.darkened(shade)
		var uv := art_uv if not art_uv.is_empty() else HanabiUISkin.cover_uv(polygon, size, art.get_size(), art_focus)
		draw_polygon(polygon, PackedColorArray([tint]), uv, art)
	var border := Color("d7ea45") if primary or selected or has_focus() else accent.lightened(0.2) if hover_amount > 0.2 else accent
	if kind == "menu" and hover_amount > 0.2 and not disabled: border = Color("d7ea45")
	if disabled: border = Color("394941")
	if relief:
		var rim_color := Color("d7ea45") if primary or (variant == "tab" and surface_state() == "pressed") else Color("352b2a") if variant == "danger" else Color("20362f")
		if disabled: rim_color = Color("18251e")
		HanabiUIBevel.draw_rim(self, polygon, rim_color, border, surface_state() == "pressed", disabled)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, border, 2.0 if has_focus() else 1.0, false)
	if selected:
		draw_line(polygon[0] + Vector2(2, 3), polygon[0] + Vector2(59, 3), border, 3.0)
	if kind == "menu":
		var corner := polygon[2]
		var wedge := PackedVector2Array([corner - Vector2(76, 0), corner, corner + Vector2(20, -71)])
		draw_colored_polygon(wedge, Color("d7ea45") if selected or has_focus() or is_hovered() else Color("c8cec7"))
		if not has_node("MenuIcon"):
			HanabiUISkin.draw_material_icon(self, icon_name if not icon_name.is_empty() else "chevron", Rect2(corner - Vector2(56, 53), Vector2(40, 40)), icon_state)
	elif kind == "ready":
		HanabiUISkin.draw_material_icon(self, "check" if text.contains("READY") else "play", Rect2(size.x - 42, (size.y - 40) / 2 + content_shift() - (1 if icon_state == "pressed" else 0), 40, 40), icon_state)
	elif not leading_icon.is_empty():
		HanabiUISkin.draw_material_icon(self, leading_icon, Rect2(10 if size.x >= 180 else (size.x - 40) / 2, (size.y - 40) / 2 + content_shift() - (1 if icon_state == "pressed" else 0), 40, 40), icon_state)
