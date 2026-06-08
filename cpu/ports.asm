; ============================================================
; File: cpu/ports.asm
; Topic: I/O Ports
; Type: Utility macros
;
; Purpose:
;   Provides small NASM macros for port-mapped I/O access.
;
; Assumes:
;   - x86 environment with port I/O support
;   - Caller knows the target hardware port
;
; Notes:
;   - These macros are intentionally minimal.
;   - Port access can hang or misconfigure hardware if used incorrectly.
;   - Use only with documented ports or emulator experiments.
; ============================================================
[bits 32]

; ----------------------------------------------------------
; Write byte to I/O port
; Input:
;   AL = value
; ----------------------------------------------------------
%macro OUTB 1
    push dx
    mov dx, %1
    out dx, al
    pop dx
%endmacro

; ----------------------------------------------------------
; Read byte from I/O port
; Output:
;   AL = value
; ----------------------------------------------------------
%macro INB 1
    push dx
    mov dx, %1
    in al, dx
    pop dx
%endmacro

; ----------------------------------------------------------
; Write word to I/O port
; Input:
;   AX = value
; ----------------------------------------------------------
%macro OUTW 1
    push dx
    mov dx, %1
    out dx, ax
    pop dx
%endmacro

; ----------------------------------------------------------
; Read word from I/O port
; Output:
;   AX = value
; ----------------------------------------------------------
%macro INW 1
    push dx
    mov dx, %1
    in ax, dx
    pop dx
%endmacro

; ----------------------------------------------------------
; Legacy I/O delay (~400ns+)
; ----------------------------------------------------------
%macro IO_WAIT 0
    push dx
    mov dx, 0x80
    out dx, al
    pop dx
%endmacro
