
extends CharacterBody2D

enum PlayerState {
	IDLE,
	AIMING
}

enum Weapon {
	NONE,
	PISTOL,
	SNIPER,
	RPG,
	MOLOTOV,
	GRENADE
}

const Projectile = preload("res://src/projectile.gd")
const Hazard = preload("res://src/hazard.gd")

signal action_performed
signal died

const GRID_SIZE = 60
const MOVE_SPEED = 300.0
const SHOT_RANGE_CELLS = 30

const SPRITE_BASE_Y = -60.0
const STEP_TILT_DEG = 12.0
const STEP_BOUNCE_PX = 12.0
const STEP_ANIM_TIME = 0.16
const WEAPON_SPRITE_PX = 50.0
const WEAPON_ORBIT_PX = 45.0

@export var player_sprite: Texture2D

@export var pistol_texture: Texture2D
@export var sniper_texture: Texture2D
@export var rpg_texture: Texture2D
@export var molotov_texture: Texture2D
@export var grenade_texture: Texture2D

@export var pistol_shot_sfx: AudioStream
@export var sniper_shot_sfx: AudioStream
@export var rpg_shot_sfx: AudioStream
@export var molotov_shot_sfx: AudioStream
@export var grenade_shot_sfx: AudioStream

@export var bullet_texture: Texture2D
@export var rocket_texture: Texture2D

var state: PlayerState = PlayerState.IDLE
var is_controllable: bool = false
var health: int = 1
var current_aim_direction: Vector2 = Vector2.RIGHT
var current_weapon: Weapon = Weapon.NONE
var current_ammo: int = 0
var step_tilt_sign: float = 1.0
var step_tween: Tween
var throw_cell: Vector2i = Vector2i.ZERO
var throw_dir: Vector2i = Vector2i.RIGHT

@onready var raycast: RayCast2D = $RayCast2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var step_sfx: AudioStreamPlayer = $StepSfx
@onready var ready_shot_sfx: AudioStreamPlayer = $ReadyShotSfx
@onready var shot_sfx: AudioStreamPlayer = $ShotSfx
@onready var pickup_sfx: AudioStreamPlayer = $PickupSfx
@onready var floor_layer: TileMapLayer = get_tree().get_first_node_in_group("floor_layer")
@onready var obstacle_layer: TileMapLayer = get_tree().get_first_node_in_group("obstacle_layer")
@onready var grid_overlay: Node2D = get_tree().get_first_node_in_group("grid_overlay")

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
		if _is_thrown_weapon():
			_adjust_throw_target(new_direction)
		else:
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

	step_sfx.play()
	_play_step_anim()

	for hazard in get_tree().get_nodes_in_group("hazard"):
		if hazard.is_deadly_cell(target_cell):
			print("Player walked into fire!")
			take_damage(999)
			break

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
		pickup_sfx.play()
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
	ready_shot_sfx.play()
	_reset_step_anim()

	if _is_thrown_weapon():
		throw_dir = Vector2i(int(round(current_aim_direction.x)), int(round(current_aim_direction.y)))
		var start = _world_to_cell(position) + throw_dir
		throw_cell = start if _is_cell_throwable(start) else _world_to_cell(position)

	_update_weapon_sprite()
	_update_aoe_preview()
	print("Entered aiming state with ", _weapon_label(), " (", current_ammo, " ammo)")

func _update_raycast_direction(direction: Vector2):
	current_aim_direction = direction
	raycast.target_position = direction * 1000
	_update_weapon_sprite()
	_update_aoe_preview()
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
		Weapon.MOLOTOV, Weapon.GRENADE:
			_throw_weapon()
		_:
			print("No weapon to fire")
			_exit_aiming_state()
			return

	var stream = _shot_sfx_for_weapon()
	if stream:
		shot_sfx.stream = stream
	shot_sfx.play()

	current_ammo -= 1
	if current_ammo <= 0:
		print("Out of ammo, dropping ", _weapon_label())
		current_weapon = Weapon.NONE
		current_ammo = 0

	_exit_aiming_state()
	action_performed.emit()

func _fire_pistol():
	raycast.force_raycast_update()
	var origin = position + Vector2(0, SPRITE_BASE_Y)
	var impact = origin + current_aim_direction * raycast.target_position.length()

	if raycast.is_colliding():
		impact = raycast.get_collision_point()
		var collider = raycast.get_collider()
		print("Pistol hit: ", collider.name)
		if collider != self and collider.has_method("take_damage"):
			collider.take_damage(1)
	else:
		print("Pistol missed")

	Projectile.spawn(get_parent(), bullet_texture, origin, impact)

