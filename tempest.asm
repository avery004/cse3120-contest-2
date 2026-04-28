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
DEPTH_RANGE EQU NEAR_RADIUS - FAR_RADIUS
PLAYER_COLOR       EQU 0000FF00h
SHOT_COLOR  EQU 000000FFh
ENEMY_COLOR EQU 0000FFFFh
PLAYER_MARKER_SIZE EQU 14
PLAYER_PEN_WIDTH   EQU 2
PLAYER_START_LANE  EQU 0
MAX_SHOTS          EQU 6
MAX_ENEMIES        EQU 6
SPAWN_TICKS        EQU 240
MIN_SPAWN_TICKS    EQU 40
SPAWN_STEP_SCORE   EQU 1000
SPAWN_STEP_TICKS   EQU 40
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

option casemap:none

INCLUDELIB kernel32.lib
INCLUDELIB user32.lib
INCLUDELIB gdi32.lib

NULL            EQU 0
TRUE            EQU 1

CS_VREDRAW      EQU 0001h
CS_HREDRAW      EQU 0002h

IDC_ARROW       EQU 32512
CW_USEDEFAULT   EQU 80000000h

WS_OVERLAPPEDWINDOW EQU 00CF0000h

WM_CREATE       EQU 0001h
WM_DESTROY      EQU 0002h
WM_PAINT        EQU 000Fh
WM_KEYDOWN      EQU 0100h
WM_TIMER        EQU 0113h

VK_RETURN       EQU 0Dh
VK_ESCAPE       EQU 1Bh
VK_SPACE        EQU 20h
VK_LEFT         EQU 25h
VK_RIGHT        EQU 27h

BLACK_BRUSH     EQU 4
PS_SOLID        EQU 0
TRANSPARENT     EQU 1
OPAQUE          EQU 2

POINT STRUCT
    x DWORD ?
    y DWORD ?
POINT ENDS

RECT STRUCT
    left   DWORD ?
    top    DWORD ?
    right  DWORD ?
    bottom DWORD ?
RECT ENDS

MSG STRUCT
    hwnd    DWORD ?
    message DWORD ?
    wParam  DWORD ?
    lParam  DWORD ?
    time    DWORD ?
    pt      POINT <>
MSG ENDS

WNDCLASS STRUCT
    style         DWORD ?
    lpfnWndProc   DWORD ?
    cbClsExtra    DWORD ?
    cbWndExtra    DWORD ?
    hInstance     DWORD ?
    hIcon         DWORD ?
    hCursor       DWORD ?
    hbrBackground DWORD ?
    lpszMenuName  DWORD ?
    lpszClassName DWORD ?
WNDCLASS ENDS

PAINTSTRUCT STRUCT
    hdc         DWORD ?
    fErase      DWORD ?
    rcPaint     RECT <>
    fRestore    DWORD ?
    fIncUpdate  DWORD ?
    rgbReserved BYTE 32 DUP(?)
PAINTSTRUCT ENDS

GetModuleHandleA PROTO :DWORD
LoadCursorA      PROTO :DWORD, :DWORD
RegisterClassA   PROTO :DWORD
CreateWindowExA  PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
ShowWindow       PROTO :DWORD, :DWORD
UpdateWindow     PROTO :DWORD
GetMessageA      PROTO :DWORD, :DWORD, :DWORD, :DWORD
TranslateMessage PROTO :DWORD
DispatchMessageA PROTO :DWORD
DefWindowProcA   PROTO :DWORD, :DWORD, :DWORD, :DWORD
DestroyWindow    PROTO :DWORD
PostQuitMessage  PROTO :DWORD
SetTimer         PROTO :DWORD, :DWORD, :DWORD, :DWORD
KillTimer        PROTO :DWORD, :DWORD
InvalidateRect   PROTO :DWORD, :DWORD, :DWORD

