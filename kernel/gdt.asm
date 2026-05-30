[bits 32]

section .data
align 8

; Старт таблицы GDT
gdt_start:

    ; 1. Нулевой дескриптор (Обязательное требование архитектуры x86)
    dq 0x0

    ; 2. Сегмент кода ядра (Смещение: 0x08)
gdt_code:
    dw 0xFFFF       ; Limit (биты 0-15)
    dw 0x0000       ; Base (биты 0-15)
    db 0x00         ; Base (биты 16-23)
    db 10011010b    ; Access byte: Present, Ring 0, Executable, Readable
    db 11001111b    ; Flags: 4KB Granularity, 32-bit, Limit (биты 16-19)
    db 0x00         ; Base (биты 24-31)

    ; 3. Сегмент данных ядра (Смещение: 0x10)
gdt_data:
    dw 0xFFFF       ; Limit (биты 0-15)
    dw 0x0000       ; Base (биты 0-15)
    db 0x00         ; Base (биты 16-23)
    db 10010010b    ; Access byte: Present, Ring 0, Writable
    db 11001111b    ; Flags: 4KB Granularity, 32-bit, Limit (биты 16-19)
    db 0x00         ; Base (биты 24-31)

gdt_end:

; Структура для загрузки через команду lgdt
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Размер таблицы (лимит)
    dd gdt_start                ; Физический адрес начала таблицы

section .text
global load_gdt

; Функция загрузки GDT и обновления сегментных регистров
load_gdt:
    ; Загружаем дескриптор
    lgdt [gdt_descriptor]
    
    ; Обновляем регистры данных на селектор 0x10 (gdt_data)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Дальний прыжок (Far Jump) для обновления регистра CS (Code Segment)
    ; Это принудительно сбрасывает конвейер процессора
    jmp 0x08:flush_cs

flush_cs:
    ret
