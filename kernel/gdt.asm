[bits 32]

section .data
align 8

; Start of GDT Table
gdt_start:

    ; 1. Null Descriptor (Mandatory x86 architecture requirement)
    dq 0x0

    ; 2. Kernel Code Segment (Offset: 0x08)
gdt_code:
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10011010b    ; Access byte: Present, Ring 0, Executable, Readable
    db 11001111b    ; Flags: 4KB Granularity, 32-bit, Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)

    ; 3. Kernel Data Segment (Offset: 0x10)
gdt_data:
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10010010b    ; Access byte: Present, Ring 0, Writable
    db 11001111b    ; Flags: 4KB Granularity, 32-bit, Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)

gdt_end:

; Structure for loading via the lgdt instruction
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Table size (Limit)
    dd gdt_start                ; Physical address of the table start

section .text
global load_gdt

; Function to load GDT and reload segment registers
load_gdt:
    ; Load the descriptor
    lgdt [gdt_descriptor]
    
    ; Update data registers to selector 0x10 (gdt_data)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Far Jump to reload the CS (Code Segment) register
    ; This forces a flush of the CPU pipeline
    jmp 0x08:flush_cs

flush_cs:
    ret
