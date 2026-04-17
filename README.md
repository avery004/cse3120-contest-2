# CSE 3120 Contest 2: MASM Tempest

This project is a basic **Tempest-style** game written in
32-bit MASM using the Win32 API and Irvine32

## Files

- `tempest.asm` - initial MASM source file.


## Planned Tempest Milestones

The game should be built in small, testable stages. Each milestone should
compile before moving to the next one.

### 1. Convert the Program to a Win32 Window

Goal: replace the do-nothing console-style program with a real Windows
application shell.

- Add Win32 includes, prototypes, constants, and library dependencies.
- Change the linker subsystem from `CONSOLE` to `WINDOWS`.
- Register a window class with `RegisterClassEx` or `RegisterClass`.
- Create the main game window with `CreateWindowEx`.
- Add a standard message loop using `GetMessage`, `TranslateMessage`, and
  `DispatchMessage`.
- Add a window procedure that handles at least:
  - `WM_CREATE`
  - `WM_PAINT`
  - `WM_KEYDOWN`
  - `WM_KEYUP`
  - `WM_DESTROY`
- Call `PostQuitMessage` when the window closes.

Finished when: a blank game window opens, stays open, responds to the close
button, and exits cleanly.

### 2. Add a Basic Rendering Loop

Goal: draw to the window using Windows graphics.

- Start with GDI drawing because it is simpler from MASM than DirectX.
- Use `BeginPaint` and `EndPaint` inside `WM_PAINT`.
- Clear the background to black.
- Create pens for bright vector-style colors.
- Draw a few test lines to confirm coordinates are correct.
- Add `InvalidateRect` when the game needs to redraw.
- Decide whether to redraw from `WM_PAINT`, a timer, or a manual game loop.

Finished when: the window consistently draws a black background with visible
test lines.

### 3. Add Double Buffering

Goal: prevent flicker before drawing the full game.

- Create a compatible memory device context.
- Create a compatible bitmap the same size as the client area.
- Draw the frame to the memory DC first.
- Copy the completed frame to the window using `BitBlt`.
- Recreate the back buffer when the window size changes.
- Clean up GDI objects when the program exits.

Finished when: the test lines redraw smoothly without obvious flicker.

### 4. Define the Game Coordinate System

Goal: establish stable values that every gameplay system can share.

- Choose a fixed client size, such as 800 by 600.
- Define the screen center point.
- Define the number of Tempest lanes, such as 12 or 16.
- Define near-ring and far-ring radii.
- Define how many depth steps exist between the near ring and far ring.
- Store shared constants in one section of the assembly file.
- Use named constants instead of hard-coded numbers wherever practical.

Finished when: the game has clear constants for window size, tunnel size,
lane count, and depth.

### 5. Draw the Tempest Tunnel

Goal: create the main Tempest-style playfield.

- Draw an outer ring or polygon near the player.
- Draw a smaller inner ring or polygon farther away.
- Connect matching points between the near and far rings.
- Use line segments to create a vector arcade look.
- Make each lane visually distinct enough for the player to track movement.
- Keep the tunnel centered in the window.
- Start with a simple circular or polygonal tunnel before attempting unusual
  shapes.

Finished when: the screen shows a recognizable Tempest-style tunnel made from
connected line segments.

### 6. Track Player Position by Lane

Goal: represent player movement in game data before adding enemies.

- Store the player's current lane index.
- Let the player move left and right around the tunnel edge.
- Wrap from the first lane to the last lane and from the last lane to the
  first lane.
- Keep movement lane-based instead of pixel-based.
- Add a small delay or key-repeat handling so movement does not feel too fast.

Finished when: pressing left and right changes the player's lane correctly.

### 7. Draw the Player

Goal: show the player's current lane on the near edge of the tunnel.

- Draw the player at the near end of the selected lane.
- Use a simple shape first, such as a triangle, small ship, or bright marker.
- Make the player color different from the tunnel color.
- Keep the player aligned to the lane boundaries.
- Redraw the player whenever the lane changes.

Finished when: the player marker visibly moves around the tunnel edge.

### 8. Add Keyboard Input

Goal: make controls reliable enough for gameplay.

