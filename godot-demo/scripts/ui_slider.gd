extends HSlider
class_name HanabiUISlider

var held: bool = false

func _ready() -> void:
	drag_started.connect(func():
		held = true
		add_theme_icon_override("grabber_highlight", HanabiUISkin.texture("components/slider_thumb_pressed.svg")))
	drag_ended.connect(func(_changed):
		held = false
		add_theme_icon_override("grabber_highlight", HanabiUISkin.texture("components/slider_thumb_hover.svg")))
