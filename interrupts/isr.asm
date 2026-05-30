[bits 32]

; Макрос для быстрой отправки EOI (End of Interrupt) мастеру PIC
%macro PIC_SEND_EOI 0
    mov al, 0x20
    out 0x20, al
%endmacro

; Обработчик IRQ0 (Таймер) - вектор 0x20
isr_timer:
    pusha           ; Сохраняем все регистры текущего потока
    
    ; -> Здесь в будущем будет вызов твоего планировщика (Scheduler)
    
    PIC_SEND_EOI
    popa            ; Восстанавливаем регистры
    iret            ; Выход из прерывания

; Обработчик IRQ1 (Клавиатура) - вектор 0x21
isr_keyboard:
    pusha
    
    ; Читаем скан-код нажатой клавиши из порта 0x60
    in al, 0x60
    
    ; -> Здесь будет передача скан-кода в драйвер клавиатуры
    
    PIC_SEND_EOI
    popa
    iret

; Глобальный обработчик исключений процессора (заглушка)
; Если ловим Page Fault, Double Fault и т.д.
isr_exception:
    pusha
    ; Для начала просто глушим систему (Kernel Panic)
    cli
    hlt
