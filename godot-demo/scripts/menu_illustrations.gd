extends RefCounted
class_name HanabiMenuIllustrations

const DIRECTORY := "res://assets/ui/menu-illustrations/"
static var manifest: Dictionary = {}

static func card(index: int) -> Dictionary:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	return manifest.cards[index]

static func rectangle(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])

static func apply(button: HanabiSlantButton, index: int) -> void:
	var data := card(index)
	button.name = "Menu" + str(index + 1)
	button.art = load(DIRECTORY + data.file)
	button.lean_override = data.lean
	button.shade = data.shade
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.set_meta("illustration_id", data.id)
	var crop := rectangle(data.crop_pixels)
	# Affine mapping over the bounding rectangle, then clip to the slant polygon.
	# draw_polygon UVs are normalized; mapping quad corners to 0..1 would shear art.
	button.art_uv.clear()
	for point in button.points():
		button.art_uv.append((crop.position + point / button.size * crop.size) / button.art.get_size())
