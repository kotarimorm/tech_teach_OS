; ============================================================
; File: drivers/vga.asm
; Topic: VGA Text Mode
; Type: Reference snippet
;
; Purpose:
;   Provides minimal VGA text mode output helpers.
;
; Assumes:
;   - VGA text buffer is mapped at 0xB8000
;   - 80x25 text mode
;   - Writable identity mapping if paging is enabled
;
; Notes:
;   - No scrolling is implemented.
;   - No newline handling is implemented.
;   - No bounds checking is implemented.
;   - Good for early debug output, not a full terminal.
; ============================================================
; TODO:
;   - Add newline handling.
;   - Add scrolling.
;   - Add cursor movement.
;   - Add bounds checking.
;   - Add color selection helpers.
;   - Add decimal and hexadecimal print helpers.
;
; WARNING:
;   This is early debug output only.
;   It is not a complete terminal implementation.
[bits 32]

VIDEO_MEMORY equ 0xB8000
WHITE_ON_BLACK equ 0x0F ; Color attribute: white text on black background
COLS equ 80
ROWS equ 25

section .data
cursor_offset dd 0

section .text
; Function to clear the screen
vga_clear_screen:
    pusha
    cld                  ; Ensure auto-increment direction (DF = 0)
    mov edi, VIDEO_MEMORY
    mov ecx, COLS * ROWS
    mov ax, 0x0F20       ; 0x20 = space character, 0x0F = white on black
    rep stosw            ; Fill the memory with spaces
    mov dword [cursor_offset], 0
    popa
    ret

; Function to print a null-terminated string
; Input: esi = address of the string
vga_print_string:
    pusha
    cld                  ; Ensure auto-increment direction (DF = 0)
    mov edi, VIDEO_MEMORY
    mov edx, [cursor_offset] ; Load the current offset into edx
    add edi, edx         ; Calculate the starting video memory address
    mov ah, WHITE_ON_BLACK

.loop:
    lodsb                ; Read byte from [esi] into al, increments esi
    test al, al          ; Check for null terminator (end of string)
    jz .done
    
    stosw                ; Write ax to [edi], increments edi by 2
    add edx, 2           ; Increment the local offset copy
    jmp .loop

.done:
    mov [cursor_offset], edx ; Save the updated offset back to memory
    popa
    ret
