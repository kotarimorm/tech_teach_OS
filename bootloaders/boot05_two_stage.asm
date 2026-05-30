; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #05 — Two-Stage Loader
;  Stage1: MBR (512 байт) — только читает Stage2
;  Stage2: до 32KB — E820 карта памяти, PM, загрузка ядра
;  Сборка:
;    nasm boot05_stage1.asm -f bin -o stage1.bin
;    nasm boot05_stage2.asm -f bin -o stage2.bin
;    cat stage1.bin stage2.bin > disk.img
; ═══════════════════════════════════════════════════════════════

; ╔══════════════════════════════════════╗
; ║  STAGE 1  (boot05_stage1.asm)        ║
; ╚══════════════════════════════════════╝

BITS 16
ORG  0x7C00

stage1:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    ; Сохраняем диск — BIOS передаёт в DL
    mov  [drive], dl

    mov  si, msg_s1
    call print16

; ── Загружаем Stage2: 16 секторов начиная с LBA 1 → по 0x0500 ─
; Используем INT 13h Extended (AH=42h) — работает с LBA, нет ограничений CHS
    mov  ah, 0x42
    mov  dl, [drive]
    mov  si, dap
    int  0x13
    jc   .err

    ; Передаём DL в Stage2 через память
    mov  al, [drive]
    mov  [0x0500 + stage2_drive_offset], al

    jmp  0x0000:0x0500           ; Запускаем Stage2!

.err:
    mov  si, msg_err
    call print16
    cli
    hlt

print16:
    lodsb
    test al, al
    jz   .d
    mov  ah, 0x0E
    int  0x10
    jmp  print16
.d: ret

; ── Disk Address Packet (DAP) для INT 13h Extended ───────────
dap:
    db   0x10          ; Размер DAP = 16 байт
    db   0x00          ; Зарезервировано
    dw   16            ; Читаем 16 секторов (8KB) — хватит для Stage2
    dw   0x0500        ; Буфер: смещение
    dw   0x0000        ; Буфер: сегмент → 0x0000:0x0500
    dq   1             ; Начальный LBA = 1 (сразу за MBR)

drive         db 0
msg_s1        db "S1 OK", 0x0D, 0x0A, 0
msg_err       db "S1 READ ERR", 0x0D, 0x0A, 0

; Stage2 ожидает свой диск по этому смещению от 0x0500
stage2_drive_offset equ 0x1FF   ; Последний байт зоны 0x0500–0x06FF

times 510 - ($ - $$) db 0
dw 0xAA55


; ╔══════════════════════════════════════╗
; ║  STAGE 2  (boot05_stage2.asm)        ║
; ╚══════════════════════════════════════╝
; --- Это отдельный файл, ORG 0x0500 ---

; BITS 16
; ORG  0x0500
;
; [Начало Stage2 - вставить код ниже как отдельный файл boot05_stage2.asm]

%ifndef STAGE1_ONLY

BITS 16
ORG  0x0500

stage2:
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00

    mov  si, msg_s2
    call print16

; ── E820: собираем карту физической памяти ───────────────────
; КРИТИЧНО: ядро должно знать где RAM, где ROM, где MMIO
; Запись E820: Base(8) + Length(8) + Type(4) + Attrs(4) = 24 байта
; Type 1 = Usable RAM, 2 = Reserved, 3 = ACPI, 4 = ACPI NVS

    mov  di, mmap_buf    ; Куда пишем записи
    xor  ebx, ebx        ; EBX=0 для первого вызова
    xor  bp, bp          ; BP = счётчик записей

.e820_loop:
    mov  eax, 0xE820
    mov  edx, 0x534D4150 ; Сигнатура "SMAP"
    mov  ecx, 24         ; Размер записи (24 байта с ACPI 3.0 полем)
    int  0x15
    jc   .e820_done      ; CF=1: ошибка или конец списка
    cmp  eax, 0x534D4150
    jne  .e820_done      ; Неверная сигнатура
    jcxz .e820_next      ; Нулевая длина записи — пропуск
    inc  bp
    add  di, 24
.e820_next:
    test ebx, ebx
    jz   .e820_done      ; EBX=0 после последней записи
    jmp  .e820_loop
.e820_done:
    mov  [mmap_count], bp
    mov  si, msg_mmap
    call print16

; ── A20 Enable ───────────────────────────────────────────────
    in   al, 0x92
    or   al, 0x02
    and  al, 0xFE
    out  0x92, al

; ── Загрузка ядра: сектора 32-96 (32KB) → 0x1000:0x0000 ─────
    mov  ah, 0x42
    mov  dl, [drive2]
    lea  si, [kernel_dap]
    int  0x13
    jc   .kernel_err
    mov  si, msg_kernel_ok
    call print16

; ── Переходим в Protected Mode → Long Mode ───────────────────
    lgdt [gdt32_ptr]
    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax
    jmp  0x08:pm32

.kernel_err:
    mov  si, msg_kernel_err
    call print16
    cli
    hlt

; ════════════════════════════════════════════════════════════
BITS 32
pm32:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  esp, 0x7FF00

    ; Карта памяти: передаём ядру через регистры
    ; ESI = адрес mmap_buf, ECX = количество записей
    mov  esi, mmap_buf
    movzx ecx, word [mmap_count]

    ; Прыгаем в ядро по адресу 0x10000 (0x1000:0x0000)
    jmp  0x00010000

; ════════════════════════════════════════════════════════════
BITS 16
print16:
    lodsb
    test al, al
    jz   .d
    mov  ah, 0x0E
    int  0x10
    jmp  print16
.d: ret

; ── Данные Stage2 ────────────────────────────────────────────
kernel_dap:
    db  0x10
    db  0x00
    dw  64               ; 64 сектора = 32KB
    dw  0x0000           ; Смещение
    dw  0x1000           ; Сегмент → физически 0x10000
    dq  32               ; LBA 32 = начало ядра на диске

drive2      db 0x80      ; HDD (Stage1 запишет сюда реальный диск)

msg_s2          db "Stage2 OK", 0x0D, 0x0A, 0
msg_mmap        db "Memory map collected", 0x0D, 0x0A, 0
msg_kernel_ok   db "Kernel loaded", 0x0D, 0x0A, 0
msg_kernel_err  db "Kernel load FAILED!", 0

mmap_count  dw 0

; ── GDT для PM ───────────────────────────────────────────────
ALIGN 8
gdt32:
    dq 0
    dw 0xFFFF, 0, 0, 10011010b | (11001111b << 8)   ; Code
    dw 0xFFFF, 0, 0, 10010010b | (11001111b << 8)   ; Data
gdt32_end:
gdt32_ptr:
    dw gdt32_end - gdt32 - 1
    dd gdt32

section .bss
mmap_buf resb 24 * 32    ; Буфер для 32 записей E820

%endif
