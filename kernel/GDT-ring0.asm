[bits 32]

gdt_start:
    ; 1. Null Descriptor (обязательно)
    dd 0x0, 0x0

    ; 2. Code Segment (Селектор 0x08)
    ; База = 0x0, Лимит = 0xFFFFF, Гранулярность = 4KB, Ring 0, Код
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00

    ; 3. Data Segment (Селектор 0x10)
    ; База = 0x0, Лимит = 0xFFFFF, Гранулярность = 4KB, Ring 0, Данные
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
