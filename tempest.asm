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
; Stores future window identifiers.
; className is used when registering the class.
; windowTitle appears in the title bar.
; hInstance is filled before WinMain runs.
; hWndMain stores the CreateWindowEx result.
; wndClass stores the registration data for the main window.
; msgData stores one message-loop record.

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
    ; Control will stay in WinMain once GetMessage is connected.
message_loop:
    ; GetMessage will decide whether the program keeps running.
    ; TranslateMessage will prepare keyboard messages for dispatch.
    ; DispatchMessage will send work to the window procedure.
    jmp message_exit
message_exit:
    ; WinMain still returns a fixed status until the loop is filled in.
    xor eax, eax
    ret
WinMain ENDP

WndProc PROC,
    hWnd:DWORD,
    uMsg:DWORD,
    wParam:DWORD,
    lParam:DWORD
    xor eax, eax
    ret
WndProc ENDP

END main
