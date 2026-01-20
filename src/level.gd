extends Node2D

enum GameState {
	INITIAL_ROLL,
	TURN_ACTIVE,
	GAME_OVER
}

var game_state: GameState = GameState.INITIAL_ROLL
var current_player_index: int = 0
var action_points: int = 0
var players: Array = []

func _ready():
	# Get player references
	players = [
		get_node("Player1"),
		get_node("Player2")
	]

	# Connect player signals
	for player in players:
		player.action_performed.connect(_on_player_action_performed)
		player.died.connect(_on_player_died)
		player.set_controllable(false)

	# Start with initial contested roll
	_do_initial_roll()

func _do_initial_roll():
	game_state = GameState.INITIAL_ROLL

	# Roll D6 for both players
	var roll1 = randi() % 6 + 1
	var roll2 = randi() % 6 + 1

	print("Initial contested roll: Player 1 rolled %d, Player 2 rolled %d" % [roll1, roll2])

	# Determine who goes first
	if roll1 > roll2:
		current_player_index = 0
		print("Player 1 goes first!")
	elif roll2 > roll1:
		current_player_index = 1
		print("Player 2 goes first!")
	else:
		# Tie, reroll
		print("Tie! Rolling again...")
		_do_initial_roll()
		return

	# Start first turn
	_start_turn()

func _start_turn():
	if game_state == GameState.GAME_OVER:
		return

	game_state = GameState.TURN_ACTIVE

	# Roll D6 for action points
	action_points = randi() % 6 + 1

	var current_player = players[current_player_index]
	print("Player %d's turn! Rolled %d AP" % [current_player_index + 1, action_points])

	# Give control to current player
	current_player.set_controllable(true)

func _on_player_action_performed():
	# Deduct action point
	action_points -= 1
	print("Action performed. AP remaining: %d" % action_points)

	# Check if turn is over
	if action_points <= 0:
		_end_turn()

func _end_turn():
	# Remove control from current player
	players[current_player_index].set_controllable(false)

	# Switch to next player
	current_player_index = (current_player_index + 1) % players.size()

	# Start next turn
	_start_turn()

func _on_player_died(player):
	print("A player has died!")
	game_state = GameState.GAME_OVER

	# Remove dead player from controllable state
	player.set_controllable(false)

	# Determine winner
	for i in range(players.size()):
		if players[i] != player:
			print("Player %d wins!" % (i + 1))
			players[i].set_controllable(false)
			break

	print("Game Over!")
