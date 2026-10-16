extends Sprite2D

var arena: HanabiArenaWorld
var last_variant: int = -1

func _ready() -> void:
	texture = preload("res://assets/autumn_arena.png")
	position = Vector2(600, 380)
	scale = Vector2(1200.0 / texture.get_width(), 760.0 / texture.get_height())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = HanabiArtwork.map_material(0)

func _process(_delta: float) -> void:
	if is_instance_valid(arena) and last_variant != arena.map_variant:
		last_variant = arena.map_variant
		material.set_shader_parameter("variant", last_variant)
