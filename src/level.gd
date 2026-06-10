extends Node2D

enum GameState {
	INITIAL_ROLL,
	TURN_INTERMISSION,
	TURN_ACTIVE,
	GAME_OVER
}

const INTERMISSION_DURATION = 1.5  # seconds
const GRID_SIZE = 60

const AP_NORMAL_COLOR = Color(1, 1, 1)
const AP_BONUS_COLOR = Color(1, 0.85, 0.2)
const AP_DISABLED_COLOR = Color(1, 0.25, 0.25)
const MAX_AP_ICONS = 8  # d6 max roll + 2 bonus

var game_state: GameState = GameState.INITIAL_ROLL
var current_player_index: int = 0
var action_points: int = 0
var players: Array = []
var intermission_timer: float = 0.0

# Pending AP modifiers from special cells, consumed on the player's next roll
var pending_bonus: Array[int] = [0, 0]
var pending_penalty: Array[int] = [0, 0]
# This turn's roll breakdown, kept for the AP display
var turn_base_ap: int = 0
var turn_bonus: int = 0
var turn_penalty: int = 0

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

	# Resolve hazards first: grenades explode at the start of the thrower's
	# turn, molotov fire burns out then too
	for hazard in get_tree().get_nodes_in_group("hazard"):
		hazard.on_turn_started(players[current_player_index])
	if game_state == GameState.GAME_OVER:
		return

	# Roll D6 for action points, then apply special-cell modifiers banked
	# at the end of previous turns
	turn_base_ap = randi() % 6 + 1
	turn_bonus = pending_bonus[current_player_index]
	turn_penalty = pending_penalty[current_player_index]
	pending_bonus[current_player_index] = 0
	pending_penalty[current_player_index] = 0
	action_points = max(turn_base_ap + turn_bonus - turn_penalty, 0)
	print("Player %d's turn! Rolled %d AP (+%d bonus, -%d penalty)" % [current_player_index + 1, turn_base_ap, turn_bonus, turn_penalty])

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
	_update_ap_display(current_stats)

	# A drained roll can leave the player with nothing to do
	if action_points <= 0:
		print("Player %d has no AP, skipping turn" % (current_player_index + 1))
		_end_turn()
		return

	# Give control to current player
	game_state = GameState.TURN_ACTIVE
	players[current_player_index].set_controllable(true)

func _on_player_action_performed():
	# Deduct action point
	action_points -= 1
	print("Action performed. AP remaining: %d" % action_points)

	# Update AP display for current player
	var current_stats = player1_stats if current_player_index == 0 else player2_stats
	_update_ap_display(current_stats)

	# Check if turn is over
	if action_points <= 0:
		_end_turn()

func _end_turn():
	if game_state == GameState.GAME_OVER:
		return

	# Remove control from current player
	players[current_player_index].set_controllable(false)

	# Ending the turn on a special cell banks an AP modifier for a next turn
	_apply_special_cells()

	# Switch to next player
	current_player_index = (current_player_index + 1) % players.size()

	# Start next turn
	_start_turn()

func _apply_special_cells():
	var player = players[current_player_index]
	if player.health <= 0:
		return

	var pcell = Vector2i(int(round(player.position.x / GRID_SIZE)), int(round(player.position.y / GRID_SIZE)))
	var opponent_index = (current_player_index + 1) % players.size()

	for special_cell in get_tree().get_nodes_in_group("special_cell"):
		if special_cell.cell() != pcell:
			continue
		if special_cell.effect == special_cell.Effect.AP_BONUS:
			pending_bonus[current_player_index] += 2
			print("Player %d ends on a bonus cell: +2 AP next turn" % (current_player_index + 1))
		else:
			pending_penalty[opponent_index] += 1
			print("Player %d ends on a drain cell: opponent -1 AP next turn" % (current_player_index + 1))

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

func _update_ap_display(stats_control: Control):
	var ap_container = stats_control.get_node("VBoxContainer/ActionPoints")
	ap_container.visible = true

	# Icon layout for the turn: [normal AP][bonus AP, yellow][drained AP, red].
	# Spending AP hides icons from the right; drained icons stay visible all
	# turn as a reminder of what was lost.
	var normal_total = max(turn_base_ap - turn_penalty, 0)
	var active_total = normal_total + turn_bonus
	var red_total = turn_penalty

	for i in range(1, MAX_AP_ICONS + 1):
		var ap_node = ap_container.get_node_or_null("ActionPoint%d" % i)
		if ap_node == null:
			continue
		if i <= action_points:
			ap_node.visible = true
			ap_node.modulate = AP_NORMAL_COLOR if i <= normal_total else AP_BONUS_COLOR
		elif i > active_total and i <= active_total + red_total:
			ap_node.visible = true
			ap_node.modulate = AP_DISABLED_COLOR
		else:
			ap_node.visible = false
