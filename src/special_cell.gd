extends Node2D

# A cell that modifies AP when a player ends their turn standing on it.
# Discovered by the level via the "special_cell" group.

enum Effect {
	AP_BONUS,   # +2 AP on your own next turn
	AP_DRAIN    # -1 AP on the opponent's next turn
}

const GRID_SIZE = 60

const BONUS_COLOR = Color(1.0, 0.85, 0.2, 0.4)
const DRAIN_COLOR = Color(1.0, 0.2, 0.2, 0.4)
const BORDER_WIDTH = 3.0

@export var effect: Effect = Effect.AP_BONUS

func _ready():
	add_to_group("special_cell")
	position = Vector2(
		round(position.x / GRID_SIZE) * GRID_SIZE,
		round(position.y / GRID_SIZE) * GRID_SIZE
	)
	queue_redraw()

func cell() -> Vector2i:
	return Vector2i(int(round(position.x / GRID_SIZE)), int(round(position.y / GRID_SIZE)))

func _draw():
	var color = BONUS_COLOR if effect == Effect.AP_BONUS else DRAIN_COLOR
	var half = GRID_SIZE / 2.0
	var rect = Rect2(Vector2(-half, -half), Vector2(GRID_SIZE, GRID_SIZE))
	draw_rect(rect, color, true)
	var border = Color(color.r, color.g, color.b, 0.9)
	draw_rect(rect, border, false, BORDER_WIDTH)
	# +/- marker
	var arm = GRID_SIZE * 0.18
	draw_line(Vector2(-arm, 0), Vector2(arm, 0), border, BORDER_WIDTH)
	if effect == Effect.AP_BONUS:
		draw_line(Vector2(0, -arm), Vector2(0, arm), border, BORDER_WIDTH)
