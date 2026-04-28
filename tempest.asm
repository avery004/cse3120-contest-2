; tempest.asm
; CSE 3120 Contest 2
; Project: basic Tempest-style game in MASM
.386
.model flat, stdcall
.stack 4096

; Constants for the first Win32 window.
WINDOW_WIDTH  EQU 800
WINDOW_HEIGHT EQU 600
TIMER_ID      EQU 1
FRAME_MS      EQU 16
; TIMER_ID identifies the game update timer.
; FRAME_MS targets about 60 updates per second.
; Keep sizes fixed while early drawing code is simple.
; Future code can replace these with client-area calculations.
; First Tempest layout constants.
CENTER_X    EQU WINDOW_WIDTH / 2
CENTER_Y    EQU WINDOW_HEIGHT / 2
LANE_COUNT  EQU 12
NEAR_RADIUS EQU 220
FAR_RADIUS  EQU 90
PLAYER_COLOR       EQU 0000FF00h
PLAYER_MARKER_SIZE EQU 14
PLAYER_PEN_WIDTH   EQU 2
PLAYER_START_LANE  EQU 0
MAX_SHOTS          EQU 6
MAX_ENEMIES        EQU 6
SPAWN_TICKS        EQU 45
START_SCORE        EQU 0
INITIAL_LIVES      EQU 3
ENEMY_SCORE        EQU 100
STATE_TITLE        EQU 0
STATE_PLAYING      EQU 1
STATE_PAUSED       EQU 2
STATE_GAME_OVER    EQU 3
; Twelve lanes gives the first tunnel a clear rhythm.
; The near radius stays close to the player edge.
; The far radius keeps the tunnel visually narrow.
; Center values keep early geometry aligned in the window.
; Player values start with a bright green marker.
; The marker stays small enough to fit one lane edge.
; Shots start with a small fixed pool.
; A fixed pool keeps the first firing code simple.
; Enemy slots start with the same fixed pool size.
; Spawn timing starts slow enough to keep the first wave readable.
; The opening score and life count start from simple fixed values.
; This keeps the first collision rules easy to test.
; Score stays integer-only for simple HUD output later.
; Game state values keep later input and timer checks simple.
; Title remains the default until an explicit start action.

INCLUDE Irvine32.inc
; Irvine32.inc supplies course helpers and usually includes SmallWin.inc.
; Keep Win32 library links here for later graphics and window calls.
INCLUDELIB Irvine32.lib
INCLUDELIB kernel32.lib
INCLUDELIB user32.lib
INCLUDELIB gdi32.lib

; kernel32: process startup and system calls.
; user32: windows, messages, and keyboard input.
; gdi32: lines, pens, brushes, and back buffers.

; Forward declarations for later Win32 code.
WinMain PROTO,
    hInst:DWORD,
    hPrevInst:DWORD,
    lpCmdLine:DWORD,
    nCmdShow:DWORD
WndProc PROTO,
    hWnd:DWORD,
    uMsg:DWORD,
    wParam:DWORD,
    lParam:DWORD
; DrawTunnel will own the wireframe tunnel drawing path.
DrawTunnel PROTO,
    hdc:DWORD
; DrawPlayer will render the player marker on the near ring.
DrawPlayer PROTO,
    hdc:DWORD
; UpdateGame will advance timed game state.
UpdateGame PROTO
; FireShot will activate one shot slot from the player lane.
FireShot PROTO
; SpawnEnemy will activate one enemy slot in a fixed lane.
SpawnEnemy PROTO
; CheckShotEnemyCollision will compare active shots to active enemies.
CheckShotEnemyCollision PROTO