BeginPaint       PROTO :DWORD, :DWORD
EndPaint         PROTO :DWORD, :DWORD
FillRect         PROTO :DWORD, :DWORD, :DWORD
GetStockObject   PROTO :DWORD
CreatePen        PROTO :DWORD, :DWORD, :DWORD
SelectObject     PROTO :DWORD, :DWORD
DeleteObject     PROTO :DWORD
SetBkMode        PROTO :DWORD, :DWORD
SetTextColor     PROTO :DWORD, :DWORD
TextOutA         PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
MoveToEx         PROTO :DWORD, :DWORD, :DWORD, :DWORD
LineTo           PROTO :DWORD, :DWORD, :DWORD

wsprintfA        PROTO C :DWORD, :DWORD, :VARARG
ExitProcess      PROTO :DWORD

GetModuleHandle  TEXTEQU <GetModuleHandleA>
LoadCursor       TEXTEQU <LoadCursorA>
RegisterClass    TEXTEQU <RegisterClassA>
CreateWindowEx   TEXTEQU <CreateWindowExA>
GetMessage       TEXTEQU <GetMessageA>
DispatchMessage  TEXTEQU <DispatchMessageA>
DefWindowProc    TEXTEQU <DefWindowProcA>
TextOut          TEXTEQU <TextOutA>
wsprintf         TEXTEQU <wsprintfA>

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
GetTickCount PROTO

LerpLanePoint PROTO,
    lane:DWORD,
    depth:DWORD,
    pX:DWORD,
    pY:DWORD

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
enemyNextLane DWORD 0
score       DWORD START_SCORE
lives       DWORD INITIAL_LIVES
gameState   DWORD STATE_TITLE
; Title strings support the opening screen prompt.
titleText1  BYTE "MASM TEMPEST",0
titleText2  BYTE "PRESS SPACE TO START",0
gameOverText1 BYTE "GAME OVER",0
gameOverText2 BYTE "PRESS ENTER TO RESTART",0
hudFormat  BYTE "SCORE %u  LIVES %u",0
hudBuffer  BYTE 32 DUP(0)
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

drawIndex DWORD 0
drawX     DWORD 0
drawY     DWORD 0

tunnelPen  DWORD 0
drawX2     DWORD 0
drawY2     DWORD 0

drawDepth DWORD 0
drawLane1 DWORD 0
drawLane2 DWORD 0
enemyX1   DWORD 0
enemyY1   DWORD 0
enemyX2   DWORD 0
enemyY2   DWORD 0

currentSpawnTicks DWORD SPAWN_TICKS

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
    ; DrawTunnel lays down the wireframe playfield.
    INVOKE DrawTunnel, paintData.hdc
    ; DrawPlayer will sit on top of the tunnel geometry.
    INVOKE DrawPlayer, paintData.hdc
    ; Use one bright pen for shot and enemy overlay lines.
    ; Draw shots in red so they do not blend into the tunnel.
    INVOKE CreatePen, PS_SOLID, 2, SHOT_COLOR
    mov testPen, eax
    INVOKE SelectObject, paintData.hdc, testPen
    mov oldPen, eax

    call DrawShots

    INVOKE SelectObject, paintData.hdc, oldPen
    INVOKE DeleteObject, testPen

    ; Draw enemies separately in yellow.
    INVOKE CreatePen, PS_SOLID, 2, ENEMY_COLOR
    mov testPen, eax
    INVOKE SelectObject, paintData.hdc, testPen
    mov oldPen, eax

    call DrawEnemies

    INVOKE SelectObject, paintData.hdc, oldPen
    INVOKE DeleteObject, testPen
    ; Draw the HUD and state prompts with a transparent text background.
    INVOKE SetBkMode, paintData.hdc, TRANSPARENT
    INVOKE SetTextColor, paintData.hdc, 0000FFFFh
    INVOKE wsprintf, ADDR hudBuffer, ADDR hudFormat, score, lives
    mov ecx, eax
    INVOKE TextOut, paintData.hdc, 16, 16, ADDR hudBuffer, ecx
    cmp gameState, STATE_TITLE
    jne check_game_over
    INVOKE TextOut, paintData.hdc, 320, 24, ADDR titleText1, LENGTHOF titleText1 - 1
    INVOKE TextOut, paintData.hdc, 250, 52, ADDR titleText2, LENGTHOF titleText2 - 1
    jmp finish_paint
