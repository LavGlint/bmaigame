extends Control

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1212"))
	draw_texture_rect(HanabiUISkin.texture("background.png"), Rect2(Vector2.ZERO, size), false, Color(0.77, 0.88, 0.80, 0.75))
	for index in range(4):
		var x: float = -335 + index * 390
		draw_colored_polygon(PackedVector2Array([Vector2(x+350,0),Vector2(x+368,0),Vector2(x-99,720),Vector2(x-117,720)]), Color("2a3733a0"))
		draw_colored_polygon(PackedVector2Array([Vector2(x+305,0),Vector2(x+341,0),Vector2(x-127,720),Vector2(x-163,720)]), Color("080f10a0"))
	for cluster in [Vector2(19, 12), Vector2(421, 370), Vector2(1115, 560)]:
		for x in range(17):
			for y in range(15):
				var opacity := maxf(0.0, 0.085 - (x + y) * 0.0025)
				draw_rect(Rect2(cluster + Vector2(x * 6, y * 6), Vector2(2, 2)), Color(0.69, 0.79, 0.73, opacity))
	draw_line(Vector2(28,661),Vector2(1254,661),Color("314b4050"),1)
	draw_line(Vector2(6,705),Vector2(31,705),Color("d7ea45"),3)
