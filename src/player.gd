extends CharacterBody2D

enum PlayerState {
	IDLE,
	AIMING
}

signal action_performed
signal died

const GRID_SIZE = 60
const MOVE_SPEED = 300.0

var state: PlayerState = PlayerState.IDLE
var is_controllable: bool = false
var health: int = 1
var current_aim_direction: Vector2 = Vector2.RIGHT

@onready var raycast: RayCast2D = $RayCast2D

func _ready():
	# Snap to grid on start
	position = _snap_to_grid(position)

	# Hide raycast initially
	raycast.enabled = false

	# Set initial raycast direction
	_update_raycast_direction(Vector2.RIGHT)

func _physics_process(delta):
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
	# Calculate target grid position
	var target_pos = position + direction * GRID_SIZE

	# Check if target position is valid (not occupied)
	# For now, we'll just move (collision detection handled by CharacterBody2D)
	var previous_position = position
	position = target_pos

	# Snap to grid
	position = _snap_to_grid(position)

	print("Player moved to: ", position)

	# Emit action performed signal
	action_performed.emit()

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

		# Check if we hit another player
		if collider is CharacterBody2D and collider != self:
			print("Hit a player!")
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
