# CSE 3120 Contest 2: MASM Tempest

A Win32 MASM simple recreation of the arcade game Tempest.

To compile please use either the asm_CSE3120.bat file created earlier in the class, or compile directly through a properly setup VS

The repo can be found at github.com/avery004/cse3120-contest-2

## High-level layout

The file is organized into these main parts:

1. Global constants
2. Local Win32 declarations and imported procedure prototypes
3. Global game state in `.data`
4. Program startup and window creation
5. Rendering procedures
6. Gameplay update and object-management procedures

## Constants and definitions

The top of the file defines the game and window configuration:

- fixed window size: `800 x 600`
- timer-driven update interval: `FRAME_MS = 16`
- 12 tunnel lanes
- near and far tunnel radii
- depth range derived from those radii
- player, shot, and enemy colors
- fixed pool sizes for shots and enemies
- score/lives defaults
- title, playing, paused, and game-over state values

It also defines local Win32 values instead of relying on SDK include files,
including:

- window styles
- message constants such as `WM_CREATE`, `WM_PAINT`, `WM_KEYDOWN`, `WM_TIMER`
- virtual key codes
- GDI constants such as `PS_SOLID`, `TRANSPARENT`, and `OPAQUE`
- local `POINT`, `RECT`, `MSG`, `WNDCLASS`, and `PAINTSTRUCT` structs

## Global game state in `.data`

The `.data` section stores both window state and gameplay state.

Window and drawing state:

- class name and window title strings
- `hInstance`
- main window handle
- `WNDCLASS`, `MSG`, and `PAINTSTRUCT` storage
- temporary GDI handles such as pens and brushes

Gameplay state:

- `playerLane`
- fixed-size shot arrays: `shotActive`, `shotLane`, `shotDepth`
- fixed-size enemy arrays: `enemyActive`, `enemyLane`, `enemyDepth`
- `enemySpawnTick`
- `score`
- `lives`
- `gameState`

UI text and HUD state:

- title screen strings
- game-over strings
- HUD format string and output buffer

Geometry and scratch values:

- precomputed near-ring and far-ring coordinate arrays
- temporary interpolation, drawing, and enemy-shape variables
- `currentSpawnTicks` for score-based difficulty scaling

## Startup and window shell

The startup path is:

- `main`
- `WinMain`
- standard message loop

`main` gets the module handle, calls `WinMain`, and exits through
`ExitProcess`.

`WinMain`:

- fills a `WNDCLASS`
- registers the class
- creates the main window
- shows and updates it
- runs `GetMessage`, `TranslateMessage`, and `DispatchMessage`

## Window procedure behavior

`WndProc` handles the core messages:

- `WM_CREATE`
  - starts the timer with `SetTimer`
- `WM_TIMER`
  - calls `UpdateGame`
  - invalidates the window
- `WM_PAINT`
  - clears the background to black
  - draws the tunnel, player, shots, enemies, HUD, title prompt, and
    game-over prompt
- `WM_KEYDOWN`
  - left/right move the player during active play
  - `Space` starts the game from the title screen
  - `Space` also fires during active play
  - `Enter` restarts after game over
  - `Escape` closes the window
- `WM_DESTROY`
  - stops the timer
  - posts quit

All other messages fall through to `DefWindowProc`.

## Rendering procedures

### `DrawTunnel`

Draws the Tempest playfield as a wireframe:

- near ring
- far ring
- lane connector lines

It uses a cyan pen and the precomputed lane coordinate arrays.

### `DrawPlayer`

Draws the player marker on the current lane by interpolating between the near
and far ring with `LerpLanePoint`.

### `DrawShots`

Draws active shots as short red line segments moving inward along a lane.

### `DrawEnemies`

Draws active enemies as short yellow cross-lane segments positioned by depth.

### HUD and state prompts

`WM_PAINT` also:

- formats `SCORE` and `LIVES` into a HUD string with `wsprintf`
- draws that HUD with `TextOut`
- draws title text when `gameState == STATE_TITLE`
- draws restart text when `gameState == STATE_GAME_OVER`

## Geometry helper

### `LerpLanePoint`

This helper converts a lane index plus a depth value into a concrete screen
point by linearly interpolating between the matching near-ring and far-ring
coordinates.

That helper is used by:

- `DrawPlayer`
- `DrawShots`
- `DrawEnemies`

## Gameplay update logic

### `UpdateGame`

`UpdateGame` is timer-driven and only advances the game while
`gameState == STATE_PLAYING`.

It currently does the following:

- recalculates enemy spawn delay from score
- advances the spawn timer
- spawns enemies
- updates shot depths
- updates enemy depths
- removes enemies that reach the outer edge
- reduces lives when enemies get through
- switches to `STATE_GAME_OVER` when the last life is lost
- calls collision handling after movement

Difficulty scales by score by shortening spawn delay down to a minimum.

### `FireShot`

Finds the first inactive shot slot and activates it on the current player
lane.

### `SpawnEnemy`

Finds the first inactive enemy slot, picks a lane from `GetTickCount`, and
spawns an enemy at depth `0`.

### `CheckShotEnemyCollision`

Checks active shot/enemy pairs and awards score when they overlap deeply
enough on the same lane.

Current limitation: the collision code compares shot slot `i` only against
enemy slot `i`, not every shot against every enemy.

## Current controls

- `Left Arrow`: move one lane left during play
- `Right Arrow`: move one lane right during play
- `Space`: start from title, then fire during play
- `Enter`: restart after game over
- `Escape`: quit

## Current game behavior

The current `tempest.asm` implements:

- a Win32 game window
- a timer-driven update loop
- a 12-lane wireframe tunnel
- player movement
- firing
- enemy spawning and movement
- score and lives
- title and game-over prompts
- restart after game over

## Important notes

- The source file is self-contained and manually declares the Win32 types and
  imports it uses.
- The project is built around GDI line rendering, not DirectX.
- The code still uses fixed-size object pools and several scratch globals to
  keep the assembly straightforward.
- The main remaining risk is real Windows/MASM verification, since that
  determines whether the current declarations and imports match the target
  toolchain exactly.
