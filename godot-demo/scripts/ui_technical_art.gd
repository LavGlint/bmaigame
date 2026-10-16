extends Control
class_name HanabiUITechnicalArt

var tint: Color = Color("8ba394")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.39
	draw_circle(center, radius * 0.72, Color(tint, 0.035))
	for ring in [1.0, 0.84, 0.61]: draw_arc(center, radius * ring, 0.0, TAU, 80, Color(tint, 0.2), 1.0, true)
	for index in range(28):
		var direction := Vector2.from_angle(index * TAU / 28.0)
		draw_line(center + direction * radius, center + direction * radius * (1.11 if index % 7 == 0 else 1.035), Color(tint, 0.35), 1.0)
	draw_line(center - Vector2(radius * 1.2, 0), center + Vector2(radius * 1.2, 0), Color(tint, 0.12))
	draw_line(center - Vector2(0, radius * 1.2), center + Vector2(0, radius * 1.2), Color(tint, 0.12))
	draw_set_transform(center, -0.4, Vector2.ONE)
	draw_texture_rect(HanabiUISkin.texture("icons/boomerang.svg"), Rect2(-radius * 0.57, -radius * 0.57, radius * 1.14, radius * 1.14), false, Color(tint, 0.55))
	draw_set_transform(center, 1.1, Vector2.ONE)
	draw_texture_rect(HanabiUISkin.texture("icons/boomerang.svg"), Rect2(-radius * 0.57, -radius * 0.57, radius * 1.14, radius * 1.14), false, Color(tint, 0.25))
	draw_set_transform(Vector2.ZERO)