.data
className   BYTE "MASMTempestWindow",0
windowTitle BYTE "MASM Tempest",0
hInstance   DWORD 0
hWndMain    DWORD 0
wndClass    WNDCLASS <>
msgData     MSG <>
paintData   PAINTSTRUCT <>
blackBrush  DWORD 0
testPen     DWORD 0
oldPen      DWORD 0
playerLane  DWORD PLAYER_START_LANE
shotActive  BYTE  MAX_SHOTS DUP(0)
shotLane    DWORD MAX_SHOTS DUP(0)
shotDepth   DWORD MAX_SHOTS DUP(0)
enemyActive BYTE  MAX_ENEMIES DUP(0)
enemyLane   DWORD MAX_ENEMIES DUP(0)
enemyDepth  DWORD MAX_ENEMIES DUP(0)
enemySpawnTick DWORD 0
score       DWORD START_SCORE
lives       DWORD INITIAL_LIVES
gameState   DWORD STATE_TITLE
; Stores future window identifiers.
; className is used when registering the class.
; windowTitle appears in the title bar.
; hInstance is filled before WinMain runs.
; hWndMain stores the CreateWindowEx result.
; wndClass stores the registration data for the main window.
; msgData stores one message-loop record.
; paintData stores BeginPaint and EndPaint state.
; blackBrush stores the stock black brush handle.
; testPen and oldPen store temporary GDI pen handles.
; playerLane tracks which near-ring lane the player occupies.
; The first lane starts at the top of the tunnel.
; Later input code wraps this value across all lanes.
; shotActive tracks whether each shot slot is in use.
; shotLane stores the lane index for each active shot.
; shotDepth stores tunnel depth for each active shot.
; The first shot logic will scan these arrays linearly.
; enemyActive tracks which enemy slots are in use.
; enemyLane stores the lane index for each active enemy.
; enemyDepth stores tunnel depth for each active enemy.
; The first enemy logic will scan these arrays linearly.
; Enemy arrays mirror the shot layout for simple update loops.
; enemySpawnTick counts update ticks until the next spawn check.
; score starts at zero for a new run.
; lives starts at the opening reserve count.
; Later collision code will update both values.
; The HUD drawing step can read these values directly.
; Enemy hits add a fixed score bonus.
; gameState starts on the title screen before live play begins.
; Pause and game-over states will share the same storage slot.
; Restart logic can reset this value without new variables.
; Precomputed near-ring coordinates for the first tunnel.
; Points start at the top and continue clockwise.
nearXPoints DWORD 400, 510, 590, 620, 590, 510
           DWORD 400, 290, 210, 180, 210, 290
nearYPoints DWORD 80, 110, 190, 300, 410, 490
           DWORD 520, 490, 410, 300, 190, 110
; Each index maps to the same lane in both arrays.
; These values avoid runtime trig in the first geometry build.
; The far ring will use the same lane order later.
; Tunnel drawing can loop over these arrays directly.
; Matching far-ring coordinates for the same lane order.
farXPoints  DWORD 400, 445, 478, 490, 478, 445
           DWORD 400, 355, 322, 310, 322, 355
farYPoints  DWORD 210, 222, 255, 300, 345, 378
           DWORD 390, 378, 345, 300, 255, 222
; Near and far indices connect into the same tunnel lane.
; These points keep the far ring centered on the same origin.
; The smaller ring leaves room for inward lane lines.
; Drawing code can reuse the same loop bounds for both rings.
; Later loops can step through both arrays with one lane index.

.code
main PROC
    INVOKE GetModuleHandle, 0
    mov hInstance, eax
    INVOKE WinMain, hInstance, 0, 0, 1
    INVOKE ExitProcess, eax
main ENDP

; WinMain prepares the window class and shows the first window.
; Program startup enters main first.
; main initializes hInstance before calling WinMain.
; The fourth WinMain argument becomes ShowWindow's command.
; The class is registered before the window is created.
; The message loop is added after the window shell is stable.
WinMain PROC,
    hInst:DWORD,
    hPrevInst:DWORD,
    lpCmdLine:DWORD,
    nCmdShow:DWORD
    mov wndClass.style, CS_HREDRAW or CS_VREDRAW
    mov wndClass.lpfnWndProc, OFFSET WndProc
    mov eax, hInst
    mov wndClass.hInstance, eax
    mov wndClass.lpszClassName, OFFSET className
    INVOKE LoadCursor, 0, IDC_ARROW
    mov wndClass.hCursor, eax
    INVOKE RegisterClass, ADDR wndClass
    test eax, eax
    jnz class_ready
    mov eax, 1
    ret
class_ready:
    ; Create the main window before showing it.
    INVOKE CreateWindowEx, 0, ADDR className, ADDR windowTitle,
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        WINDOW_WIDTH, WINDOW_HEIGHT, 0, 0, hInst, 0
    mov hWndMain, eax
    test eax, eax
    jnz window_ready
    mov eax, 1
    ret
window_ready:
    ; ShowWindow applies the requested initial display state.
    INVOKE ShowWindow, hWndMain, nCmdShow
    ; UpdateWindow forces the first paint immediately.
    INVOKE UpdateWindow, hWndMain
    ; Control stays in WinMain until GetMessage returns 0.
message_loop:
    INVOKE GetMessage, ADDR msgData, 0, 0, 0
    test eax, eax
    jz message_exit
    INVOKE TranslateMessage, ADDR msgData
    INVOKE DispatchMessage, ADDR msgData
    jmp message_loop
message_exit:
    mov eax, msgData.wParam
    ret
WinMain ENDP

