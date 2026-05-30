[bits 32]

VIDEO_MEMORY equ 0xB8000
WHITE_ON_BLACK equ 0x0F ; Цветовой атрибут: белый текст на черном фоне
COLS equ 80
ROWS equ 25

section .data
cursor_offset dd 0

section .text
; Функция очистки экрана
vga_clear_screen:
    pusha
    mov edi, VIDEO_MEMORY
    mov ecx, COLS * ROWS
    mov ax, 0x0F20       ; 0x20 = пробел, 0x0F = белый на черном
    rep stosw            ; Заливаем память пробелами
    mov dword [cursor_offset], 0
    popa
    ret

; Функция печати строки, оканчивающейся нулем
; Вход: esi = адрес строки
vga_print_string:
    pusha
    mov edi, VIDEO_MEMORY
    add edi, [cursor_offset]
    mov ah, WHITE_ON_BLACK

.loop:
    lodsb                ; Читаем байт из [esi] в al
    test al, al          ; Проверяем на ноль (конец строки)
    jz .done
    
    stosw                ; Пишем ax (ah = цвет, al = символ) по адресу edi
    add dword [cursor_offset], 2
    jmp .loop

.done:
    popa
    ret
