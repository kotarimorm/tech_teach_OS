; ============================================================
; File: drivers/keyboard/keyboard.asm
; Topic: PS/2 Keyboard
; Type: Reference snippet
;
; Purpose:
;   Demonstrates a basic PS/2 keyboard IRQ1 handler.
;
; Assumes:
;   - PIC is remapped
;   - IDT has a valid IRQ1 entry
;   - Keyboard IRQ is unmasked
;   - kbd_buf_push is available
;   - scancode_to_ascii table is provided
;
; WARNING:
;   This is not a complete keyboard driver.
;   It does not implement full key state tracking.
;   It does not fully support Shift/Ctrl/Alt/CapsLock layouts.
;   Extended E0 keys are intentionally minimal.
;
; Notes:
;   - This is useful for early text input experiments.
;   - Adapt scancode translation to your own keyboard layer.
; ============================================================
; TODO:
;   - Provide or include the scancode_to_ascii table.
;   - Add Shift/Ctrl/Alt state tracking.
;   - Add CapsLock handling.
;   - Add extended E0 key support.
;   - Add key release event support if needed.
;   - Decide whether the buffer stores ASCII, scancodes, or key events.
;
; WARNING:
;   This is an early keyboard input example.
;   It is not a complete keyboard driver or layout system.
[bits 32]

PS2_DATA_PORT equ 0x60
PS2_STAT_PORT equ 0x64
PIC1_COMMAND  equ 0x20
PIC_EOI       equ 0x20

global keyboard_handler_main

extern kbd_buf_push

section .bss

kbd_e0_pending:
    resb 1

section .text

keyboard_handler_main:

    pusha

    ; --------------------------------------------------------
    ; Check controller output buffer
    ; --------------------------------------------------------

    in al, PS2_STAT_PORT

    test al, 1
    jz .irq_done

    ; --------------------------------------------------------
    ; Mouse packet?
    ; Drain port 0x60 and ignore.
    ; --------------------------------------------------------

    test al, 0x20
    jz .read_keyboard

    in al, PS2_DATA_PORT
    jmp .irq_done

.read_keyboard:

    ; --------------------------------------------------------
    ; Read scancode
    ; --------------------------------------------------------

    in al, PS2_DATA_PORT

    ; --------------------------------------------------------
    ; E0 prefix
    ; --------------------------------------------------------

    cmp al, 0xE0
    jne .not_e0

    mov byte [kbd_e0_pending], 1
    jmp .irq_done

.not_e0:

    ; --------------------------------------------------------
    ; Extended key continuation
    ; For now ignore entire E0 sequence.
    ; Later:
    ; Arrow keys
    ; Insert/Delete
    ; Home/End
    ; Right Ctrl
    ; Right Alt
    ; --------------------------------------------------------

    cmp byte [kbd_e0_pending], 0
    je .normal_key

    mov byte [kbd_e0_pending], 0
    jmp .irq_done

.normal_key:

    ; --------------------------------------------------------
    ; Ignore break codes
    ; --------------------------------------------------------

    test al, 0x80
    jnz .irq_done

    ; --------------------------------------------------------
    ; Translate Set 1 scancode -> ASCII
    ; --------------------------------------------------------

    movzx ebx, al

    mov al, [scancode_to_ascii + ebx]

    test al, al
    jz .irq_done

    ; --------------------------------------------------------
    ; Push ASCII character
    ; --------------------------------------------------------

    call kbd_buf_push

.irq_done:

    mov al, PIC_EOI
    out PIC1_COMMAND, al

    popa
    iret
