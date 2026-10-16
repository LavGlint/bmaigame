extends RefCounted
class_name HanabiArenaNavigation

var grid := AStarGrid2D.new()
var world: HanabiArenaWorld
var step_size := 16.0
var clearance := 18.0
var free: Dictionary = {}

func configure(arena: HanabiArenaWorld) -> void:
	world = arena
	clearance = world.rules.fighter_radius+2.0
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(ceili(world.field.size.x/step_size),ceili(world.field.size.y/step_size)))
	grid.cell_size = Vector2.ONE*step_size
	grid.offset = world.field.position+Vector2.ONE*step_size*0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	free.clear()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x,y)
			var at := grid.get_point_position(cell)
			var open := world.field.grow(-clearance).has_point(at) and HanabiMapGeometry.circle_clear(at,clearance,world.collision_shapes)
			grid.set_point_solid(cell,not open)
			if open: free[cell] = true

func nearest(at: Vector2) -> Vector2i:
	var cell := Vector2i(floori((at.x-world.field.position.x)/step_size),floori((at.y-world.field.position.y)/step_size))
	if free.has(cell): return cell
	var best := Vector2i(-1,-1)
	var distance := INF
	for ring in range(1,7):
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				if abs(x) != ring and abs(y) != ring: continue
				var candidate := cell+Vector2i(x,y)
				if not free.has(candidate): continue
				var point := grid.get_point_position(candidate)
				var current := at.distance_squared_to(point)
				if current < distance and world.combat.wall_contacts(at,point,world.rules.fighter_radius).is_empty(): best = candidate; distance = current
		if best.x >= 0: break
	return best

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := nearest(from); var finish := nearest(to)
	if start.x < 0 or finish.x < 0: return PackedVector2Array()
	return grid.get_point_path(start,finish)

func steering(from: Vector2, to: Vector2) -> Vector2:
	if world.combat.wall_contacts(from,to,world.rules.fighter_radius+1.0).is_empty(): return (to-from).normalized()
	var points := path(from,to)
	# Look ahead only along segments proven clear against the true polygons.
	var destination := from
	for point in points:
		if from.distance_to(point) < 5.0: continue
		if not world.combat.wall_contacts(from,point,world.rules.fighter_radius+0.5).is_empty(): break
		destination = point
	return (destination-from).normalized()