- Handle `VK_LEFT` and `VK_RIGHT` for lane movement.
- Handle `VK_SPACE` for firing.
- Handle `VK_ESCAPE` for quitting or returning to a menu.
- Store key states if continuous input is needed.
- Avoid putting large gameplay logic directly inside `WM_KEYDOWN`.
- Let the game update read input state once per frame.

Finished when: movement and fire input are detected cleanly without freezing
the window.

### 9. Add a Timed Game Update

Goal: make gameplay advance automatically.

- Use `SetTimer` for a simple first version, or use a manual frame loop later.
- Pick a starting update rate, such as 30 or 60 updates per second.
- Separate update logic from drawing logic.
- On each update:
  - read input state
  - move active bullets
  - move active enemies
  - check collisions
  - request a redraw

Finished when: the game updates repeatedly even when the player is not
pressing keys.

### 10. Add Player Shots

Goal: let the player fire down the tunnel.

- Store a small fixed-size array of shots.
- Each shot should have:
  - active/inactive state
  - lane index
  - depth position
  - speed
- Spawn a shot when the player presses space.
- Move shots from the near edge toward the far end.
- Remove shots when they leave the tunnel.
- Add a simple cooldown so the player cannot fire unlimited shots instantly.
- Draw shots as short bright line segments or small rectangles.

Finished when: pressing space fires a visible shot down the selected lane.

### 11. Add Basic Enemies

Goal: create targets that travel toward the player.

- Store a small fixed-size array of enemies.
- Each enemy should have:
  - active/inactive state
  - lane index
  - depth position
  - speed
  - type if multiple enemy styles are added later
- Spawn enemies near the far end of random lanes.
- Move enemies toward the near edge over time.
- Draw enemies using simple vector shapes.
- Remove enemies when destroyed or when they reach the player.

Finished when: enemies appear at the far end and move toward the player.

### 12. Add Collision Detection

Goal: make shots, enemies, and the player interact.

- Check shot/enemy collisions by comparing lane and depth.
- Destroy both the shot and enemy when they collide.
- Add score when an enemy is destroyed.
- Check enemy/player collision when an enemy reaches the near edge.
- Reduce lives or trigger game over when the player is hit.
- Keep collision logic simple and readable before adding special cases.

Finished when: shots can destroy enemies, and enemies can damage the player.

### 13. Add Score, Lives, and Game State

Goal: make the game feel complete enough to play.

- Track score as a 32-bit integer.
- Track remaining lives.
- Add states such as:
  - title screen
  - playing
  - paused
  - game over
- Draw score and lives using `TextOut`, Irvine console output only if still
  using a console, or simple custom line-based digits.
- Add restart behavior after game over.

Finished when: the player can start, play, lose, and restart.

### 14. Add Difficulty Progression

Goal: make the game become harder over time.

- Increase enemy spawn rate as score increases.
- Increase enemy speed after certain score thresholds.
- Add more simultaneous enemies.
- Add simple enemy variations, such as:
  - straight movers
  - faster movers
  - lane-switching movers
- Keep the first version balanced enough that it remains playable.

Finished when: the game gradually becomes more difficult the longer the
player survives.

### 15. Improve Visual Style

Goal: make the game look more like a vector arcade game.

- Use bright colors on a black background.
- Use different colors for the tunnel, player, shots, and enemies.
- Add a small flash when an enemy is destroyed.
- Add a simple title screen.
- Add a simple game-over screen.
- Avoid complex art until the core gameplay works.

Finished when: the game is readable and visually close to the Tempest idea.

### 16. Add Sound Effects

Goal: add simple feedback without making the project much harder.

- Start with `Beep` or simple Win32 sound calls.
- Add sounds for:
  - firing
  - enemy destroyed
  - player hit
  - game over
- Keep sound optional so the game still runs if sound code is removed.

Finished when: major game events have short sound feedback.

### 17. Clean Up and Document the Code

Goal: make the final assembly project understandable.

- Group related data together in the `.data` section.
- Group constants together near the top of the file.
- Split large procedures into smaller procedures when they become hard to
  follow.
- Add short comments for non-obvious Win32 calls and game logic.
- Remove unused variables and test drawing code.
- Make sure every GDI object that is created is also deleted.
- Update this README whenever build commands or dependencies change.

Finished when: the code builds cleanly, is readable, and the README matches
the final project.