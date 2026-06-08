; ============================================================
; File: interrupts/pic.asm
; Topic: Programmable Interrupt Controller
; Type: Reference snippet
;
; Purpose:
;   Remaps the legacy PIC away from CPU exception vectors.
;
; Assumes:
;   - x86 legacy PIC environment
;   - I/O ports are available
;   - Interrupts are disabled during PIC setup
;
; Notes:
;   - Typical remap offsets are 0x20 for master and 0x28 for slave.
;   - Mask unused IRQ lines until handlers are installed.
;   - Enable interrupts only after IDT and handlers are valid.
; ============================================================
[bits 32]

PIC1_COMMAND equ 0x20
PIC1_DATA    equ 0x21
PIC2_COMMAND equ 0xA0
PIC2_DATA    equ 0xA1

remap_pic:
    ; ICW1: Start initialization
    mov al, 0x11
    out PIC1_COMMAND, al
    call io_wait
    out PIC2_COMMAND, al
    call io_wait

    ; ICW2: Vector offset (Master = 0x20, Slave = 0x28)
    mov al, 0x20
    out PIC1_DATA, al
    call io_wait
    mov al, 0x28
    out PIC2_DATA, al
    call io_wait

    ; ICW3: Cascading setup
    mov al, 0x04
    out PIC1_DATA, al
    call io_wait
    mov al, 0x02
    out PIC2_DATA, al
    call io_wait

    ; ICW4: 8086/88 mode
    mov al, 0x01
    out PIC1_DATA, al
    call io_wait
    out PIC2_DATA, al
    call io_wait

    ; Temporarily mask all hardware interrupts
    mov al, 0xFF
    out PIC1_DATA, al
    out PIC2_DATA, al
    ret
    
; Artificial delay for slow I/O ports on older hardware
io_wait:
    out 0x80, al
    ret
