[bits 32]

PIT_COMMAND_PORT equ 0x43
PIT_CHANNEL_0    equ 0x40
PIT_BASE_FREQ    equ 1193180 ; Базовая аппаратная частота PIT в Гц

global init_timer

; Функция инициализации таймера (IRQ0)
; Вход: EAX = желаемая частота в Гц (например, 100 для переключения контекста 100 раз в сек)
init_timer:
    pusha

    ; Вычисляем делитель: Делитель = Базовая частота / Желаемая частота
    mov ecx, PIT_BASE_FREQ
    xor edx, edx      ; Обнуляем EDX для корректного деления
    xchg eax, ecx     ; Теперь EAX = 1193180, ECX = Желаемая частота
    div ecx           ; EAX = EAX / ECX. В EAX теперь лежит делитель
    mov ebx, eax      ; Сохраняем делитель в EBX

    ; Отправляем конфигурационный байт в Command Port
    ; 0x36 = Канал 0, доступ младший/старший байт, Режим 3 (Генератор меандра), Бинарный формат
    mov al, 0x36
    out PIT_COMMAND_PORT, al

    ; Отправляем младший байт делителя (Low byte)
    mov al, bl
    out PIT_CHANNEL_0, al

    ; Отправляем старший байт делителя (High byte)
    mov al, bh
    out PIT_CHANNEL_0, al

    popa
    ret
