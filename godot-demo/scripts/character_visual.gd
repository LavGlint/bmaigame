extends Node2D
# Synced character.tscn uses the same deterministic controller as combat.
@export_file("*.json") var manifest_path: String
@export var autoplay := true
var driver: HanabiFighterAnimation
@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	driver = HanabiFighterAnimation.new()
	var role := int(manifest_path.get_base_dir().get_file().trim_prefix("role_"))
	driver.configure(sprite, role)

func play_action(action: StringName, direction: StringName = &"down", restart := true) -> void:
	driver.play(action,direction,restart)

func advance(delta: float) -> Dictionary:
	return driver.advance(delta)
