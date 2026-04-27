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
; Twelve lanes gives the first tunnel a clear rhythm.
; The near radius stays close to the player edge.
; The far radius keeps the tunnel visually narrow.
; Center values keep early geometry aligned in the window.

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
    jne check_keydown
    ; BeginPaint returns the device context for the invalid rectangle.
    INVOKE BeginPaint, hWnd, ADDR paintData
    INVOKE GetStockObject, BLACK_BRUSH
    mov blackBrush, eax
    ; FillRect uses the stock brush, so there is nothing to delete here.
    INVOKE FillRect, paintData.hdc, ADDR paintData.rcPaint, blackBrush
    INVOKE CreatePen, PS_SOLID, 1, 0000FFFFh
    mov testPen, eax
    INVOKE SelectObject, paintData.hdc, testPen
    mov oldPen, eax
    INVOKE MoveToEx, paintData.hdc, 120, 120, 0
    INVOKE LineTo, paintData.hdc, 680, 420
    INVOKE SelectObject, paintData.hdc, oldPen
    INVOKE DeleteObject, testPen
    ; EndPaint releases the temporary paint state.
    INVOKE EndPaint, hWnd, ADDR paintData
    ; Return 0 after handling the paint request.
    xor eax, eax
    ret
check_keydown:
    ; Escape closes the main window through WM_DESTROY.
    cmp uMsg, WM_KEYDOWN
    jne check_destroy
    cmp wParam, VK_ESCAPE
    jne check_destroy
    INVOKE DestroyWindow, hWnd
    ; Return 0 after handling the key press.
    xor eax, eax
    ret
check_destroy:
    ; WM_DESTROY is handled locally.
    ; Other messages should use the default window procedure.
    ; This keeps standard window behavior intact.
    ; WM_DESTROY ends the message loop through WM_QUIT.
    cmp uMsg, WM_DESTROY
    jne not_destroy
    INVOKE PostQuitMessage, 0
    ; Return 0 after handling the destroy notification.
    xor eax, eax
    ret
not_destroy:
    ; Forward unhandled work to DefWindowProc.
    INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam
    ; This preserves default close, move, and sizing behavior.
    ; DefWindowProc returns the result in eax.
    ret
WndProc ENDP

END main