func _fire_sniper():
	var space_state = get_world_2d().direct_space_state
	var origin = position + Vector2(0, -60)  # match raycast offset (raycast is at y=-60)
	var end = origin + current_aim_direction * GRID_SIZE * SHOT_RANGE_CELLS

	var exclude: Array[RID] = []
	# Exclude self so we don't immediately hit our own collider
	exclude.append(get_rid())

	var impact = end
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
			break

		var collider = result.collider
		var pierces = collider.is_in_group("box") or collider.is_in_group("door")

		if collider.has_method("take_damage"):
			print("Sniper hit: ", collider.name)
			collider.take_damage(1)
		else:
			print("Sniper hit non-damageable: ", collider.name)

		if not pierces:
			impact = result.position
			break

		# Continue past doors/boxes by excluding them from the next query
		exclude.append(result.rid)

	Projectile.spawn(get_parent(), bullet_texture, origin, impact)

func _fire_rpg():
	var origin = position + Vector2(0, SPRITE_BASE_Y)
	var impact = _rpg_explosion_point()
	var aoe_cells = _cells_cross(_world_to_cell(impact))
	print("RPG explosion cells: ", aoe_cells)

	Projectile.spawn(get_parent(), rocket_texture, origin, impact)

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
	_update_weapon_sprite()
	_update_aoe_preview()
	print("Exited aiming state")

func equip_weapon(weapon_type: int, ammo: int):
	# weapon_type comes in as WeaponPickup.WeaponType ordinal; map to local Weapon enum
	match weapon_type:
		0: current_weapon = Weapon.PISTOL
		1: current_weapon = Weapon.SNIPER
		2: current_weapon = Weapon.RPG
		3: current_weapon = Weapon.MOLOTOV
		4: current_weapon = Weapon.GRENADE
		_: current_weapon = Weapon.NONE
	current_ammo = ammo
	_update_weapon_sprite()
	print("Equipped ", _weapon_label(), " with ", current_ammo, " ammo")

func _weapon_label() -> String:
	match current_weapon:
		Weapon.NONE: return "None"
		Weapon.PISTOL: return "Pistol"
		Weapon.SNIPER: return "Sniper Rifle"
		Weapon.RPG: return "RPG"
		Weapon.MOLOTOV: return "Molotov"
		Weapon.GRENADE: return "Grenade"
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

	if not controllable:
		_reset_step_anim()

	print("Player controllable: ", controllable)

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE
	)

func _rpg_explosion_point() -> Vector2:
	raycast.force_raycast_update()
	if raycast.is_colliding():
		return raycast.get_collision_point()
	# No hit — explode at max range
	return (position + Vector2(0, SPRITE_BASE_Y)) + current_aim_direction * GRID_SIZE * SHOT_RANGE_CELLS

