
extends CharacterBody2D

enum PlayerState {
	IDLE,
	AIMING
}

signal action_performed
signal died

const GRID_SIZE = 60
const MOVE_SPEED = 300.0

@export var player_sprite: Texture2D

var state: PlayerState = PlayerState.IDLE
var is_controllable: bool = false
var health: int = 1
var current_aim_direction: Vector2 = Vector2.RIGHT

@onready var raycast: RayCast2D = $RayCast2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_layer: TileMapLayer = get_tree().get_first_node_in_group("floor_layer")
@onready var obstacle_layer: TileMapLayer = get_tree().get_first_node_in_group("obstacle_layer")

func _ready():
	# Apply player sprite if set
	if player_sprite:
		sprite.texture = player_sprite

	# Snap to grid on start
	position = _snap_to_grid(position)

	# Hide raycast initially
	raycast.enabled = false

	# Set initial raycast direction
	_update_raycast_direction(Vector2.RIGHT)

func _physics_process(_delta):
	if not is_controllable or health <= 0:
		return

	if state == PlayerState.IDLE:
		_handle_idle_state()
	elif state == PlayerState.AIMING:
		_handle_aiming_state()

func _handle_idle_state():
	# Check for shoot button to enter aiming mode
	if Input.is_action_just_pressed("shoot"):
		_enter_aiming_state()
		return

	# Handle movement
	var direction = Vector2.ZERO

	if Input.is_action_just_pressed("right"):
		direction = Vector2.RIGHT
	elif Input.is_action_just_pressed("left"):
		direction = Vector2.LEFT
	elif Input.is_action_just_pressed("up"):
		direction = Vector2.UP
	elif Input.is_action_just_pressed("down"):
		direction = Vector2.DOWN

	if direction != Vector2.ZERO:
		_try_move(direction)

func _handle_aiming_state():
	# Check for shoot button to fire
	if Input.is_action_just_pressed("shoot"):
		_fire_weapon()
		return

	# Handle aim direction changes
	var new_direction = Vector2.ZERO

	if Input.is_action_just_pressed("right"):
		new_direction = Vector2.RIGHT
	elif Input.is_action_just_pressed("left"):
		new_direction = Vector2.LEFT
	elif Input.is_action_just_pressed("up"):
		new_direction = Vector2.UP
	elif Input.is_action_just_pressed("down"):
		new_direction = Vector2.DOWN

	if new_direction != Vector2.ZERO:
		_update_raycast_direction(new_direction)

func _try_move(direction: Vector2):
	var target_pos = _snap_to_grid(position + direction * GRID_SIZE)
	var current_cell = _world_to_cell(position)
	var target_cell = _world_to_cell(target_pos)
	var dir_int = Vector2i(int(round(direction.x)), int(round(direction.y)))

	var door = _door_between(current_cell, target_cell)
	if door and not door.try_pass(current_cell, target_cell):
		print("Door blocked")
		return

	var box = _box_at(target_cell)
	if box and not box.try_push(dir_int):
		print("Box push blocked")
		return

	if not _is_cell_walkable(target_pos):
		print("Move blocked")
		return

	position = target_pos
	print("Player moved to: ", position)

	action_performed.emit()

func _is_cell_walkable(world_pos: Vector2) -> bool:
	if floor_layer == null or obstacle_layer == null:
		return true

	var floor_cell = floor_layer.local_to_map(floor_layer.to_local(world_pos))
	var obstacle_cell = obstacle_layer.local_to_map(obstacle_layer.to_local(world_pos))

	var on_floor = floor_layer.get_cell_source_id(floor_cell) != -1
	var blocked = obstacle_layer.get_cell_source_id(obstacle_cell) != -1

	return on_floor and not blocked

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(round(world_pos.x / GRID_SIZE)), int(round(world_pos.y / GRID_SIZE)))

func _door_between(a: Vector2i, b: Vector2i) -> Node:
	for door in get_tree().get_nodes_in_group("door"):
		if door.spans(a, b):
			return door
	return null

func _box_at(target_cell: Vector2i) -> Node:
	for box in get_tree().get_nodes_in_group("box"):
		if box.cell() == target_cell:
			return box
	return null

func _enter_aiming_state():
	state = PlayerState.AIMING
	raycast.enabled = true
	print("Entered aiming state")

	# Note: Entering aim doesn't cost AP, only firing does

func _update_raycast_direction(direction: Vector2):
	current_aim_direction = direction

	# Update raycast target position based on direction
	# Scale to reasonable distance (1000 pixels)
	raycast.target_position = direction * 1000

	print("Aiming direction: ", direction)

func _fire_weapon():
	print("Firing weapon!")

	# Force raycast update
	raycast.force_raycast_update()

	# Check if raycast hit something
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		print("Hit: ", collider.name)

		if collider != self and collider.has_method("take_damage"):
			collider.take_damage(1)
	else:
		print("Missed!")

	# Exit aiming state
	_exit_aiming_state()

	# Emit action performed signal
	action_performed.emit()

func _exit_aiming_state():
	state = PlayerState.IDLE
	raycast.enabled = false
	print("Exited aiming state")

func take_damage(amount: int):
	health -= amount
	print("Player took %d damage. Health: %d" % [amount, health])

	if health <= 0:
		_die()

func _die():
	print("Player died!")
	died.emit(self)
	# Optionally hide or disable the player
	visible = false

func set_controllable(controllable: bool):
	is_controllable = controllable

	if not controllable and state == PlayerState.AIMING:
		_exit_aiming_state()

	print("Player controllable: ", controllable)

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE
	)
