; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #06 — VGA Mode 13h (320x200, 256 цветов)
;  Режим:    16-bit Real Mode
;  Цель:     Переключение в графический режим, рисование пикселей,
;            линий и прямоугольников напрямую через видеопамять
;  Сборка:   nasm boot06_vga13h.asm -f bin -o boot06.bin
;  Тест:     qemu-system-x86_64 -drive format=raw,file=boot06.bin
; ═══════════════════════════════════════════════════════════════

BITS 16
ORG  0x7C00

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

; ── Переключение в VGA Mode 13h ──────────────────────────────
; INT 10h: AH=0 (Set Video Mode), AL=0x13 (320x200x8bpp)
; После этого вызова: ES:0xA000 = линейный framebuffer
    mov  ax, 0x0013
    int  0x10

; ── ES = 0xA000 (сегмент видеопамяти VGA) ────────────────────
    mov  ax, 0xA000
    mov  es, ax

; ── Заливка всего экрана тёмно-синим (цвет 0x01) ─────────────
; В Mode 13h: 1 байт = 1 пиксель, индекс в палитре 0-255
; Стандартные цвета: 0=чёрный, 1=синий, 4=красный, 0xF=белый
    xor  di, di              ; DI = 0 (начало видеопамяти)
    mov  al, 0x01            ; Синий
    mov  cx, 320 * 200       ; Всего пикселей
    rep  stosb               ; ES:[DI++] = AL, повторяем CX раз

; ── Рисуем белый прямоугольник (рамка экрана) ────────────────
; Параметры: X=10, Y=10, W=300, H=180, цвет=0x0F (белый)
    mov  bx, 10              ; X
    mov  dx, 10              ; Y
    mov  cx, 300             ; Ширина
    mov  si, 180             ; Высота
    mov  al, 0x0F            ; Белый
    call draw_rect

; ── Рисуем красный прямоугольник внутри ──────────────────────
    mov  bx, 60
    mov  dx, 50
    mov  cx, 200
    mov  si, 100
    mov  al, 0x04            ; Красный
    call draw_rect

; ── Рисуем жёлтую горизонтальную линию по центру ─────────────
    mov  bx, 10              ; X start
    mov  dx, 100             ; Y = центр экрана
    mov  cx, 300             ; Длина
    mov  al, 0x0E            ; Жёлтый
    call draw_hline

; ── Рисуем зелёную диагональ ─────────────────────────────────
    mov  bx, 10              ; X start
    mov  dx, 10              ; Y start
    mov  cx, 180             ; Количество точек
    mov  al, 0x02            ; Зелёный
.diag:
    call put_pixel
    inc  bx
    inc  dx
    loop .diag

; ── Бесконечный цикл ─────────────────────────────────────────
.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
;  ФУНКЦИИ РИСОВАНИЯ
; ════════════════════════════════════════════════════════════

; put_pixel — рисует один пиксель
; IN: BX=x (0-319), DX=y (0-199), AL=цвет, ES=0xA000
put_pixel:
    push di
    push ax
    push dx
    mov  di, dx              ; DI = y
    imul di, 320             ; DI = y * 320 (байт на строку)
    add  di, bx              ; DI = y*320 + x
    stosb                    ; ES:[DI] = AL (пиксель)
    pop  dx
    pop  ax
    pop  di
    ret

; draw_hline — горизонтальная линия
; IN: BX=x, DX=y, CX=длина, AL=цвет
draw_hline:
    push di
    push cx
    push ax
    mov  di, dx
    imul di, 320
    add  di, bx              ; DI = начало строки y на позиции x
    rep  stosb               ; Заливаем CX пикселей
    pop  ax
    pop  cx
    pop  di
    ret

; draw_vline — вертикальная линия
; IN: BX=x, DX=y, CX=высота, AL=цвет
draw_vline:
    push di
    push cx
.loop:
    call put_pixel
    inc  dx                  ; Y++
    loop .loop
    pop  cx
    pop  di
    ret

; draw_rect — заполненный прямоугольник
; IN: BX=x, DX=y, CX=ширина, SI=высота, AL=цвет
draw_rect:
    push si
    push dx
    push ax
.row:
    test si, si
    jz   .done
    push cx
    mov  di, dx
    imul di, 320
    add  di, bx
    rep  stosb               ; Рисуем строку
    pop  cx
    inc  dx                  ; Следующая строка
    dec  si
    jmp  .row
.done:
    pop  ax
    pop  dx
    pop  si
    ret

times 510 - ($ - $$) db 0
dw 0xAA55
