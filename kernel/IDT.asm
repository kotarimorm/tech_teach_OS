[bits 32]

; Шаблон одной записи в IDT (8 байт)
struc idt_entry
    .offset_low  resw 1  ; Младшие 16 бит адреса обработчика
    .selector    resw 1  ; Селектор сегмента кода (например, 0x08)
    .zero        resb 1  ; Всегда 0
    .type_attr   resb 1  ; Флаги (10001110b = 32-bit Interrupt Gate, Ring 0)
    .offset_high resw 1  ; Старшие 16 бит адреса обработчика
endstruc

; Сама таблица (для примера делаем всего 3 вектора, а не 256)
idt_table:
    resb 8 * 3  ; Выделяем 24 байта

; Указатель для команды LIDT
idt_descriptor:
    dw (8 * 3) - 1       ; Лимит (размер минус 1)
    dd idt_table         ; Базовый адрес
