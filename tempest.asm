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
; Stores future window identifiers.
; className is used when registering the class.
; windowTitle appears in the title bar.
; hInstance is filled before WinMain runs.
; hWndMain stores the CreateWindowEx result.

.code
main PROC
    exit
main ENDP

; Placeholder WinMain keeps the future window path linkable.
; Startup still enters main until the window setup is ready.
WinMain PROC,
    hInst:DWORD,
    hPrevInst:DWORD,
    lpCmdLine:DWORD,
    nCmdShow:DWORD
    xor eax, eax
    ret
WinMain ENDP

END main