check_game_over:
    cmp gameState, STATE_GAME_OVER
    jne finish_paint
    INVOKE TextOut, paintData.hdc, 332, 24, ADDR gameOverText1, LENGTHOF gameOverText1 - 1
    INVOKE TextOut, paintData.hdc, 230, 52, ADDR gameOverText2, LENGTHOF gameOverText2 - 1
finish_paint:
    INVOKE SetBkMode, paintData.hdc, OPAQUE
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
    ; Movement input only applies during active play.
    cmp gameState, STATE_PLAYING
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
    cmp gameState, STATE_PLAYING
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
    jne check_play_fire
    mov gameState, STATE_PLAYING
    INVOKE InvalidateRect, hWnd, 0, 1
    xor eax, eax
    ret
check_play_fire:
    ; Space only fires while live gameplay is running.
    cmp gameState, STATE_PLAYING
    jne check_enter
fire_shot:
    INVOKE FireShot
    INVOKE InvalidateRect, hWnd, 0, 1
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
    mov currentSpawnTicks, SPAWN_TICKS
    mov enemyNextLane, 0
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

    INVOKE CreatePen, PS_SOLID, 1, 0000FFFFh
    mov tunnelPen, eax

    INVOKE SelectObject, hdc, tunnelPen
    mov oldPen, eax

    ; Draw near outer ring.
    INVOKE MoveToEx, hdc, nearXPoints[0], nearYPoints[0], 0

    mov drawIndex, 1

draw_near_ring:
    mov eax, drawIndex
    mov ebx, nearXPoints[eax*4]
    mov edx, nearYPoints[eax*4]

    INVOKE LineTo, hdc, ebx, edx

    inc drawIndex
    cmp drawIndex, LANE_COUNT
    jb draw_near_ring

    INVOKE LineTo, hdc, nearXPoints[0], nearYPoints[0]

    ; Draw far inner ring.
    INVOKE MoveToEx, hdc, farXPoints[0], farYPoints[0], 0

    mov drawIndex, 1

draw_far_ring:
    mov eax, drawIndex
    mov ebx, farXPoints[eax*4]
    mov edx, farYPoints[eax*4]

    INVOKE LineTo, hdc, ebx, edx

    inc drawIndex
    cmp drawIndex, LANE_COUNT
    jb draw_far_ring

    INVOKE LineTo, hdc, farXPoints[0], farYPoints[0]

    ; Draw lane connector lines.
    mov drawIndex, 0

draw_lane_lines:
    mov eax, drawIndex

    mov ebx, nearXPoints[eax*4]
    mov edx, nearYPoints[eax*4]
    INVOKE MoveToEx, hdc, ebx, edx, 0

    mov eax, drawIndex
    mov ebx, farXPoints[eax*4]
    mov edx, farYPoints[eax*4]
    INVOKE LineTo, hdc, ebx, edx

    inc drawIndex
    cmp drawIndex, LANE_COUNT
    jb draw_lane_lines

    INVOKE SelectObject, hdc, oldPen
    INVOKE DeleteObject, tunnelPen

    ret
DrawTunnel ENDP

DrawPlayer PROC,
    hdc:DWORD

    INVOKE CreatePen, PS_SOLID, PLAYER_PEN_WIDTH, PLAYER_COLOR
    mov testPen, eax

    INVOKE SelectObject, hdc, testPen
    mov oldPen, eax

    ; Outer point of player.
    INVOKE LerpLanePoint, playerLane, 0, ADDR drawX, ADDR drawY

    ; Inner point of player, slightly toward the center.
    INVOKE LerpLanePoint, playerLane, 16, ADDR drawX2, ADDR drawY2

    INVOKE MoveToEx, hdc, drawX, drawY, 0
    INVOKE LineTo, hdc, drawX2, drawY2

    INVOKE SelectObject, hdc, oldPen
    INVOKE DeleteObject, testPen

    ret
DrawPlayer ENDP

DrawShots PROC

    mov drawIndex, 0

