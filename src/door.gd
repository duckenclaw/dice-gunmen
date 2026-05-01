extends StaticBody2D
class_name Door

const GRID_SIZE = 60

var health: int = 1

# State: rotation offset from closed position, in {-90, 0, 90}.
var rotation_state: int = 0

# Derived from position at _ready.
var cell_a: Vector2i  # cell on one side of the edge
var cell_b: Vector2i  # cell on the other side
var closed_rotation_deg: float = 0.0
var axis_vertical: bool = false  # true = vertical edge (blocks E-W); false = horizontal edge (blocks N-S)

func _ready():
	add_to_group("door")
	_compute_edge_from_position()
	_snap_initial_state()

func _compute_edge_from_position():
	var fx = fposmod(position.x, GRID_SIZE)
	var fy = fposmod(position.y, GRID_SIZE)
	var x_half = abs(fx - GRID_SIZE / 2.0) < 1.0
	var y_half = abs(fy - GRID_SIZE / 2.0) < 1.0

	if x_half and not y_half:
		axis_vertical = true
		var cy = int(round(position.y / GRID_SIZE))
		var cx_left = int(floor(position.x / GRID_SIZE))
		cell_a = Vector2i(cx_left, cy)
		cell_b = Vector2i(cx_left + 1, cy)
		closed_rotation_deg = 90.0
	elif y_half and not x_half:
		axis_vertical = false
		var cx = int(round(position.x / GRID_SIZE))
		var cy_top = int(floor(position.y / GRID_SIZE))
		cell_a = Vector2i(cx, cy_top)
		cell_b = Vector2i(cx, cy_top + 1)
		closed_rotation_deg = 0.0
	else:
		push_error("Door at %s is not on an edge midpoint (x or y must be a half-cell offset)" % position)

func _snap_initial_state():
	var r = rotation_degrees - closed_rotation_deg
	r = fposmod(r + 180.0, 360.0) - 180.0
	r = clamp(r, -90.0, 90.0)
	rotation_state = int(round(r / 90.0)) * 90
	rotation_degrees = closed_rotation_deg + rotation_state

func spans(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return (from_cell == cell_a and to_cell == cell_b) or (from_cell == cell_b and to_cell == cell_a)

func try_pass(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	# +90 when moving from cell_a to cell_b, -90 the other way.
	var delta = 90 if to_cell == cell_b else -90
	var new_state = rotation_state + delta

	if new_state < -90 or new_state > 90:
		return false

	rotation_state = new_state
	rotation_degrees = closed_rotation_deg + rotation_state
	return true

func take_damage(amount: int):
	health -= amount
	print("Door took %d damage. Health: %d" % [amount, health])
	if health <= 0:
		queue_free()
