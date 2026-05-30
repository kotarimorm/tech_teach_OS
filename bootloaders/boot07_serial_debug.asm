; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #07 — Serial/UART Debug Bootloader
;  Режим:    16-bit Real Mode → 32-bit Protected Mode
;  Цель:     Отладочный вывод через COM1 на всех этапах загрузки
;  COM1:     Порты 0x3F8-0x3FF, 115200 baud, 8N1
;  Сборка:   nasm boot07_serial.asm -f bin -o boot07.bin
;  Тест:     qemu-system-x86_64 -drive format=raw,file=boot07.bin -serial stdio
; ═══════════════════════════════════════════════════════════════

BITS 16
ORG  0x7C00

; ── Определения портов COM1 ──────────────────────────────────
COM1_BASE  equ 0x3F8
COM1_DATA  equ COM1_BASE + 0   ; Data Register (DLAB=0: данные)
COM1_IER   equ COM1_BASE + 1   ; Interrupt Enable (DLAB=0)
COM1_FCR   equ COM1_BASE + 2   ; FIFO Control Register
COM1_LCR   equ COM1_BASE + 3   ; Line Control Register (содержит DLAB бит)
COM1_MCR   equ COM1_BASE + 4   ; Modem Control Register
COM1_LSR   equ COM1_BASE + 5   ; Line Status Register
COM1_DIVLO equ COM1_BASE + 0   ; Divisor Low  (DLAB=1)
COM1_DIVHI equ COM1_BASE + 1   ; Divisor High (DLAB=1)

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

; ── Инициализация UART 115200 baud 8N1 ───────────────────────
    call uart_init

; ── Отладочные сообщения в Real Mode ─────────────────────────
    mov  si, msg_rm_start
    call uart_puts

    ; Печатаем адрес загрузки в hex
    mov  si, msg_load_addr
    call uart_puts
    mov  ax, 0x7C00
    call uart_hex16
    call uart_crlf

    ; Печатаем значение SP
    mov  si, msg_sp
    call uart_puts
    mov  ax, sp
    call uart_hex16
    call uart_crlf

; ── Показываем работу с портами ──────────────────────────────
    mov  si, msg_a20
    call uart_puts
    in   al, 0x92
    or   al, 0x02
    and  al, 0xFE
    out  0x92, al
    mov  si, msg_ok
    call uart_puts

; ── Загружаем GDT и переходим в PM ───────────────────────────
    mov  si, msg_gdt
    call uart_puts
    lgdt [gdt_ptr]
    mov  si, msg_ok
    call uart_puts

    mov  si, msg_entering_pm
    call uart_puts

    mov  eax, cr0
    or   eax, 0x1
    mov  cr0, eax
    jmp  0x08:pm_entry

; ════════════════════════════════════════════════════════════
;  UART ФУНКЦИИ
; ════════════════════════════════════════════════════════════

; uart_init — инициализация COM1, 115200 baud, 8N1
uart_init:
    ; 1. Отключаем прерывания UART (пишем в IER)
    mov  dx, COM1_IER
    xor  al, al
    out  dx, al

    ; 2. Устанавливаем DLAB=1 для доступа к делителю
    mov  dx, COM1_LCR
    mov  al, 0x80            ; DLAB bit
    out  dx, al

    ; 3. Делитель = 1 → baudrate = 115200
    ;    Формула: divisor = 115200 / baudrate
    ;    115200 / 115200 = 1
    mov  dx, COM1_DIVLO
    mov  al, 1               ; Низкий байт делителя
    out  dx, al
    mov  dx, COM1_DIVHI
    xor  al, al              ; Высокий байт = 0
    out  dx, al

    ; 4. Формат 8N1: 8 бит данных, нет parity, 1 стоп-бит, DLAB=0
    ;    LCR: bit[1:0]=11(8bit), bit2=0(1stop), bit[4:3]=00(no parity)
    mov  dx, COM1_LCR
    mov  al, 0x03
    out  dx, al

    ; 5. Включаем FIFO буфер, очищаем, порог = 14 байт
    mov  dx, COM1_FCR
    mov  al, 0xC7            ; Enable + Clear RX/TX + 14-byte threshold
    out  dx, al

    ; 6. Modem Control: DTR + RTS + Out2 (Out2 нужен для IRQ)
    mov  dx, COM1_MCR
    mov  al, 0x0B
    out  dx, al
    ret

