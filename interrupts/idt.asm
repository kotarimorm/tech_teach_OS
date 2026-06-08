; ============================================================
; File: interrupts/idt.asm
; Topic: Interrupt Descriptor Table
; Type: Reference snippet
;
; Purpose:
;   Provides basic IDT storage, loading, and gate setup logic.
;
; Assumes:
;   - 32-bit protected mode
;   - Kernel code selector is 0x08
;   - Handler addresses are valid and reachable
;
; Notes:
;   - Empty IDT entries will crash if triggered.
;   - Install valid handlers before enabling interrupts.
;   - Enable interrupts only after IDT, PIC, and stack are ready.
; ============================================================
[bits 32]

section .data
align 4
idtr:
    dw (256 * 8) - 1  ; Limit: table size minus 1
    dd idt_table      ; Base address

align 8
idt_table:
    times 256 dq 0    ; Reserve 2048 bytes (256 entries * 8 bytes), fill with zeros

section .text
; Load the IDTR register
load_idt:
    lidt [idtr]
    ret

; Function to set an interrupt gate
; Input: EAX = handler address (ISR), EBX = interrupt number (0-255)
set_idt_gate:
    push edx
    push edi
    
    ; Calculate offset in the table: EBX * 8
    mov edi, idt_table
    lea edi, [edi + ebx * 8]
    
    ; Lower 16 bits of the handler address (Offset 0..15)
    mov dx, ax
    mov [edi], dx
    
    ; Code segment selector (assuming GDT Code Segment = 0x08)
    mov word [edi + 2], 0x08
    
    ; Reserved zero byte
    mov byte [edi + 4], 0x00
    
    ; Flags (Present=1, DPL=00, Type=1110 -> 32-bit Interrupt Gate = 0x8E)
    mov byte [edi + 5], 0x8E
    
    ; Upper 16 bits of the handler address (Offset 16..31)
    shr eax, 16
    mov [edi + 6], ax
    
    pop edi
    pop edx
    ret
