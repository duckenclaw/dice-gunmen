# dice-gunmen

## Game Overview
A turn-based 2D top-down PvP shooter where players use dice rolls to determine action points and engage in tactical combat on a grid-based battlefield.

## Game Rules

### Setup
- 2 players start on a 2D plane at opposite ends
- Initial contested D6 roll determines who goes first
- Each player has 1 HP

### Turn Structure
1. **Roll Phase**: Roll D6 to receive Action Points (AP) equal to the dice value (1-6)
2. **Action Phase**: Use available AP to perform actions
3. **End Turn**: Pass control to the other player

### Actions

#### Move (1 AP)
- Move to an adjacent grid cell (up, down, left, right)
- Cannot move to cells occupied by obstacles or other players
- Grid cells are 60x60 pixels

#### Shoot (1 AP when fired)
- **Enter Aim State** (Free): Press "shoot" action to enter aiming stance
    - Movement controls now rotate the aim direction
    - RayCast2D becomes visible showing aim direction
    - No AP cost for entering aim mode
- **Fire** (1 AP): Press "shoot" action again while aiming
    - Fires a projectile in the aimed direction
    - Destroys first obstacle hit OR kills a player (1 damage)
    - Returns to idle state
    - Costs 1 AP when fired

### Win Condition
- Last player alive wins the game

### Grid System
- Cell size: 60x60 pixels
- Movement is discrete (snaps to grid positions)
- Grid positions calculated as: `(x / 60) * 60, (y / 60) * 60`

### State Management

#### Level States
- `INITIAL_ROLL`: Contested D6 roll phase
- `TURN_ACTIVE`: Player is taking their turn
- `GAME_OVER`: A player has died

#### Player States
- `IDLE`: Default state, can move or enter aim mode
- `AIMING`: Aiming mode, controls rotate aim direction

### Input Actions Required
The project must define these input actions in Project Settings:
- `up`: Move/aim up
- `down`: Move/aim down
- `left`: Move/aim left
- `right`: Move/aim right
- `shoot`: Enter aim mode / Fire weapon

### Script Responsibilities

#### Level Script (`src/level.gd`)
- Manage game state (initial roll, turn order, game over)
- Track current player and AP remaining
- Roll D6 at turn start
- Handle turn switching
- Detect player death and end game
- Broadcast signals to players (enable/disable control)

#### Player Script (`src/player.gd`)
- Implement state machine (Idle/Aiming)
- Handle grid-based movement (60x60 cells)
- Manage aim direction rotation
- Handle shooting mechanics
- Raycast collision detection
- Health and damage system (1 HP)
- Request AP from Level when performing actions

### RayCast2D Configuration
- Positioned at player center (0, -60)
- Default direction: right (1000, 0)
- Rotates in cardinal directions (0°, 90°, 180°, 270°)
- Visible only in AIMING state
- Detects collision with other players

### Turn Flow
1. Level rolls D6 for current player
2. Player receives AP (1-6)
3. Player uses actions (Move/Shoot) until AP = 0
4. Level switches to next player
5. Repeat until one player dies

### Damage System
- All players have 1 HP
- Successful raycast hit = 1 damage = death
- Dead players are removed from turn order
- Game ends when only one player remains