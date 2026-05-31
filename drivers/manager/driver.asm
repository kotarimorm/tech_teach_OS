; drivers/drivers.asm
global kbd_init
global kbd_handle

; --- Драйвер клавиатуры ---
kbd_init:
    ; Инициализация портов клавиатуры
    ret

kbd_handle:
    ; Чтение сканкода из 0x60
    in al, 0x60
    ; ... логика обработки ...
    ret

; --- Можно добавить еще драйверы ---
global timer_init
timer_init:
    ret
