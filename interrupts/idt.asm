[bits 32]

section .data
align 4
idtr:
    dw (256 * 8) - 1  ; Лимит: размер таблицы минус 1
    dd idt_table      ; Базовый адрес

align 8
idt_table:
    times 256 dq 0    ; Резервируем 2048 байт (256 записей по 8 байт), заполняем нулями

section .text
; Загрузка регистра IDTR
load_idt:
    lidt [idtr]
    ret

; Функция установки шлюза прерывания (Gate)
; Вход: eax = адрес обработчика (ISR), ebx = номер прерывания (0-255)
set_idt_gate:
    push edx
    push edi
    
    ; Вычисляем смещение в таблице: ebx * 8
    mov edi, idt_table
    lea edi, [edi + ebx * 8]
    
    ; Младшие 16 бит адреса обработчика (Offset 0..15)
    mov dx, ax
    mov [edi], dx
    
    ; Селектор сегмента кода (предполагаем, что GDT Code Segment = 0x08)
    mov word [edi + 2], 0x08
    
    ; Зарезервированный нулевой байт
    mov byte [edi + 4], 0x00
    
    ; Флаги (Present=1, DPL=00, Type=1110 -> 32-bit Interrupt Gate = 0x8E)
    mov byte [edi + 5], 0x8E
    
    ; Старшие 16 бит адреса обработчика (Offset 16..31)
    shr eax, 16
    mov [edi + 6], ax
    
    pop edi
    pop edx
    ret
