# dice-gunmen

A turn-based 2D top-down PvP shooter built in Godot 4.6. Two gunslingers face off on a grid; a D6 roll each turn decides how many actions you get. Walls, pushable boxes, and swinging doors make every turn a small puzzle.

## Game Rules

### Setup
- 2 players spawn at opposite ends of the level.
- Each player has 1 HP — one clean hit ends the duel.
- A contested D6 roll decides who acts first (re-rolled on a tie).

### Turn Structure
1. **Roll**: at the start of each turn, the active player rolls a D6 to receive that many Action Points (AP).
2. **Intermission** (~1.5 s): a "PLAYER N TURN" banner shows briefly before control hands over.
3. **Active turn**: the player spends AP on actions (move, aim, shoot) until AP reaches 0.
4. **Hand-off**: control passes to the other player and the cycle repeats.

### Actions

| Action | AP | Notes |
|---|---|---|
| Move (1 cell) | 1 | Cardinal directions only. Failed moves cost no AP. |
| Push a box | 1 | Walking into a box pushes it (and any chain behind it) one cell. |
| Open / move through a door | 1 | Door rotates 90° in the direction of motion. |
| Enter Aim mode | 0 | Free; aiming reveals a raycast line in the chosen direction. |
| Change aim direction | 0 | While aiming, movement keys rotate the aim. |
| Fire | 1 | Fires along the aim line. The first thing the ray hits absorbs the shot. |

### Terrain

- **Floor** — the only tiles you may stand on. Walking off the floor is blocked.
- **Obstacles** — solid walls. Block movement and shots. Indestructible.
- **Boxes** (Cover) — 1 HP, blocks shots, can be pushed in chains. Walking into a box pushes it; a chain push fails (and the player stays put) if the back of the chain hits a wall, an obstacle, a door, or the edge of the floor. Boxes shatter at 0 HP, opening the lane.
- **Doors** (Cover) — 1 HP, sit on the edge between two cells. A door's rotation is constrained to `[-90°, +90°]` from its closed orientation. Each pass through rotates the door 90° in the direction of motion; if that would push past the limit, the move is blocked. Closed doors block shots; open doors swing into one of the adjacent cells and can still be hit there.

### Aiming and Shooting
1. Press **shoot** in idle to enter aim mode (free).
2. Use movement keys to rotate the aim line through the four cardinal directions.
3. Press **shoot** again to fire (costs 1 AP).
4. The shot deals 1 damage to the first thing it hits — player, box, or door — then ends. Walls and closed doors block shots without taking damage.

### Win Condition
Last gunslinger standing wins.

## Controls

| Key | Action |
|---|---|
| `W` / `↑` | Up |
| `S` / `↓` | Down |
| `A` / `←` | Left |
| `D` / `→` | Right |
| `Space` / `Z` | Shoot (enter aim → fire) |

## Running

Open the project in Godot 4.6 and run, or from the project root:

```bash
godot --path .
```
