extends RefCounted
class_name HanabiUIBevel

static func face(size: Vector2, lean: float, state: String) -> PackedVector2Array:
	var depth := clampf(roundf(size.y * 0.12), 2.0, 6.0)
	var top := 1.0
	if state == "hover":
		depth += 1.0
		top = 0.0
	elif state == "pressed":
		depth = 1.0
		top = minf(4.0, size.y * 0.14)
	elif state == "disabled":
		depth = 2.0
	return PackedVector2Array([Vector2(lean, top), Vector2(size.x, top), Vector2(size.x - lean, size.y - depth), Vector2(0, size.y - depth)])

static func draw_body(canvas: CanvasItem, outer: PackedVector2Array, front: PackedVector2Array, color: Color) -> void:
	canvas.draw_colored_polygon(outer, color.darkened(0.55))
	canvas.draw_colored_polygon(PackedVector2Array([front[3], front[2], outer[2], outer[3]]), color.darkened(0.38))
	canvas.draw_colored_polygon(front, color)

static func draw_rim(canvas: CanvasItem, front: PackedVector2Array, color: Color, border: Color, pressed: bool = false, muted: bool = false) -> void:
	var highlight := color.lightened(0.34 if not muted else 0.10)
	var low := color.darkened(0.32)
	if pressed:
		highlight = color.darkened(0.34)
		low = color.lightened(0.10)
	canvas.draw_line(front[0] + Vector2(2, 1), front[1] + Vector2(-3, 1), highlight, 2.0, false)
	canvas.draw_line(front[0] + Vector2(1, 2), front[3] + Vector2(2, -2), highlight, 1.0, false)
	canvas.draw_line(front[3] + Vector2(3, -1), front[2] + Vector2(-2, -1), low, 2.0, false)
	canvas.draw_line(front[1] + Vector2(-2, 2), front[2] + Vector2(-1, -2), low, 2.0, false)
	var outline := front.duplicate()
	outline.append(front[0])
	canvas.draw_polyline(outline, border, 1.0, false)

static func chamfer(rect: Rect2, cut: float = 2.0) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([a + Vector2(cut, 0), Vector2(b.x-cut, a.y), Vector2(b.x, a.y+cut), b-Vector2(0,cut), b-Vector2(cut,0), Vector2(a.x+cut,b.y), Vector2(a.x,b.y-cut), a+Vector2(0,cut)])