WndProc PROC,
    hWnd:DWORD,
    uMsg:DWORD,
    wParam:DWORD,
    lParam:DWORD
    ; WM_PAINT clears the invalid area before custom drawing is added.
    cmp uMsg, WM_PAINT
    jne check_create
    ; BeginPaint returns the device context for the invalid rectangle.
    INVOKE BeginPaint, hWnd, ADDR paintData
    INVOKE GetStockObject, BLACK_BRUSH
    mov blackBrush, eax
    ; FillRect uses the stock brush, so there is nothing to delete here.
    INVOKE FillRect, paintData.hdc, ADDR paintData.rcPaint, blackBrush
    ; DrawTunnel will replace the temporary test line over time.
    INVOKE DrawTunnel, paintData.hdc
    ; DrawPlayer will sit on top of the tunnel geometry.
    INVOKE DrawPlayer, paintData.hdc
    INVOKE CreatePen, PS_SOLID, 1, 0000FFFFh
    mov testPen, eax
    INVOKE SelectObject, paintData.hdc, testPen
    mov oldPen, eax
    call DrawShots
    call DrawEnemies
    INVOKE MoveToEx, paintData.hdc, 120, 120, 0
    INVOKE LineTo, paintData.hdc, 680, 420
    INVOKE SelectObject, paintData.hdc, oldPen
    INVOKE DeleteObject, testPen
    ; EndPaint releases the temporary paint state.
    INVOKE EndPaint, hWnd, ADDR paintData
    ; Return 0 after handling the paint request.
    xor eax, eax
    ret
check_create:
    ; WM_CREATE starts the fixed update timer for later game logic.
    cmp uMsg, WM_CREATE
    jne check_timer
    ; The callback stays null because WM_TIMER will handle updates.
    INVOKE SetTimer, hWnd, TIMER_ID, FRAME_MS, 0
    ; Return 0 after creating the timer.
    xor eax, eax
    ret
check_timer:
    ; WM_TIMER advances state and requests another redraw.
    cmp uMsg, WM_TIMER
    jne check_keydown
    INVOKE UpdateGame
    INVOKE InvalidateRect, hWnd, 0, 1
    xor eax, eax
    ret
check_keydown:
    ; Left arrow wraps from lane 0 to the last lane.
    cmp uMsg, WM_KEYDOWN
    jne check_destroy
    cmp wParam, VK_LEFT
    jne check_right
    cmp playerLane, 0
    jne move_left
    mov playerLane, LANE_COUNT
move_left:
    dec playerLane
    ; Request a repaint after the lane changes.
    INVOKE InvalidateRect, hWnd, 0, 1
    xor eax, eax
    ret
check_right:
    ; Right arrow wraps from the last lane back to lane 0.
    cmp wParam, VK_RIGHT
    jne check_fire
    inc playerLane
    cmp playerLane, LANE_COUNT
    jb move_right_done
    mov playerLane, 0
move_right_done:
    INVOKE InvalidateRect, hWnd, 0, 1
    xor eax, eax
    ret
check_fire:
    ; Space starts play from title, then fires during live play.
    cmp wParam, VK_SPACE
    jne check_enter
    ; The first Space press only leaves the title state.
    cmp gameState, STATE_TITLE
    jne fire_shot
    mov gameState, STATE_PLAYING
    INVOKE InvalidateRect, hWnd, 0, 1
    xor eax, eax
    ret
fire_shot:
    INVOKE FireShot
    xor eax, eax
    ret
check_enter:
    cmp wParam, VK_RETURN
    jne check_escape
    cmp gameState, STATE_GAME_OVER
    jne check_escape
    mov score, START_SCORE
    mov lives, INITIAL_LIVES
    mov playerLane, PLAYER_START_LANE
    mov enemySpawnTick, 0
    mov gameState, STATE_PLAYING
    mov ecx, MAX_SHOTS
reset_slots:
    dec ecx
    mov BYTE PTR shotActive[ecx], 0
    mov BYTE PTR enemyActive[ecx], 0
    jnz reset_slots
    xor eax, eax
    ret
check_escape:
    ; Escape closes the main window through WM_DESTROY.
    cmp wParam, VK_ESCAPE
    jne check_destroy
    INVOKE DestroyWindow, hWnd
    ; Return 0 after handling the key press.
    xor eax, eax
    ret
check_destroy:
    ; WM_DESTROY is handled locally.
    ; Stop the fixed update timer before ending the message loop.
    ; This path runs for the close button and Escape-triggered shutdown.
    cmp uMsg, WM_DESTROY
    jne not_destroy
    ; KillTimer is harmless if the timer is already inactive.
    INVOKE KillTimer, hWnd, TIMER_ID
    ; WM_QUIT makes GetMessage return 0 in WinMain.
    INVOKE PostQuitMessage, 0
    ; Return 0 after handling the destroy notification.
    xor eax, eax
    ret
