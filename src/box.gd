extends StaticBody2D
class_name Box

const GRID_SIZE = 60

var health: int = 1

func _ready():
	add_to_group("box")

func cell() -> Vector2i:
	return Vector2i(round(position.x / GRID_SIZE), round(position.y / GRID_SIZE))

func try_push(direction: Vector2i) -> bool:
	var from_cell = cell()
	var target_cell = from_cell + direction

	if not _can_enter(from_cell, target_cell, direction):
		return false

	position += Vector2(direction) * GRID_SIZE
	return true

func _can_enter(from_cell: Vector2i, target_cell: Vector2i, direction: Vector2i) -> bool:
	var floor_layer: TileMapLayer = get_tree().get_first_node_in_group("floor_layer")
	var obstacle_layer: TileMapLayer = get_tree().get_first_node_in_group("obstacle_layer")
	if floor_layer == null or obstacle_layer == null:
		return false

	var world_pos = Vector2(target_cell) * GRID_SIZE

	if floor_layer.get_cell_source_id(floor_layer.local_to_map(floor_layer.to_local(world_pos))) == -1:
		return false
	if obstacle_layer.get_cell_source_id(obstacle_layer.local_to_map(obstacle_layer.to_local(world_pos))) != -1:
		return false

	for door in get_tree().get_nodes_in_group("door"):
		if door.spans(from_cell, target_cell):
			return false

	for other in get_tree().get_nodes_in_group("box"):
		if other == self:
			continue
		if other.cell() == target_cell:
			return other.try_push(direction)

	return true

func take_damage(amount: int):
	health -= amount
	print("Box took %d damage. Health: %d" % [amount, health])
	if health <= 0:
		queue_free()
