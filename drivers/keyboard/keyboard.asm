[bits 32]

; ============================================================
; PS/2 Keyboard IRQ1 handler
; Safe version (no lost AL, proper filtering)
; ============================================================

PS2_DATA_PORT equ 0x60
PS2_CMD_PORT  equ 0x64

global keyboard_handler_main

extern kbd_buf_push

section .text

keyboard_handler_main:
    pusha

    ; --------------------------------------------------------
    ; Check PS/2 controller status
    ; bit 0 = output buffer full
    ; bit 5 = mouse data (ignore)
    ; --------------------------------------------------------
    in al, PS2_CMD_PORT
    test al, 1
    jz .done

    test al, 0x20
    jnz .done

    ; --------------------------------------------------------
    ; Read scancode
    ; --------------------------------------------------------
    in al, PS2_DATA_PORT

    ; --------------------------------------------------------
    ; Ignore key release events
    ; (bit 7 = 1 means key release)
    ; --------------------------------------------------------
    test al, 0x80
    jnz .done

    ; --------------------------------------------------------
    ; Translate scancode to ASCII
    ; --------------------------------------------------------
    movzx ebx, al
    mov al, [scancode_to_ascii + ebx]

    ; --------------------------------------------------------
    ; If zero -> no valid mapping
    ; --------------------------------------------------------
    test al, al
    jz .done

    ; --------------------------------------------------------
    ; Push character into keyboard buffer
    ; --------------------------------------------------------
    call kbd_buf_push

.done:
    popa
    ret
