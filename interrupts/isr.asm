; ============================================================
; File: interrupts/isr.asm
; Topic: Interrupt Service Routines
; Type: Reference snippet
;
; Purpose:
;   Shows minimal ISR patterns for timer, keyboard, and exceptions.
;
; Assumes:
;   - IDT entries point to these handlers
;   - PIC has been remapped if hardware IRQs are used
;   - Stack is valid and writable
;
; WARNING:
;   Exceptions with error codes require special stack handling.
;   Do not use one generic handler for all exceptions without adapting it.
;
; Notes:
;   - Send EOI for hardware IRQs.
;   - Do not send EOI for CPU exceptions.
;   - Keep early ISR code simple and observable.
; ============================================================
[bits 32]

; Safe Macro: preserves EAX register on stack while sending EOI
%macro PIC_SEND_EOI 0
    push eax
    mov al, 0x20
    out 0x20, al
    pop eax
%endmacro

isr_timer:
    pusha
    PIC_SEND_EOI
    popa
    iret

isr_keyboard:
    pusha
    
    in al, 0x60             ; Scan code is safe in AL now, PIC_SEND_EOI won't destroy it
    
    ; -> Your driver code here (can safely use AL)
    
    PIC_SEND_EOI
    popa
    iret

; Global Exception Handler (For exceptions WITHOUT error code)
isr_exception:
    pusha
    cli
    hlt
    jmp $

; Dedicated Page Fault Handler (Example of exception WITH error code)
isr_page_fault:
    ; Processors pushes Error Code here automatically
    pusha
    
    ; -> Kernel Panic visualization logic here
    
    cli
    hlt
    ; If we ever want to restore from Page Fault:
    ; popa
    ; add esp, 4   ; MANDATORY: Pop the error code from the stack before iret
    ; iret
