extends Resource
class_name HanabiRules

@export var match_seconds: float = 240.0
@export var round_seconds: float = 150.0
@export var rounds: int = 3
@export var hearts: int = 2
@export var move_speed: float = 225.0
@export var run_speed: float = 315.0
@export var dash_speed: float = 680.0
@export var dash_seconds: float = 0.18
@export var dash_cooldown: float = 1.2
@export var throw_speed: float = 570.0
@export var return_speed: float = 640.0
@export var return_after: float = 0.56
@export var kill_points: int = 1
@export var win_points: int = 3
@export var difficulty: String = "easy"
@export_range(64.0,72.0) var fighter_height: float = 68.0
@export var fighter_radius: float = 16.0

const COLORS: Array[Color] = [Color("608e80"), Color("c8a04f"), Color("a283a9"), Color("c58591")]
const NAMES: Array[String] = ["赤刃", "星火", "月织", "桃铃"]

static func prize(rank: int) -> String:
	return "一等奖" if rank == 0 else "二等奖" if rank == 1 else "鼓励奖"
