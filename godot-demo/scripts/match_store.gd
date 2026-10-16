extends RefCounted
class_name HanabiMatchStore

const STORE_PATH := "user://matches.json"
var records: Array = []
var storage_path: String = STORE_PATH

func _init(path: String = STORE_PATH) -> void:
	storage_path = path
	if FileAccess.file_exists(storage_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
		if parsed is Array:
			records = parsed.filter(func(record): return record is Dictionary and record.has("ranking"))

func add(world: HanabiArenaWorld, router: HanabiInputRouter) -> void:
	var ranking: Array = []
	var humans: int = 0
	for fighter in world.ranking():
		var mode: String = "ai" if world.demo else router.label_for(fighter.slot)
		if router.modes[fighter.slot] != "ai" and not world.demo:
			humans += 1
		ranking.append({"slot": fighter.slot + 1, "name": fighter.nickname, "score": fighter.score, "kills": fighter.kills, "wins": fighter.wins, "survival": snappedf(fighter.survival, 0.1), "lot": fighter.lot + 1, "mode": mode})
	records.push_front({"date": Time.get_datetime_string_from_system(), "seconds": world.rules.match_seconds, "early": world.early_end, "humans": humans, "ranking": ranking})
	if records.size() > 100:
		records.resize(100)
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records, "\t"))

func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(PackedByteArray([239, 187, 191]))
	file.store_csv_line(PackedStringArray(["时间", "正式时长秒", "真人数", "提前结束", "排名", "奖项", "席位", "昵称", "控制方式", "积分", "击倒", "小局胜场", "存活秒", "抽签序号"]))
	for record in records:
		for index in range(record.ranking.size()):
			var fighter: Dictionary = record.ranking[index]
			var safe_name: String = str(fighter.name)
			if safe_name.strip_edges().begins_with("=") or safe_name.strip_edges().begins_with("+") or safe_name.strip_edges().begins_with("-") or safe_name.strip_edges().begins_with("@"):
				safe_name = "'" + safe_name
			file.store_csv_line(PackedStringArray([str(record.date), str(record.seconds), str(record.humans), "是" if record.early else "否", str(index + 1), HanabiRules.prize(index), str(fighter.slot), safe_name, str(fighter.mode), str(fighter.score), str(fighter.kills), str(fighter.wins), str(fighter.survival), str(fighter.lot)]))
	return OK
