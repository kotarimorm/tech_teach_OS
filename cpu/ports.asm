[bits 32]

; Макрос записи байта (8 бит) в порт
; Использование: OUTB 0x60, al
%macro OUTB 2
    mov dx, %1      ; Порт всегда в DX
    mov al, %2      ; Данные всегда в AL
    out dx, al
%endmacro

; Макрос чтения байта (8 бит) из порта
; Использование: INB 0x60 (результат будет в AL)
%macro INB 1
    mov dx, %1
    in al, dx
%endmacro

; Макрос записи слова (16 бит) в порт (нужно для ATA драйвера)
; Использование: OUTW 0x1F0, ax
%macro OUTW 2
    mov dx, %1
    mov ax, %2
    out dx, ax
%endmacro

; Макрос чтения слова (16 бит) из порта
; Использование: INW 0x1F0 (результат будет в AX)
%macro INW 1
    mov dx, %1
    in ax, dx
%endmacro

; Небольшая задержка для старого железа (ждём, пока порт ответит)
; Часто используется при ремаппинге PIC
%macro IO_WAIT 0
    out 0x80, al    ; Пишем мусор в неиспользуемый порт
%endmacro