draw_shots:
    cmp drawIndex, MAX_SHOTS
    jae draw_shots_done

    mov eax, drawIndex
    cmp BYTE PTR shotActive[eax], 0
    je next_draw_shot

    mov eax, drawIndex
    mov ebx, shotLane[eax*4]

    ; First point of shot.
    mov eax, drawIndex
    INVOKE LerpLanePoint, ebx, shotDepth[eax*4], ADDR drawX, ADDR drawY

    ; Second point of shot, slightly behind it.
    mov eax, drawIndex
    mov edx, shotDepth[eax*4]
    sub edx, 10
    cmp edx, 0
    jge shot_depth_ok
    mov edx, 0

shot_depth_ok:
    INVOKE LerpLanePoint, ebx, edx, ADDR drawX2, ADDR drawY2

    INVOKE MoveToEx, paintData.hdc, drawX, drawY, 0
    INVOKE LineTo, paintData.hdc, drawX2, drawY2

next_draw_shot:
    inc drawIndex
    jmp draw_shots

draw_shots_done:
    ret

DrawShots ENDP

DrawEnemies PROC

    mov drawIndex, 0

draw_enemies:
    cmp drawIndex, MAX_ENEMIES
    jae draw_enemies_done

    mov eax, drawIndex
    cmp BYTE PTR enemyActive[eax], 0
    je next_draw_enemy

    ; ebx = enemy lane
    mov eax, drawIndex
    mov ebx, enemyLane[eax*4]

    ; edx = interpolation depth.
    ; enemyDepth grows outward, so convert it to lane interpolation depth.
    mov eax, drawIndex
    mov edx, DEPTH_RANGE
    sub edx, enemyDepth[eax*4]

    cmp edx, 0
    jge enemy_depth_ok
    mov edx, 0

enemy_depth_ok:
    ; Save the enemy depth.
    mov drawDepth, edx

    ; left neighbor lane = lane - 1, wrapped.
    mov eax, ebx
    cmp eax, 0
    jne enemy_left_normal
    mov eax, LANE_COUNT

enemy_left_normal:
    dec eax
    mov drawLane1, eax

    ; right neighbor lane = lane + 1, wrapped.
    mov eax, ebx
    inc eax
    cmp eax, LANE_COUNT
    jb enemy_right_ok
    mov eax, 0

enemy_right_ok:
    mov drawLane2, eax

    ; Get point on left neighboring lane at same depth.
    INVOKE LerpLanePoint, drawLane1, drawDepth, ADDR drawX, ADDR drawY

    ; Get point on right neighboring lane at same depth.
    INVOKE LerpLanePoint, drawLane2, drawDepth, ADDR drawX2, ADDR drawY2

    ; Draw a shortened cross-line between those two lane points.
    ; New start = left + 3/8 of the way to right.
    mov eax, drawX2
    sub eax, drawX
    imul eax, 3
    cdq
    mov ecx, 8
    idiv ecx
    add eax, drawX
    mov enemyX1, eax

    mov eax, drawY2
    sub eax, drawY
    imul eax, 3
    cdq
    mov ecx, 8
    idiv ecx
    add eax, drawY
    mov enemyY1, eax

    ; New end = left + 5/8 of the way to right.
    mov eax, drawX2
    sub eax, drawX
    imul eax, 5
    cdq
    mov ecx, 8
    idiv ecx
    add eax, drawX
    mov enemyX2, eax

    mov eax, drawY2
    sub eax, drawY
    imul eax, 5
    cdq
    mov ecx, 8
    idiv ecx
    add eax, drawY
    mov enemyY2, eax

    INVOKE MoveToEx, paintData.hdc, enemyX1, enemyY1, 0
    INVOKE LineTo, paintData.hdc, enemyX2, enemyY2

next_draw_enemy:
    inc drawIndex
    jmp draw_enemies

draw_enemies_done:
    ret

DrawEnemies ENDP

LerpLanePoint PROC USES ebx esi edi,
    lane:DWORD,
    depth:DWORD,
    pX:DWORD,
    pY:DWORD

    ; Clamp depth to DEPTH_RANGE.
    mov eax, depth
    cmp eax, DEPTH_RANGE
    jle depth_not_too_large
    mov eax, DEPTH_RANGE

