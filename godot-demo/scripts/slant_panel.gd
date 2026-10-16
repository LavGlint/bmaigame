extends Panel
class_name HanabiSlantPanel

var fill: Color = Color("1a2825")
var border: Color = Color("43584f")
var lean_override: float = -1.0

func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _draw() -> void:
	var lean := minf(22.0, minf(size.y * 0.22, size.x * 0.25)) if lean_override < 0.0 else lean_override
	if size.x < 12 or size.y < 8: lean = 0.0
	var points := PackedVector2Array([Vector2(lean, 0), Vector2(size.x, 0), Vector2(size.x - lean, size.y), Vector2(0, size.y)])
	if border.a > 0.0 and fill.a > 0.3 and size.x > 170 and size.y > 70:
		var front := HanabiUIBevel.face(size, lean, "normal")
		HanabiUIBevel.draw_body(self, points, front, fill)
		HanabiUIBevel.draw_rim(self, front, fill, border)
	else: draw_colored_polygon(points, fill)
	if border.a > 0.0:
		points.append(points[0])
		draw_polyline(points, border, 1.0, false)
		if fill.a > 0.3 and size.x > 170 and size.y > 70:
			draw_line(points[0] + Vector2(4, 3), points[0] + Vector2(38, 3), Color(border, 0.75), 2.0)
			draw_line(points[2] - Vector2(36, 3), points[2] - Vector2(3, 3), Color(border, 0.75), 2.0)
			draw_rect(Rect2(points[0] + Vector2(4, 5), Vector2(2, 6)), Color(border, 0.75))
			draw_rect(Rect2(points[2] - Vector2(5, 11), Vector2(2, 6)), Color(border, 0.75))