not_destroy:
    ; Forward unhandled work to DefWindowProc.
    INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam
    ; Default processing covers close, move, size, and focus changes.
    ; This preserves default close, move, and sizing behavior.
    ; DefWindowProc returns the result in eax.
    ; Only WM_DESTROY should bypass the default path above.
    ret
WndProc ENDP

; DrawTunnel traces both rings and the lane connectors.
DrawTunnel PROC,
    hdc:DWORD
    ; Start at the top of the near ring.
    INVOKE MoveToEx, hdc, DWORD PTR nearXPoints[0], DWORD PTR nearYPoints[0], 0
    mov ecx, 1
draw_near_ring:
    INVOKE LineTo, hdc, DWORD PTR nearXPoints[ecx*4], DWORD PTR nearYPoints[ecx*4]
    inc ecx
    cmp ecx, LANE_COUNT
    jb draw_near_ring
    ; Close the polygon by returning to the first lane.
    INVOKE LineTo, hdc, DWORD PTR nearXPoints[0], DWORD PTR nearYPoints[0]
    ; Trace the smaller inner ring with the same lane order.
    INVOKE MoveToEx, hdc, DWORD PTR farXPoints[0], DWORD PTR farYPoints[0], 0
    mov ecx, 1
draw_far_ring:
    INVOKE LineTo, hdc, DWORD PTR farXPoints[ecx*4], DWORD PTR farYPoints[ecx*4]
    inc ecx
    cmp ecx, LANE_COUNT
    jb draw_far_ring
    INVOKE LineTo, hdc, DWORD PTR farXPoints[0], DWORD PTR farYPoints[0]
    ; Draw lane connectors from the outer ring inward.
    mov ecx, 0
draw_lane_lines:
    INVOKE MoveToEx, hdc, DWORD PTR nearXPoints[ecx*4], DWORD PTR nearYPoints[ecx*4], 0
    INVOKE LineTo, hdc, DWORD PTR farXPoints[ecx*4], DWORD PTR farYPoints[ecx*4]
    inc ecx
    cmp ecx, LANE_COUNT
    jb draw_lane_lines
    ret
DrawTunnel ENDP

; DrawPlayer renders a small marker on the selected near lane.
DrawPlayer PROC,
    hdc:DWORD
    INVOKE CreatePen, PS_SOLID, PLAYER_PEN_WIDTH, PLAYER_COLOR
    mov testPen, eax
    INVOKE SelectObject, hdc, testPen
    mov oldPen, eax
    mov eax, playerLane
    mov ecx, DWORD PTR nearXPoints[eax*4]
    mov edx, DWORD PTR nearYPoints[eax*4]
    sub edx, PLAYER_MARKER_SIZE
    INVOKE MoveToEx, hdc, ecx, edx, 0
    add edx, PLAYER_MARKER_SIZE * 2
    INVOKE LineTo, hdc, ecx, edx
    INVOKE SelectObject, hdc, oldPen
    INVOKE DeleteObject, testPen
    ret
DrawPlayer ENDP

DrawShots PROC
    mov ecx, 0
draw_shots:
    cmp ecx, MAX_SHOTS
    jae draw_shots_done
    cmp BYTE PTR shotActive[ecx], 0
    je next_draw_shot
    mov eax, DWORD PTR shotLane[ecx*4]
    mov edx, DWORD PTR nearYPoints[eax*4]
    sub edx, DWORD PTR shotDepth[ecx*4]
    INVOKE MoveToEx, paintData.hdc, DWORD PTR nearXPoints[eax*4], edx, 0
    add edx, 8
    INVOKE LineTo, paintData.hdc, DWORD PTR nearXPoints[eax*4], edx
next_draw_shot:
    inc ecx
    jmp draw_shots
draw_shots_done:
    ret
DrawShots ENDP
DrawEnemies PROC
    mov ecx, 0
draw_enemies:
    cmp ecx, MAX_ENEMIES
    jae draw_enemies_done
    cmp BYTE PTR enemyActive[ecx], 0
    je next_draw_enemy
    mov eax, DWORD PTR enemyLane[ecx*4]
    mov edx, DWORD PTR farYPoints[eax*4]
    add edx, DWORD PTR enemyDepth[ecx*4]
    INVOKE MoveToEx, paintData.hdc, DWORD PTR farXPoints[eax*4], edx, 0
    sub edx, 8
    INVOKE LineTo, paintData.hdc, DWORD PTR farXPoints[eax*4], edx
