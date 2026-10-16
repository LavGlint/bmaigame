extends Node2D
class_name HanabiArenaWorld

signal match_finished
signal effect(kind: String)

var rules: HanabiRules = HanabiRules.new()
var router: HanabiInputRouter
var font: Font
var fighters: Array[HanabiFighter] = []
var boomerangs: Array[HanabiRangedProjectile] = []
var combat: HanabiRangedCombat
var collision_shapes: Array[Dictionary] = []
var field := Rect2(20,20,1080,590)
var level: Node2D
var actor_parent: Node2D
var navigation: HanabiArenaNavigation
const MAP_IDS := ["industrial","ruins","woodland"]
const MAP_NAMES := ["工业仓库·三线穿插","石砌遗迹·双环绕行","林间哨站·分叉穿插"]
const MAP_OFFSET := Vector2(80,76)
var brains: Array[HanabiBotBrain] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var state: String = "lobby"
var before_pause: String = "playing"
var pause_reason: String = ""
var remaining: float = 240.0
var phase_time: float = 0.0
var round_number: int = 1
var match_leg: int = 1
var map_variant: int = 0
var started: bool = false
var demo: bool = false
var early_end: bool = false
var winner: HanabiFighter
var effects: Array[Dictionary] = []
var visual_time: float = 0.0

func _ready() -> void:
	rng.randomize()
	combat = HanabiRangedCombat.new()
	combat.configure(self)
	load_map(map_variant)
	for slot in range(4):
		var fighter := HanabiFighter.new()
		fighter.configure(slot, self)
		actor_parent.add_child(fighter)
		fighters.append(fighter)
		var brain := HanabiBotBrain.new()
		brain.direction = -1.0 if slot % 2 else 1.0
		brains.append(brain)
	reset_to_lobby()

func load_map(index: int) -> void:
	index = clampi(index,0,2)
	if is_instance_valid(level) and map_variant == index: return
	clear_boomerangs()
	effects.clear()
	for fighter in fighters:
		fighter.reparent(self,false)
	if combat.get_parent(): combat.reparent(self,false)
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	map_variant = index
	level = load("res://assets/maps/%s/map.tscn" % MAP_IDS[index]).instantiate()
	level.position = MAP_OFFSET
	add_child(level)
	actor_parent = level.get_actor_parent()
	var bounds: Array = level.config.playable_bounds
	field = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	collision_shapes.clear()
	# Read actual scene shapes, not bounding boxes or a second authored layout.
	for shape: CollisionPolygon2D in level.find_children("*","CollisionPolygon2D",true,false):
		var points := PackedVector2Array()
		for point in shape.polygon: points.append(actor_parent.to_local(shape.to_global(point)))
		collision_shapes.append({"id":collision_shapes.size(),"name":str(shape.get_parent().get_parent().name),"polygon":points})
	for shape: CollisionShape2D in level.get_node("Boundary").find_children("*","CollisionShape2D",true,false):
		var rectangle := shape.shape as RectangleShape2D
		var points := PackedVector2Array()
		for point in HanabiMapGeometry.rectangle(Rect2(-rectangle.size*0.5,rectangle.size)): points.append(actor_parent.to_local(shape.to_global(point)))
		collision_shapes.append({"id":collision_shapes.size(),"name":str(shape.get_parent().name),"polygon":points})
	if combat.get_parent(): combat.reparent(actor_parent,false)
	else: actor_parent.add_child(combat)
	combat.position = Vector2.ZERO
	combat.y_sort_enabled = true
	for fighter in fighters:
		fighter.reparent(actor_parent,false)
		fighter.z_index = 0
		fighter.set_presentation_size(rules.fighter_height,rules.fighter_radius)
		fighter.reset_round()
	navigation = HanabiArenaNavigation.new()
	navigation.configure(self)
	for brain in brains: brain.clock = 0.0; brain.cached.clear()

func spawn_position(slot: int) -> Vector2:
	return actor_parent.to_local(level.get_spawn_global(slot))

func combat_global(point: Vector2) -> Vector2:
	return actor_parent.to_global(point)

func combat_from_canvas(point: Vector2) -> Vector2:
	return actor_parent.get_global_transform_with_canvas().affine_inverse()*point

func clear_boomerangs() -> void:
	if combat: combat.clear()

func reset_to_lobby() -> void:
	clear_boomerangs()
	state = "lobby"
	remaining = rules.match_seconds
	started = false
	match_leg = 1
	demo = false
	winner = null
	effects.clear()
	if router:
		router.locked = false
	for fighter in fighters:
		fighter.score = 0
		fighter.kills = 0
		fighter.wins = 0
		fighter.deaths = 0
		fighter.survival = 0.0
		fighter.reset_round()
	queue_redraw()

func start_match(is_demo: bool = false) -> void:
	reset_to_lobby()
	demo = is_demo
	state = "countdown"
	phase_time = 2.6
	round_number = 1
	early_end = false
	remaining = rules.match_seconds
	if router:
		router.locked = true
		router.arm_gameplay()
	var lots: Array[int] = [0, 1, 2, 3]
	for index in range(3, 0, -1):
		var other := rng.randi_range(0, index)
		var temp: int = lots[index]
		lots[index] = lots[other]
		lots[other] = temp
	for slot in range(4):
		fighters[slot].lot = lots[slot]
		brains[slot].clock = 0.0
		brains[slot].cached.clear()

