; drivers/manager.asm
extern kbd_init
extern kbd_handle
extern timer_init

section .data
; Таблица драйверов: [init_addr, handle_addr]
driver_table:
    dd kbd_init, kbd_handle
    dd timer_init, 0         ; У таймера нет обработчика нажатий
    
section .text
global init_all_drivers

init_all_drivers:
    mov edi, driver_table
    mov ecx, 2               ; Количество драйверов
.loop:
    mov eax, [edi]           ; Берем адрес init
    cmp eax, 0
    je .next
    call eax                 ; Вызываем init
.next:
    add edi, 8               ; Переходим к следующей записи (2 * 4 байта)
    loop .loop
    ret