next_draw_enemy:
    inc ecx
    jmp draw_enemies
draw_enemies_done:
    ret
DrawEnemies ENDP
; UpdateGame advances live gameplay state only during active play.
UpdateGame PROC
    ; Freeze movement, spawning, and collisions outside active play.
    ; Title, pause, and game-over all share this early return.
    ; Reset the spawn counter so resume does not burst-spawn.
    cmp gameState, STATE_PLAYING
    je update_live
    mov enemySpawnTick, 0
    ret
update_live:
    ; Count update ticks before spawning another enemy.
    inc enemySpawnTick
    cmp enemySpawnTick, SPAWN_TICKS
    jb update_shots
    mov enemySpawnTick, 0
    call SpawnEnemy
    mov ecx, 0
update_shots:
    cmp ecx, MAX_SHOTS
    jae update_enemies
    cmp BYTE PTR shotActive[ecx], 0
    je next_shot
    add DWORD PTR shotDepth[ecx*4], 12
    cmp DWORD PTR shotDepth[ecx*4], NEAR_RADIUS
    jbe next_shot
    mov BYTE PTR shotActive[ecx], 0
next_shot:
    inc ecx
    jmp update_shots
update_enemies:
    mov ecx, 0
move_enemies:
    cmp ecx, MAX_ENEMIES
    jae update_done
    cmp BYTE PTR enemyActive[ecx], 0
    je next_enemy
    add DWORD PTR enemyDepth[ecx*4], 6
    cmp DWORD PTR enemyDepth[ecx*4], NEAR_RADIUS
    jb next_enemy
    ; Remove enemies that reach the player edge.
    mov eax, DWORD PTR enemyLane[ecx*4]
    cmp eax, playerLane
    jne clear_enemy
    ; The final life flips the game into the game-over state.
    cmp DWORD PTR lives, 1
    ja lose_life
    mov DWORD PTR lives, 0
    mov gameState, STATE_GAME_OVER
    jmp clear_enemy
lose_life:
    ; Earlier hits only reduce the remaining life count.
    dec DWORD PTR lives
clear_enemy:
    mov BYTE PTR enemyActive[ecx], 0
next_enemy:
    inc ecx
    jmp move_enemies
update_done:
    ; Run collision checks after movement finishes for this frame.
    call CheckShotEnemyCollision
    ret
UpdateGame ENDP

; FireShot activates the first free shot slot.
FireShot PROC
    mov ecx, 0
find_free_shot:
    cmp ecx, MAX_SHOTS
    jae fire_done
    cmp BYTE PTR shotActive[ecx], 0
    je activate_shot
    inc ecx
    jmp find_free_shot
activate_shot:
    mov BYTE PTR shotActive[ecx], 1
    mov eax, playerLane
    mov DWORD PTR shotLane[ecx*4], eax
    mov DWORD PTR shotDepth[ecx*4], 0
fire_done:
    ret
FireShot ENDP

SpawnEnemy PROC
    mov ecx, 0
find_free_enemy:
    cmp ecx, MAX_ENEMIES
    jae spawn_done
    cmp BYTE PTR enemyActive[ecx], 0
    je activate_enemy
    inc ecx
    jmp find_free_enemy
activate_enemy:
    mov BYTE PTR enemyActive[ecx], 1
    mov DWORD PTR enemyLane[ecx*4], 3
    mov DWORD PTR enemyDepth[ecx*4], 0
spawn_done:
    ret
SpawnEnemy ENDP

; CheckShotEnemyCollision will own shot versus enemy tests.
CheckShotEnemyCollision PROC
    mov ecx, MAX_SHOTS
check_collision_slot:
    dec ecx
    cmp BYTE PTR shotActive[ecx], 0
    je next_collision_slot
    cmp BYTE PTR enemyActive[ecx], 0
    je next_collision_slot
    mov eax, DWORD PTR shotLane[ecx*4]
    cmp eax, DWORD PTR enemyLane[ecx*4]
    jne next_collision_slot
    mov eax, DWORD PTR shotDepth[ecx*4]
    add eax, DWORD PTR enemyDepth[ecx*4]
    cmp eax, NEAR_RADIUS - FAR_RADIUS
    jb next_collision_slot
    ; Clear the matching slots and award the hit score.
    ; The current test still compares same-index shot and enemy entries.
    mov BYTE PTR shotActive[ecx], 0
    mov BYTE PTR enemyActive[ecx], 0
    add score, ENEMY_SCORE
next_collision_slot:
    test ecx, ecx
    jnz check_collision_slot
collision_done:
    ret
CheckShotEnemyCollision ENDP

END main
