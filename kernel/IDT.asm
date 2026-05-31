[bits 32]

; Template for a single IDT entry (8 bytes)
struc idt_entry
    .offset_low  resw 1  ; Lower 16 bits of the handler address
    .selector    resw 1  ; Code segment selector (e.g., 0x08)
    .zero        resb 1  ; Always 0
    .type_attr   resb 1  ; Flags (10001110b = 32-bit Interrupt Gate, Ring 0)
    .offset_high resw 1  ; Upper 16 bits of the handler address
endstruc

; The table itself (allocating only 3 vectors for this example instead of 256)
idt_table:
    resb 8 * 3  ; Allocate 24 bytes

; Pointer for the LIDT instruction
idt_descriptor:
    dw (8 * 3) - 1       ; Limit (size minus 1)
    dd idt_table         ; Base address
