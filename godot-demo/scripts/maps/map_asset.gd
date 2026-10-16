extends Node2D
## Reusable visual/collision map. Place actors directly under World to share Y sorting.
@export_file("*.json") var manifest_path: String
var config: Dictionary = {}
var overlay: Node2D

class ShapeOverlay extends Node2D:
	var data: Dictionary
	func _draw() -> void:
		for obstacle: Dictionary in data.get("obstacles", []):
			var polygon := PackedVector2Array()
			for p: Array in obstacle["collision"]: polygon.append(Vector2(p[0],p[1]))
			draw_colored_polygon(polygon,Color(0.1,0.9,1,0.18))
			polygon.append(polygon[0])
			draw_polyline(polygon,Color(0.1,0.9,1,0.9),1.5)
		var bounds: Array = data["playable_bounds"]
		draw_rect(Rect2(bounds[0],bounds[1],bounds[2],bounds[3]),Color(1,0.7,0.2),false,2)
		for p: Array in data["spawn_points"]:
			draw_circle(Vector2(p[0],p[1]),16,Color(0.3,1,0.5,0.3))
			draw_arc(Vector2(p[0],p[1]),16,0,TAU,32,Color(0.3,1,0.5),1)

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("Invalid map manifest: "+manifest_path)
		return
	config = parsed
	var debug := ShapeOverlay.new()
	debug.data = config
	debug.z_index = 100
	debug.visible = false
	add_child(debug)
	overlay = debug

func get_spawn(index: int) -> Vector2:
	var values: Array = config["spawn_points"][posmod(index,4)]
	return Vector2(values[0],values[1])

func get_spawn_global(index: int) -> Vector2:
	return to_global(get_spawn(index))

func get_actor_parent() -> Node2D:
	return $World

func set_debug_overlay(enabled: bool) -> void:
	if is_instance_valid(overlay): overlay.visible = enabled
