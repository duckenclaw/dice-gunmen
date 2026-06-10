extends Node2D

# A lingering area effect left behind by a thrown weapon. Lives in the
# "hazard" group; the level calls on_turn_started(player) at every turn start.
#
# MOLOTOV_FIRE: cells are deadly to any player that walks onto them; the fire
# burns out at the start of the thrower's next turn.
# GRENADE: inert until the start of the thrower's next turn, then explodes and
# damages everything (players, boxes, doors) on its cells.

enum HazardType {
	MOLOTOV_FIRE,
	GRENADE
}

const GRID_SIZE = 60

const FIRE_COLOR = Color(1.0, 0.5, 0.1, 0.5)
const GRENADE_COLOR = Color(0.4, 0.45, 0.4, 0.35)
const ICON_PX = 40.0

var type: HazardType = HazardType.MOLOTOV_FIRE
var cells: Array[Vector2i] = []
var thrower: Node = null
var icon: Texture2D = null

static func spawn(parent: Node, hazard_type: int, hazard_cells: Array[Vector2i], hazard_thrower: Node, hazard_icon: Texture2D) -> Node:
	var h = load("res://src/hazard.gd").new()
	h.type = hazard_type
	h.cells = hazard_cells
	h.thrower = hazard_thrower
	h.icon = hazard_icon
	parent.add_child(h)
	return h

func _ready():
	add_to_group("hazard")
	queue_redraw()

func is_deadly_cell(cell: Vector2i) -> bool:
	return type == HazardType.MOLOTOV_FIRE and cell in cells

func on_turn_started(player: Node):
	if player != thrower:
		return

	match type:
		HazardType.MOLOTOV_FIRE:
			print("Molotov fire burned out")
			queue_free()
		HazardType.GRENADE:
			_explode()
			queue_free()

func _explode():
	print("Grenade exploding on cells: ", cells)

	for box in get_tree().get_nodes_in_group("box"):
		if box.cell() in cells:
			box.take_damage(1)

	for door in get_tree().get_nodes_in_group("door"):
		if door.cell_a in cells or door.cell_b in cells:
			door.take_damage(1)

	for player in get_tree().get_nodes_in_group("player"):
		var pcell = Vector2i(int(round(player.position.x / GRID_SIZE)), int(round(player.position.y / GRID_SIZE)))
		if pcell in cells and player.has_method("take_damage"):
			player.take_damage(1)

func _draw():
	var color = FIRE_COLOR if type == HazardType.MOLOTOV_FIRE else GRENADE_COLOR
	var half = GRID_SIZE / 2.0

	for cell in cells:
		var rect = Rect2(Vector2(cell) * GRID_SIZE - Vector2(half, half), Vector2(GRID_SIZE, GRID_SIZE))
		if type == HazardType.MOLOTOV_FIRE:
			draw_rect(rect, color, true)
		else:
			draw_rect(rect, color, false, 2.0)

	if icon and not cells.is_empty():
		# Center icon on the middle cell (cells[0] is the throw target)
		var size = icon.get_size()
		var longest = max(size.x, size.y)
		if longest > 0:
			var s = ICON_PX / longest
			var draw_size = size * s
			var center = Vector2(cells[0]) * GRID_SIZE
			draw_texture_rect(icon, Rect2(center - draw_size / 2.0, draw_size), false)
