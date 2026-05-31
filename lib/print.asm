; lib/print.asm
; Функция вывода байта в Hex-формате

global print_hex_byte
extern print_char       ; Предполагаем, что его Си-функция печати символа доступна

section .text

; ---------------------------------------------------------
; print_hex_byte
; Переводит байт в ASCII (Hex) и выводит на экран.
; Вход: AL = байт для вывода
;       [esp + 8] = позиция на экране (pos), если передавать по cdecl
; ---------------------------------------------------------
print_hex_byte:
    push ebp
    mov ebp, esp
    push ebx
    push ecx

    mov cl, al              ; Сохраняем исходный байт в CL
    mov ebx, [ebp + 8]      ; EBX = текущая позиция pos на экране

    ; --- Шаг 1: Выводим старшую тетраду (старшие 4 бита) ---
    mov al, cl
    shr al, 4               ; Сдвигаем вправо, оставляя только старшие 4 бита
    call .hex_to_ascii      ; Переводим 0x0..0xF в символ ASCII
    
    ; Вызываем print_char(AL, pos)
    push ebx                ; 2-й аргумент: pos
    movzx eax, al
    push eax                ; 1-й аргумент: символ ASCII
    call print_char
    add esp, 8              ; Выравниваем стек
    inc ebx                 ; Двигаем позицию на 1 символ вперед

    ; --- Шаг 2: Выводим младшую тетраду (младшие 4 бита) ---
    mov al, cl
    and al, 0x0F            ; Сбрасываем старшие биты маской
    call .hex_to_ascii      ; Переводим в ASCII
    
    ; Вызываем print_char(AL, pos)
    push ebx                ; 2-й аргумент: pos
    movzx eax, al
    push eax                ; 1-й аргумент: символ ASCII
    call print_char
    add esp, 8              ; Выравниваем стек
    inc ebx                 ; Двигаем позицию для следующего вывода

    ; Возвращаем новую позицию экрана в EAX (очень удобно для цепочки вывода)
    mov eax, ebx            

    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; --- Вспомогательная микро-функция перевода 4 бит в ASCII ---
.hex_to_ascii:
    cmp al, 10
    jl .is_digit
    add al, 'A' - 10        ; Если это A..F (переводим в буквы)
    ret
.is_digit:
    add al, '0'             ; Если это 0..9 (переводим в цифры)
    ret
