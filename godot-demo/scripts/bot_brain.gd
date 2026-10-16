extends RefCounted
class_name HanabiBotBrain

var clock: float = 0.0
var cached: Dictionary = {}
var direction: float = 1.0

func command(fighter: HanabiFighter, world, delta: float) -> Dictionary:
	clock -= delta
	if clock > 0.0:
		return cached
	clock = 0.12 if world.rules.difficulty == "normal" else world.rng.randf_range(0.18, 0.34)
	var target: HanabiFighter = null
	var distance: float = INF
	for opponent in world.fighters:
		if opponent == fighter or not opponent.alive:
			continue
		var current: float = fighter.position.distance_to(opponent.position)
		if current < distance:
			distance = current
			target = opponent
	if target == null:
		return {}
	var toward := (target.position - fighter.position).normalized()
	var movement := toward * (1.0 if distance > 245.0 else -1.0 if distance < 125.0 else 0.1) + toward.orthogonal() * 0.65 * direction
	var danger: bool = false
	for boom in world.boomerangs:
		if boom.owner_fighter != fighter and boom.position.distance_to(fighter.position) < 135.0:
			movement += (fighter.position - boom.position).normalized() * 2.0
			danger = true
	var blocked: bool = not world.combat.wall_contacts(fighter.position,target.position,world.rules.fighter_radius+1.0).is_empty()
	if blocked or not world.combat.wall_contacts(fighter.position,fighter.position+movement.normalized()*48.0,world.rules.fighter_radius+1.0).is_empty():
		movement = world.navigation.steering(fighter.position,target.position)
	var error: float = world.rng.randf_range(-0.21, 0.21) if world.rules.difficulty == "easy" else world.rng.randf_range(-0.075, 0.075)
	cached = {"move": movement.normalized(), "aim": toward.rotated(error), "throw": not is_instance_valid(fighter.active_boom) and distance < 450.0 and world.rng.randf() < 0.38, "dash": danger and world.rng.randf() < (0.15 if world.rules.difficulty == "easy" else 0.55), "slash": distance < 58.0 and world.rng.randf() < 0.7, "run": distance > 260.0 and not danger}
	if fighter.character_id == 0:
		cached.throw = distance < float(world.combat.weapon(0).range)+70.0 and not world.combat.line_blocked(fighter.position,target.position)
		cached.move = movement.normalized() if blocked else (toward+movement*0.35).normalized() if distance > 170.0 else movement.normalized()
	return cached
