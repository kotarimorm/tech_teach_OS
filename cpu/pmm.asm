[bits 32]

PAGE_SIZE   equ 4096
BITMAP_SIZE equ 131072   ; 128 КБ покрывают 4 ГБ памяти (каждый бит = 4 КБ)

section .bss
align 4
memory_bitmap:
    resb BITMAP_SIZE     ; Резервируем 128 КБ неинициализированной памяти

section .text
global pmm_init
global pmm_alloc_page
global pmm_free_page

; ---------------------------------------------------------
; Инициализация: помечаем всю память как свободную (нули)
; В реальной WhaleOS тебе нужно будет изначально пометить 
; занятыми страницы, где лежит само ядро и видеопамять.
; ---------------------------------------------------------
pmm_init:
    pusha
    mov edi, memory_bitmap
    mov ecx, BITMAP_SIZE / 4
    xor eax, eax
    rep stosd            ; Быстро заполняем карту нулями по 4 байта за раз
    popa
    ret

; ---------------------------------------------------------
; Выделение одной страницы (4 КБ)
; Возвращает: EAX = физический адрес страницы (или 0, если памяти нет)
; ---------------------------------------------------------
pmm_alloc_page:
    push ebx
    push ecx
    push edx

    mov ecx, BITMAP_SIZE
    mov esi, memory_bitmap
    xor ebx, ebx         ; EBX будет хранить индекс байта в карте

.find_free_byte:
    cmp ebx, ecx
    jge .out_of_memory   ; Дошли до конца карты, свободной памяти нет

    mov al, [esi + ebx]
    cmp al, 0xFF         ; 0xFF (11111111b) значит все 8 страниц в байте заняты
    jne .find_free_bit   ; Если не 0xFF, значит тут есть свободный бит (0)!

    inc ebx
    jmp .find_free_byte

.find_free_bit:
    ; В AL сейчас наш байт. Ищем первый нулевой бит.
    xor edx, edx         ; EDX = индекс бита (0-7)

.bit_loop:
    bt ax, dx            ; Bit Test: проверяем бит под номером DX
    jnc .found_bit       ; Если Carry Flag = 0 (бит равен 0), мы его нашли!
    inc edx
    cmp edx, 8
    jl .bit_loop

.found_bit:
    ; 1. Помечаем бит как занятый (1)
    bts ax, dx           ; Bit Test and Set: устанавливаем бит в 1
    mov [esi + ebx], al  ; Записываем обновленный байт обратно в карту

    ; 2. Вычисляем физический адрес для возврата
    ; Формула: (Индекс_байта * 8 + Индекс_бита) * 4096
    mov eax, ebx
    shl eax, 3           ; EAX = EBX * 8
    add eax, edx         ; EAX = глобальный номер страницы памяти
    shl eax, 12          ; Сдвиг влево на 12 бит эквивалентен умножению на 4096
    jmp .done

.out_of_memory:
    xor eax, eax         ; Возвращаем 0 (ошибка выделения)

.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------
; Освобождение страницы
; Вход: EAX = физический адрес страницы
; ---------------------------------------------------------
pmm_free_page:
    pusha

    ; Проверка на выравнивание (адрес должен быть строго кратен 4096)
    test eax, 0xFFF
    jnz .done            ; Если младшие 12 бит не нули, это неверный адрес - игнорим

    shr eax, 12          ; EAX = глобальный номер страницы (делим на 4096)
    
    mov ebx, eax
    shr ebx, 3           ; EBX = индекс байта в карте (номер страницы / 8)
    
    mov edx, eax
    and edx, 7           ; EDX = остаток от деления на 8 (индекс бита: 0-7)

    ; Сбрасываем нужный бит
    mov esi, memory_bitmap
    mov al, [esi + ebx]
    btr ax, dx           ; Bit Test and Reset: сбрасываем бит в 0
    mov [esi + ebx], al

.done:
    popa
    ret
