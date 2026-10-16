extends Node
class_name HanabiTonePlayer

var enabled: bool = false
var volume: float = 0.7:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		for player in get_children():
			if player is AudioStreamPlayer: player.volume_db = -5.0 + linear_to_db(maxf(0.001, volume))

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func play_effect(kind: String) -> void:
	if not enabled:
		return
	var notes := {"throw": 550.0, "hit": 180.0, "ko": 120.0, "catch": 800.0, "dash": 330.0, "win": 880.0, "go": 660.0, "slash": 220.0, "finish": 1046.0}
	if not notes.has(kind):
		return
	var rate: int = 22050
	var count: int = 3307
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for index in range(count):
		var progress: float = float(index) / count
		var frequency: float = notes[kind] * lerpf(1.0, 1.5 if kind == "win" else 0.6, progress)
		phase += TAU * frequency / rate
		data.encode_s16(index * 2, int(sin(phase) * (1.0 - progress) * 10000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -5.0 + linear_to_db(maxf(0.001, volume))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
