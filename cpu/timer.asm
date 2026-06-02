[bits 32]

PIT_COMMAND_PORT equ 0x43
PIT_CHANNEL_0    equ 0x40
PIT_BASE_FREQ    equ 1193180

global init_timer

; ----------------------------------------------------------
; init_timer
;
; Input:
;   EAX = desired frequency (Hz)
;
; Examples:
;   mov eax, 100
;   call init_timer
;
; Valid range:
;   19 Hz .. 1193180 Hz
; ----------------------------------------------------------

init_timer:
    pusha

    ; Prevent divide-by-zero
    test eax, eax
    jz .done

    ; divisor = PIT_BASE_FREQ / frequency
    mov ecx, eax

    mov eax, PIT_BASE_FREQ
    xor edx, edx
    div ecx

    ; PIT divisor must fit in 16 bits
    cmp eax, 65535
    jbe .divisor_ok

    mov eax, 65535

.divisor_ok:

    mov bx, ax

    ; Command byte:
    ; Channel 0
    ; Lobyte/Hibyte access
    ; Mode 3 (Square Wave)
    ; Binary counter

    mov dx, PIT_COMMAND_PORT
    mov al, 0x36
    out dx, al

    ; Low byte

    mov dx, PIT_CHANNEL_0
    mov al, bl
    out dx, al

    ; High byte

    mov al, bh
    out dx, al

.done:
    popa
    ret