; uart_putc — отправить один символ
; IN: AL = символ
uart_putc:
    push ax
    push dx
.wait:
    ; Ждём пока бит 5 (THRE = Transmit Holding Register Empty) = 1
    mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .wait
    pop  dx
    pop  ax
    mov  dx, COM1_DATA
    out  dx, al
    ret

; uart_puts — отправить строку (нуль-терминированную)
; IN: SI = адрес строки
uart_puts:
    push ax
.loop:
    lodsb
    test al, al
    jz   .done
    call uart_putc
    jmp  .loop
.done:
    pop  ax
    ret

; uart_crlf — отправить CR+LF
uart_crlf:
    mov  al, 0x0D
    call uart_putc
    mov  al, 0x0A
    call uart_putc
    ret

; uart_hex16 — вывести AX как "0xXXXX"
; IN: AX = число
uart_hex16:
    push bx
    push cx
    push ax
    ; Пишем "0x"
    mov  al, '0'
    call uart_putc
    mov  al, 'x'
    call uart_putc
    ; 4 нибла, от старшего к младшему
    pop  ax
    push ax
    mov  cx, 4
.loop:
    ; Берём старший нибл
    mov  bx, ax
    and  bx, 0xF000
    shr  bx, 12
    mov  al, bl
    add  al, '0'
    cmp  al, '9'+1
    jb   .ok
    add  al, 7               ; 'A'-'9'-1 = 7
.ok:
    call uart_putc
    shl  ax, 4               ; Следующий нибл
    loop .loop
    pop  ax
    pop  cx
    pop  bx
    ret

; uart_hex8 — вывести AL как "XX"
uart_hex8:
    push ax
    push ax
    shr  al, 4               ; Старший нибл
    and  al, 0x0F
    add  al, '0'
    cmp  al, '9'+1
    jb   .hi_ok
    add  al, 7
.hi_ok:
    call uart_putc
    pop  ax
    and  al, 0x0F            ; Младший нибл
    add  al, '0'
    cmp  al, '9'+1
    jb   .lo_ok
    add  al, 7
.lo_ok:
    call uart_putc
    pop  ax
    ret

; ════════════════════════════════════════════════════════════
;  GDT
; ════════════════════════════════════════════════════════════
ALIGN 8
gdt_start:
    dq 0
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00   ; Code 32-bit
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00   ; Data 32-bit
gdt_end:
gdt_ptr:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ════════════════════════════════════════════════════════════
;  Protected Mode — продолжаем слать через UART (порты те же!)
; ════════════════════════════════════════════════════════════
BITS 32
pm_entry:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  esp, 0x90000

    ; В PM порты ввода-вывода те же — UART работает без изменений!
    ; Просто пишем напрямую в порт

    ; Ждём THRE
.wait_thre:
    mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .wait_thre

    ; Шлём строку "PM OK\r\n" побайтово
    mov  dx, COM1_DATA
    mov  al, 'P'
    out  dx, al
.w2: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w2
    mov  dx, COM1_DATA
    mov  al, 'M'
    out  dx, al
.w3: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w3
    mov  dx, COM1_DATA
    mov  al, ' '
    out  dx, al
.w4: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w4
    mov  dx, COM1_DATA
    mov  al, 'O'
    out  dx, al
.w5: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w5
    mov  dx, COM1_DATA
    mov  al, 'K'
    out  dx, al
.w6: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w6
    mov  dx, COM1_DATA
    mov  al, 0x0D
    out  dx, al
.w7: mov  dx, COM1_LSR
    in   al, dx
    and  al, 0x20
    jz   .w7
    mov  dx, COM1_DATA
    mov  al, 0x0A
    out  dx, al

.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
BITS 16
; Строки для отладки
msg_rm_start   db "[SENTINEL] Real Mode start", 0x0D, 0x0A, 0
msg_load_addr  db "[SENTINEL] Load addr: ", 0
msg_sp         db "[SENTINEL] Stack ptr: ", 0
msg_a20        db "[SENTINEL] Enabling A20... ", 0
msg_gdt        db "[SENTINEL] Loading GDT... ", 0
msg_entering_pm db "[SENTINEL] Entering Protected Mode!", 0x0D, 0x0A, 0
msg_ok         db "OK", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55