func spawn_boom(fighter: HanabiFighter, release_aim: Vector2 = Vector2.ZERO) -> void:
	combat.fire(fighter,fighter.aim if release_aim.is_zero_approx() else release_aim.normalized())

func set_paused(reason: String = "按 P 或点击继续") -> void:
	if state in ["lobby", "finished", "paused"]:
		return
	before_pause = state
	state = "paused"
	if router: router.held_run_keys.clear()
	pause_reason = reason
	for fighter in fighters:
		fighter.sprite.pause()

func resume_match() -> void:
	if state == "paused":
		if router: router.arm_gameplay()
		state = before_pause
		pause_reason = ""
		for fighter in fighters:
			fighter.last_actions.clear()

func finish_match(early: bool = false) -> void:
	if state == "finished":
		return
	early_end = early
	state = "finished"
	clear_boomerangs()
	if not early:
		remaining = 0.0
	if router:
		router.locked = false
	effect.emit("finish")
	match_finished.emit()

func _physics_process(delta: float) -> void:
	if state == "paused":
		if router: router.end_frame()
		return
	visual_time += delta
	_update_particles(delta)
	if state == "lobby":
		for fighter in fighters:
			fighter.presentation_step(delta)
		queue_redraw()
		if router:
			router.end_frame()
		return
	if state in ["paused", "finished"]:
		if router:
			router.end_frame()
		queue_redraw()
		return
	if started:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			finish_match()
			return
		var target_leg := mini(rules.rounds, 1 + int((rules.match_seconds - remaining) / rules.round_seconds))
		if target_leg > match_leg:
			match_leg = target_leg
			clear_boomerangs()
			for fighter in fighters: fighter.reset_round()
			state = "countdown"
			phase_time = 0.9
	if state in ["countdown", "roundover"]:
		for fighter in fighters: fighter.presentation_step(delta)
		phase_time -= delta
		if phase_time <= 0.0:
			if state == "roundover":
				round_number += 1
				clear_boomerangs()
				for fighter in fighters:
					fighter.reset_round()
				state = "countdown"
				phase_time = 0.9
			else:
				state = "playing"
				started = true
				effect.emit("go")
		if router:
			router.end_frame()
		queue_redraw()
		return
	for slot in range(4):
		var fighter: HanabiFighter = fighters[slot]
		var command: Dictionary = {}
		if fighter.alive:
			command = brains[slot].command(fighter, self, delta) if demo or router == null or router.modes[slot] == "ai" else router.command(slot)
		fighter.step(command, delta)
		fighter.z_index = 0
	combat.step(delta)
	var alive: Array[HanabiFighter] = []
	for fighter in fighters:
		if fighter.alive:
			alive.append(fighter)
	if alive.size() <= 1:
		winner = alive[0] if alive.size() == 1 else null
		if winner:
			winner.score += rules.win_points
			winner.wins += 1
			winner.feedback("存活 +3", 0.8)
			burst(winner.position, winner.tint, 35)
			effect.emit("win")
		state = "roundover"
		clear_boomerangs()
		phase_time = 1.8
	if router:
		router.end_frame()
	queue_redraw()

func ranking() -> Array[HanabiFighter]:
	var ranked: Array[HanabiFighter] = fighters.duplicate()
	ranked.sort_custom(func(a: HanabiFighter, b: HanabiFighter):
		if a.score != b.score: return a.score > b.score
		if a.kills != b.kills: return a.kills > b.kills
		if a.wins != b.wins: return a.wins > b.wins
		if roundi(a.survival * 10) != roundi(b.survival * 10): return a.survival > b.survival
		return a.lot < b.lot)
	return ranked

func leg_remaining() -> float:
	return maxf(0.0, remaining - maxf(0.0, rules.match_seconds - match_leg * rules.round_seconds))

func burst(at: Vector2, tint: Color, amount: int) -> void:
	for index in range(amount):
		effects.append({"position": at, "velocity": Vector2(rng.randf_range(-130, 130), rng.randf_range(-130, 130)), "color": tint if index % 3 else Color("fff4d6"), "life": rng.randf_range(0.4, 0.9), "size": rng.randf_range(2, 5)})

func _update_particles(delta: float) -> void:
	for particle in effects:
		particle.life -= delta
		particle.position += particle.velocity * delta
		particle.velocity.y += 40.0 * delta
	effects = effects.filter(func(particle): return particle.life > 0)

func _draw() -> void:
	if not is_instance_valid(actor_parent): return
	draw_set_transform_matrix(global_transform.affine_inverse()*actor_parent.global_transform)
	for particle in effects:
		var color: Color = particle.color
		color.a = clampf(particle.life / 0.5, 0.0, 1.0)
		draw_circle(particle.position, particle.size, color)
	draw_set_transform(Vector2.ZERO)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box
