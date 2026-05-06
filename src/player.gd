
extends CharacterBody2D

enum PlayerState {
	IDLE,
	AIMING
}

enum Weapon {
	NONE,
	PISTOL,
	SNIPER,
	RPG
}

signal action_performed
signal died

const GRID_SIZE = 60
const MOVE_SPEED = 300.0
const SHOT_RANGE_CELLS = 30
const RPG_AOE_RADIUS = 1  # 1 = 3x3 cells centered on hit

@export var player_sprite: Texture2D

var state: PlayerState = PlayerState.IDLE
var is_controllable: bool = false
var health: int = 1
var current_aim_direction: Vector2 = Vector2.RIGHT
var current_weapon: Weapon = Weapon.NONE
var current_ammo: int = 0

@onready var raycast: RayCast2D = $RayCast2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_layer: TileMapLayer = get_tree().get_first_node_in_group("floor_layer")
@onready var obstacle_layer: TileMapLayer = get_tree().get_first_node_in_group("obstacle_layer")

func _ready():
	if player_sprite:
		sprite.texture = player_sprite

	position = _snap_to_grid(position)
	raycast.enabled = false
	_update_raycast_direction(Vector2.RIGHT)

func _physics_process(_delta):
	if not is_controllable or health <= 0:
		return

	if state == PlayerState.IDLE:
		_handle_idle_state()
	elif state == PlayerState.AIMING:
		_handle_aiming_state()

func _handle_idle_state():
	if Input.is_action_just_pressed("pickup"):
		_try_pickup()
		return

	if Input.is_action_just_pressed("shoot"):
		if current_weapon == Weapon.NONE or current_ammo <= 0:
			print("No weapon equipped")
			return
		_enter_aiming_state()
		return

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
	if Input.is_action_just_pressed("shoot"):
		_fire_weapon()
		return

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

func _try_pickup():
	# Use physics overlap so any weapon Area2D touching the player's body counts
	var pickup: Node = null
	for area in $PickupDetector.get_overlapping_areas():
		if area.is_in_group("weapon"):
			pickup = area
			break

	if pickup == null:
		print("No pickup here")
		return

	if pickup.try_pickup(self):
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
	print("Entered aiming state with ", _weapon_label(), " (", current_ammo, " ammo)")

func _update_raycast_direction(direction: Vector2):
	current_aim_direction = direction
	raycast.target_position = direction * 1000
	print("Aiming direction: ", direction)

func _fire_weapon():
	print("Firing ", _weapon_label())

	match current_weapon:
		Weapon.PISTOL:
			_fire_pistol()
		Weapon.SNIPER:
			_fire_sniper()
		Weapon.RPG:
			_fire_rpg()
		_:
			print("No weapon to fire")
			_exit_aiming_state()
			return

	current_ammo -= 1
	if current_ammo <= 0:
		print("Out of ammo, dropping ", _weapon_label())
		current_weapon = Weapon.NONE
		current_ammo = 0

	_exit_aiming_state()
	action_performed.emit()

func _fire_pistol():
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		print("Pistol hit: ", collider.name)
		if collider != self and collider.has_method("take_damage"):
			collider.take_damage(1)
	else:
		print("Pistol missed")

func _fire_sniper():
	var space_state = get_world_2d().direct_space_state
	var origin = position + Vector2(0, -60)  # match raycast offset (raycast is at y=-60)
	var end = origin + current_aim_direction * GRID_SIZE * SHOT_RANGE_CELLS

	var exclude: Array[RID] = []
	# Exclude self so we don't immediately hit our own collider
	exclude.append(get_rid())

	var passes = 0
	var max_passes = 32  # safety cap
	while passes < max_passes:
		passes += 1
		var query = PhysicsRayQueryParameters2D.create(origin, end)
		query.exclude = exclude
		query.collide_with_bodies = true
		var result = space_state.intersect_ray(query)

		if result.is_empty():
			print("Sniper end of range")
			return

		var collider = result.collider
		var pierces = collider.is_in_group("box") or collider.is_in_group("door")

		if collider.has_method("take_damage"):
			print("Sniper hit: ", collider.name)
			collider.take_damage(1)
		else:
			print("Sniper hit non-damageable: ", collider.name)

		if not pierces:
			return

		# Continue past doors/boxes by excluding them from the next query
		exclude.append(result.rid)

func _fire_rpg():
	raycast.force_raycast_update()

	var explosion_world: Vector2
	if raycast.is_colliding():
		explosion_world = raycast.get_collision_point()
	else:
		# No hit — explode at max range
		explosion_world = (position + Vector2(0, -60)) + current_aim_direction * GRID_SIZE * SHOT_RANGE_CELLS

	var center_cell = Vector2i(
		int(round(explosion_world.x / GRID_SIZE)),
		int(round(explosion_world.y / GRID_SIZE))
	)

	print("RPG explosion at cell: ", center_cell)

	var aoe_cells: Array[Vector2i] = []
	for dx in range(-RPG_AOE_RADIUS, RPG_AOE_RADIUS + 1):
		for dy in range(-RPG_AOE_RADIUS, RPG_AOE_RADIUS + 1):
			aoe_cells.append(center_cell + Vector2i(dx, dy))

	# Damage boxes in AOE
	for box in get_tree().get_nodes_in_group("box"):
		if box.cell() in aoe_cells:
			print("RPG damaging box at ", box.cell())
			box.take_damage(1)

	# Damage doors whose either spanned cell is in AOE
	for door in get_tree().get_nodes_in_group("door"):
		if door.cell_a in aoe_cells or door.cell_b in aoe_cells:
			print("RPG damaging door spanning ", door.cell_a, "-", door.cell_b)
			door.take_damage(1)

	# Damage players (including self) in AOE
	for player in get_tree().get_nodes_in_group("player"):
		var pcell = Vector2i(int(round(player.position.x / GRID_SIZE)), int(round(player.position.y / GRID_SIZE)))
		if pcell in aoe_cells:
			print("RPG damaging player at ", pcell)
			if player.has_method("take_damage"):
				player.take_damage(1)

func _exit_aiming_state():
	state = PlayerState.IDLE
	raycast.enabled = false
	print("Exited aiming state")

func equip_weapon(weapon_type: int, ammo: int):
	# weapon_type comes in as WeaponPickup.WeaponType ordinal; map to local Weapon enum
	match weapon_type:
		0: current_weapon = Weapon.PISTOL
		1: current_weapon = Weapon.SNIPER
		2: current_weapon = Weapon.RPG
		_: current_weapon = Weapon.NONE
	current_ammo = ammo
	print("Equipped ", _weapon_label(), " with ", current_ammo, " ammo")

func _weapon_label() -> String:
	match current_weapon:
		Weapon.NONE: return "None"
		Weapon.PISTOL: return "Pistol"
		Weapon.SNIPER: return "Sniper Rifle"
		Weapon.RPG: return "RPG"
	return "Unknown"

func take_damage(amount: int):
	health -= amount
	print("Player took %d damage. Health: %d" % [amount, health])

	if health <= 0:
		_die()

func _die():
	print("Player died!")
	died.emit(self)
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
