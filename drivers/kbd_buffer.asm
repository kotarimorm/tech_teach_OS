; drivers/kbd_buffer.asm
; Кольцевой буфер для клавиатуры (256 байт)

global kbd_buf_push
global kbd_buf_pop

section .bss
    ; Резервируем 256 байт под сам буфер
    kbd_buffer resb 256
    
    ; Указатели на голову (запись) и хвост (чтение)
    kbd_head resd 1
    kbd_tail resd 1

section .text

; ---------------------------------------------------------
; kbd_buf_push
; Добавляет скан-код в буфер. ВЫЗЫВАЕТСЯ ТОЛЬКО ИЗ ПРЕРЫВАНИЯ!
; Вход: AL = скан-код
; ---------------------------------------------------------
kbd_buf_push:
    push ebx
    push ecx

    mov ebx, [kbd_head]       ; Берем текущий индекс записи
    
    ; Вычисляем следующий индекс (head + 1)
    mov ecx, ebx
    inc ecx
    and ecx, 255              ; Магия оптимизации: ecx = ecx % 256
    
    ; Проверка на переполнение: если следующий индекс = хвосту, буфер полон
    cmp ecx, [kbd_tail]
    je .drop                  ; Если полон — просто выбрасываем скан-код

    ; Записываем байт в память
    mov byte [kbd_buffer + ebx], al
    
    ; Сдвигаем голову
    mov [kbd_head], ecx

.drop:
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------
; kbd_buf_pop
; Читает скан-код из буфера. Вызывается из основного цикла kmain.
; Выход: EAX = скан-код, или EAX = -1 (0xFFFFFFFF), если буфер пуст
; ---------------------------------------------------------
kbd_buf_pop:
    push ebx

    mov ebx, [kbd_tail]       ; Берем текущий индекс чтения
    
    ; Проверка на пустоту: если хвост догнал голову — читать нечего
    cmp ebx, [kbd_head]
    je .empty

    ; Читаем байт из буфера
    xor eax, eax              ; Очищаем EAX, чтобы старшие биты были нулями
    mov al, byte [kbd_buffer + ebx]
    
    ; Сдвигаем хвост
    inc ebx
    and ebx, 255              ; ebx = ebx % 256
    mov [kbd_tail], ebx
    
    pop ebx
    ret

.empty:
    mov eax, -1               ; Возвращаем -1, сигнализируя об отсутствии данных
    pop ebx
    ret
