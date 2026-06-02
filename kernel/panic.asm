; core/panic.asm
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
