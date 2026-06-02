; ============================================================
; Simple driver manager
; Calls all driver init functions from a table
; NASM x86
; ============================================================

extern kbd_init
extern kbd_handle
extern timer_init

global init_all_drivers

section .data

; ------------------------------------------------------------
; Driver table format:
; [init_function, handle_function]
; handle_function may be 0 if not used
; Table ends with NULL entry
; ------------------------------------------------------------
driver_table:
    dd kbd_init,  kbd_handle
    dd timer_init, 0
    dd 0, 0


section .text

; ------------------------------------------------------------
; init_all_drivers
; Calls all driver init functions in table
; ------------------------------------------------------------
init_all_drivers:
    mov esi, driver_table

.loop:
    mov eax, [esi]          ; load init function pointer
    cmp eax, 0              ; end of table
    je .done

    call eax                ; call init function

    add esi, 8              ; next entry (2 dwords)
    jmp .loop

.done:
    ret
