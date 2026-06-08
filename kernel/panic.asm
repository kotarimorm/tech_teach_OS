; ============================================================
; File: kernel/panic.asm
; Topic: Kernel Panic
; Type: Debug helper
;
; Purpose:
;   Prints a panic message directly to VGA memory and halts.
;
; Assumes:
;   - 32-bit protected mode
;   - VGA text memory is available at 0xB8000
;   - ESI points to a null-terminated panic message
;   - Data selector 0x10 is valid
;
; Notes:
;   - This is intended for early fatal error debugging.
;   - It does not recover or return.
;   - It intentionally disables interrupts.
; ============================================================
global panic

section .text
; Input: ESI = address of the message string (null-terminated)
panic:
    cli                 ; Disable interrupts to prevent interference
    cld                 ; Force clear direction flag to ensure forward lodsb/stosw
    
    ; Reset data segments to target kernel space safely
    mov ax, 0x10
    mov ds, ax
    mov es, ax

    mov edi, 0xB8000    ; VGA frame buffer address
    mov ah, 0x4F        ; Attributes: red background (4), white text (F)
    
.loop:
    lodsb               ; Load byte from string (into AL)
    cmp al, 0           ; End of string?
    je .halt
    stosw               ; Write character + attribute to video memory
    jmp .loop

.halt:
    hlt                 ; Halt the CPU
    jmp .halt           ; In case the CPU wakes up
