[bits 32]

gdt_start:
    ; 1. Null Descriptor (mandatory)
    dd 0x0, 0x0

    ; 2. Code Segment (Selector 0x08)
    ; Base = 0x0, Limit = 0xFFFFF, Granularity = 4KB, Ring 0, Code
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00

    ; 3. Data Segment (Selector 0x10)
    ; Base = 0x0, Limit = 0xFFFFF, Granularity = 4KB, Ring 0, Data
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