depth_not_too_large:
    cmp eax, 0
    jge depth_ok
    mov eax, 0

depth_ok:
    mov depth, eax

    mov esi, lane

    ; x = nearX + ((farX - nearX) * depth) / DEPTH_RANGE
    mov eax, farXPoints[esi*4]
    sub eax, nearXPoints[esi*4]
    imul depth
    cdq
    mov ebx, DEPTH_RANGE
    idiv ebx
    add eax, nearXPoints[esi*4]

    mov edi, pX
    mov DWORD PTR [edi], eax

    ; y = nearY + ((farY - nearY) * depth) / DEPTH_RANGE
    mov eax, farYPoints[esi*4]
    sub eax, nearYPoints[esi*4]
    imul depth
    cdq
    mov ebx, DEPTH_RANGE
    idiv ebx
    add eax, nearYPoints[esi*4]

    mov edi, pY
    mov DWORD PTR [edi], eax

    ret

LerpLanePoint ENDP

; UpdateGame advances live gameplay state only during active play.
UpdateGame PROC USES ebx
    ; Freeze movement, spawning, and collisions outside active play.
    ; Title, pause, and game-over all share this early return.
    ; Reset the spawn counter so resume does not burst-spawn.
    cmp gameState, STATE_PLAYING
    je update_live
    mov enemySpawnTick, 0
    ret
update_live:
    ; Count update ticks before spawning another enemy.
        ; Recalculate spawn delay from score.
    ; 0-999 score     = 240 ticks
    ; 1000-1999 score = 200 ticks
    ; 2000-2999 score = 160 ticks
    ; 3000-3999 score = 120 ticks
    ; 4000-4999 score = 80 ticks
    ; 5000+ score     = 40 ticks

    mov eax, score
    xor edx, edx
    mov ebx, SPAWN_STEP_SCORE
    div ebx                     ; eax = score / 1000

    mov ebx, SPAWN_STEP_TICKS
    mul ebx                     ; eax = scoreStep * 40

    mov ebx, SPAWN_TICKS
    sub ebx, eax                ; ebx = 240 - scoreStep*40

    cmp ebx, MIN_SPAWN_TICKS
    jae spawn_delay_ok
    mov ebx, MIN_SPAWN_TICKS

spawn_delay_ok:
    mov currentSpawnTicks, ebx

    inc enemySpawnTick
    mov eax, currentSpawnTicks
    cmp enemySpawnTick, eax
    jb no_spawn_this_tick

    mov enemySpawnTick, 0
    call SpawnEnemy

no_spawn_this_tick:
    ; Always reset ECX before updating shots.
    ; Otherwise shots only update reliably on enemy-spawn frames.
    mov ecx, 0

update_shots:
    cmp ecx, MAX_SHOTS
    jae update_enemies
    cmp BYTE PTR shotActive[ecx], 0
    je next_shot
    add DWORD PTR shotDepth[ecx*4], 12
    cmp DWORD PTR shotDepth[ecx*4], DEPTH_RANGE
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
    add DWORD PTR enemyDepth[ecx*4], 1
    cmp DWORD PTR enemyDepth[ecx*4], DEPTH_RANGE
    jb next_enemy

    ; Any enemy that reaches the outer shell costs one life.
    cmp DWORD PTR lives, 1
    ja lose_life_any_lane

    mov DWORD PTR lives, 0
    mov gameState, STATE_GAME_OVER
    jmp clear_enemy_any_lane

lose_life_any_lane:
    dec DWORD PTR lives

clear_enemy_any_lane:
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

SpawnEnemy PROC USES ebx edx
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

    ; Pick a lane from 0 to 11 using GetTickCount.
    INVOKE GetTickCount
    xor edx, edx
    mov ebx, LANE_COUNT
    div ebx                     ; edx = remainder 0..LANE_COUNT-1

    mov DWORD PTR enemyLane[ecx*4], edx
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
    cmp eax, DEPTH_RANGE
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
