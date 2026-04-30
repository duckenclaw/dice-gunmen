extends Node2D

enum GameState {
	INITIAL_ROLL,
	TURN_INTERMISSION,
	TURN_ACTIVE,
	GAME_OVER
}

const INTERMISSION_DURATION = 1.5  # seconds

var game_state: GameState = GameState.INITIAL_ROLL
var current_player_index: int = 0
var action_points: int = 0
var players: Array = []
var intermission_timer: float = 0.0

@onready var turn_label: Label = $CanvasLayer/UI/TurnLabel
@onready var player1_stats: Control = $CanvasLayer/UI/Player1Stats
@onready var player2_stats: Control = $CanvasLayer/UI/Player2Stats

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

	# Hide AP displays initially
	player1_stats.get_node("VBoxContainer/ActionPoints").visible = false
	player2_stats.get_node("VBoxContainer/ActionPoints").visible = false

	# Start with initial contested roll
	_do_initial_roll()

func _process(delta):
	if game_state == GameState.TURN_INTERMISSION:
		intermission_timer -= delta
		if intermission_timer <= 0:
			_activate_turn()

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

	# Roll D6 for action points
	action_points = randi() % 6 + 1
	print("Player %d's turn! Rolled %d AP" % [current_player_index + 1, action_points])

	# Start intermission
	game_state = GameState.TURN_INTERMISSION
	intermission_timer = INTERMISSION_DURATION

	# Show turn label
	turn_label.text = "PLAYER %d TURN" % (current_player_index + 1)
	turn_label.visible = true

	# Hide both AP displays
	player1_stats.get_node("VBoxContainer/ActionPoints").visible = false
	player2_stats.get_node("VBoxContainer/ActionPoints").visible = false

func _activate_turn():
	# Hide turn label
	turn_label.visible = false

	# Show and update AP display for current player
	var current_stats = player1_stats if current_player_index == 0 else player2_stats
	_update_ap_display(current_stats, action_points)

	# Give control to current player
	game_state = GameState.TURN_ACTIVE
	players[current_player_index].set_controllable(true)

func _on_player_action_performed():
	# Deduct action point
	action_points -= 1
	print("Action performed. AP remaining: %d" % action_points)

	# Update AP display for current player
	var current_stats = player1_stats if current_player_index == 0 else player2_stats
	_update_ap_display(current_stats, action_points)

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

func _update_ap_display(stats_control: Control, ap_count: int):
	var ap_container = stats_control.get_node("VBoxContainer/ActionPoints")
	ap_container.visible = true

	# Get all AP texture rects
	for i in range(1, 7):
		var ap_node = ap_container.get_node("ActionPoint%d" % i)
		ap_node.visible = (i <= ap_count)
