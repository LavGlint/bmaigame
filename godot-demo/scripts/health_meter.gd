extends Control
class_name HanabiHealthMeter

var value: int = 3
var maximum: int = 3
var tint: Color = Color("608e80")
var cooldown: float = 0.0
var hit_pulse: float = 0.0
var last_value: int = 3

func _process(delta: float) -> void:
	if value < last_value: hit_pulse = 0.3
	last_value = value
	hit_pulse = maxf(0.0, hit_pulse - delta)
	queue_redraw()

func _draw() -> void:
	var gap := 3.0
	var width := floorf((size.x - gap * (maximum - 1)) / maximum / 2) * 2
	for index in range(maximum):
		var x := index * (width + gap)
		var color := tint if index < value else Color(0.25, 0.32, 0.29, 0.65)
		if hit_pulse > 0.0 and index >= value: color = Color("df786e")
		var polygon := PackedVector2Array([Vector2(x + 3, 0), Vector2(x + width, 0), Vector2(x + width - 3, 8), Vector2(x, 8)])
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color("101617"), 3.0, false)
		draw_colored_polygon(polygon, color)
		draw_line(Vector2(x + 4, 1), Vector2(x + width - 2, 1), color.lightened(0.28), 1.0, false)
		draw_line(Vector2(x + 2, 7), Vector2(x + width - 4, 7), color.darkened(0.35), 2.0, false)
	if cooldown > 0.0:
		draw_rect(Rect2(0, 13, size.x, 2), Color(0.07, 0.12, 0.10, 0.3))
		draw_rect(Rect2(0, 13, floorf(size.x * (1.0 - cooldown) / 2) * 2, 2), Color("d7ea45"))
