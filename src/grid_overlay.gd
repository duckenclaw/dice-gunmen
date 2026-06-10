extends Node2D

# Draws the 60-px player grid on top of the tilemap layers and can highlight
# arbitrary cells (e.g. an AoE attack preview). Discovered via the
# "grid_overlay" group, same pattern as the tile layers.

const GRID_SIZE = 60

const LINE_COLOR = Color(1.0, 1.0, 1.0, 0.12)
const LINE_WIDTH = 3.0
const AOE_COLOR = Color(1.0, 0.25, 0.15, 0.35)

var aoe_cells: Array[Vector2i] = []
var bounds: Rect2 = Rect2()

@onready var floor_layer: TileMapLayer = get_tree().get_first_node_in_group("floor_layer")

func _ready():
	add_to_group("grid_overlay")
	_compute_bounds()
	queue_redraw()

func show_aoe(cells: Array[Vector2i]):
	aoe_cells = cells
	queue_redraw()

func clear_aoe():
	if aoe_cells.is_empty():
		return
	aoe_cells = []
	queue_redraw()

func _compute_bounds():
	if floor_layer == null:
		return

	var used = floor_layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return

	var tile_size = Vector2(floor_layer.tile_set.tile_size)
	var top_left = to_local(floor_layer.to_global(Vector2(used.position) * tile_size))
	var bottom_right = to_local(floor_layer.to_global(Vector2(used.position + used.size) * tile_size))

	# Player-grid cells are centered on multiples of GRID_SIZE, so their
	# boundaries sit at GRID_SIZE * k + GRID_SIZE / 2. Expand the floor rect
	# outward to the nearest boundaries so lines fully cover the floor.
	var half = GRID_SIZE / 2.0
	var min_x = floor((top_left.x - half) / GRID_SIZE) * GRID_SIZE + half
	var min_y = floor((top_left.y - half) / GRID_SIZE) * GRID_SIZE + half
	var max_x = ceil((bottom_right.x - half) / GRID_SIZE) * GRID_SIZE + half
	var max_y = ceil((bottom_right.y - half) / GRID_SIZE) * GRID_SIZE + half

	bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _draw():
	if bounds.size == Vector2.ZERO:
		return

	var half = GRID_SIZE / 2.0
	for cell in aoe_cells:
		var rect = Rect2(Vector2(cell) * GRID_SIZE - Vector2(half, half), Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, AOE_COLOR, true)

	var x = bounds.position.x
	while x <= bounds.end.x:
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), LINE_COLOR, LINE_WIDTH)
		x += GRID_SIZE

	var y = bounds.position.y
	while y <= bounds.end.y:
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), LINE_COLOR, LINE_WIDTH)
		y += GRID_SIZE