# 5-cell cross: center + 4 orthogonal neighbors; center stays first so
# callers can treat cells[0] as the impact cell.
func _cells_cross(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [
		center,
		center + Vector2i.RIGHT,
		center + Vector2i.LEFT,
		center + Vector2i.UP,
		center + Vector2i.DOWN
	]
	return cells

func _update_aoe_preview():
	if grid_overlay == null:
		return

	if state != PlayerState.AIMING:
		grid_overlay.clear_aoe()
	elif _is_thrown_weapon():
		grid_overlay.show_aoe(_cells_cross(throw_cell))
	elif current_weapon == Weapon.RPG:
		grid_overlay.show_aoe(_cells_cross(_world_to_cell(_rpg_explosion_point())))
	else:
		grid_overlay.clear_aoe()

func _is_thrown_weapon() -> bool:
	return current_weapon == Weapon.MOLOTOV or current_weapon == Weapon.GRENADE

# A thrown weapon flies cell by cell in a straight line from the player;
# every cell on the way must be open floor with no obstacle or box.
func _is_cell_throwable(cell: Vector2i) -> bool:
	if not _is_cell_walkable(Vector2(cell) * GRID_SIZE):
		return false
	if _box_at(cell):
		return false
	return true

func _adjust_throw_target(direction: Vector2):
	var dir_int = Vector2i(int(round(direction.x)), int(round(direction.y)))
	current_aim_direction = direction

	# Same direction extends the line one cell; a new direction restarts the
	# line from the player.
	var candidate: Vector2i
	if dir_int == throw_dir:
		candidate = throw_cell + dir_int
	else:
		candidate = _world_to_cell(position) + dir_int

	if _is_cell_throwable(candidate):
		throw_dir = dir_int
		throw_cell = candidate
		print("Throw target cell: ", throw_cell)
	else:
		print("Throw blocked toward ", candidate)

	_update_weapon_sprite()
	_update_aoe_preview()

func _throw_weapon():
	var cells = _cells_cross(throw_cell)
	var icon = _weapon_texture()
	var origin = position + Vector2(0, SPRITE_BASE_Y)
	var target_world = Vector2(throw_cell) * GRID_SIZE

	Projectile.spawn_thrown(get_parent(), icon, origin, target_world)

	var hazard_parent = grid_overlay if grid_overlay else get_parent()
	var hazard_type = Hazard.HazardType.MOLOTOV_FIRE if current_weapon == Weapon.MOLOTOV else Hazard.HazardType.GRENADE
	Hazard.spawn(hazard_parent, hazard_type, cells, self, icon)
	print(_weapon_label(), " thrown at cell ", throw_cell)

	# Fire is immediately lethal to anyone standing in it (the grenade waits
	# for the start of the thrower's next turn instead)
	if current_weapon == Weapon.MOLOTOV:
		for player in get_tree().get_nodes_in_group("player"):
			if _world_to_cell(player.position) in cells and player.has_method("take_damage"):
				print("Molotov fire caught player at ", _world_to_cell(player.position))
				player.take_damage(999)

func _update_weapon_sprite():
	var tex = _weapon_texture()
	if tex == null:
		weapon_sprite.visible = false
		return

	weapon_sprite.visible = true
	weapon_sprite.texture = tex

	var size = tex.get_size()
	var longest = max(size.x, size.y)
	if longest > 0:
		var s = WEAPON_SPRITE_PX / longest
		weapon_sprite.scale = Vector2(s, s)

	if state == PlayerState.AIMING:
		# Orbit around the player in the aim direction, pointing away from
		# the sprite; flip vertically when aiming left so it isn't upside down.
		weapon_sprite.position = Vector2(0, SPRITE_BASE_Y) + current_aim_direction * WEAPON_ORBIT_PX
		weapon_sprite.rotation = current_aim_direction.angle()
		weapon_sprite.flip_v = current_aim_direction.x < 0
	else:
		weapon_sprite.position = Vector2(0, SPRITE_BASE_Y)
		weapon_sprite.rotation = 0.0
		weapon_sprite.flip_v = false

func _weapon_texture() -> Texture2D:
	match current_weapon:
		Weapon.PISTOL: return pistol_texture
		Weapon.SNIPER: return sniper_texture
		Weapon.RPG: return rpg_texture
		Weapon.MOLOTOV: return molotov_texture
		Weapon.GRENADE: return grenade_texture
	return null

func _shot_sfx_for_weapon() -> AudioStream:
	match current_weapon:
		Weapon.PISTOL: return pistol_shot_sfx
		Weapon.SNIPER: return sniper_shot_sfx
		Weapon.RPG: return rpg_shot_sfx
		Weapon.MOLOTOV: return molotov_shot_sfx
		Weapon.GRENADE: return grenade_shot_sfx
	return null

func _play_step_anim():
	step_tilt_sign *= -1.0
	if step_tween:
		step_tween.kill()
	step_tween = create_tween()
	step_tween.tween_property(sprite, "position:y", SPRITE_BASE_Y - STEP_BOUNCE_PX, STEP_ANIM_TIME * 0.5)
	step_tween.parallel().tween_property(sprite, "rotation_degrees", step_tilt_sign * STEP_TILT_DEG, STEP_ANIM_TIME * 0.5)
	step_tween.tween_property(sprite, "position:y", SPRITE_BASE_Y, STEP_ANIM_TIME * 0.5)

func _reset_step_anim():
	if step_tween:
		step_tween.kill()
	step_tween = create_tween()
	step_tween.tween_property(sprite, "rotation_degrees", 0.0, STEP_ANIM_TIME * 0.5)
	step_tween.parallel().tween_property(sprite, "position:y", SPRITE_BASE_Y, STEP_ANIM_TIME * 0.5)
