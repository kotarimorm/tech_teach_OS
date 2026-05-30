; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #02 — Real Mode → Protected Mode (32-bit)
;  Режим:    16-bit → 32-bit PM
;  Цель:     Настройка GDT, включение PE, прыжок в PM, VGA вывод
;  Сборка:   nasm boot02_protected.asm -f bin -o boot02.bin
;  Тест:     qemu-system-x86_64 -drive format=raw,file=boot02.bin
; ═══════════════════════════════════════════════════════════════

BITS 16
ORG  0x7C00

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00

; ── Включение линии A20 (Fast A20 через порт 0x92) ──────────
; Без A20 память выше 1MB недоступна — адреса оборачиваются!
    in   al, 0x92
    or   al, 0x02        ; Бит 1: включить A20
    and  al, 0xFE        ; Бит 0: НЕ сбрасываем систему
    out  0x92, al

; ── Загружаем GDT ────────────────────────────────────────────
    lgdt [gdt_descriptor]

; ── Включаем Protected Mode: PE-бит в CR0 ────────────────────
    mov  eax, cr0
    or   eax, 0x1        ; Bit 0 = Protection Enable (PE)
    mov  cr0, eax

; ── Far jump: сбрасывает pipeline и загружает новый CS ───────
; 0x08 = селектор CODE дескриптора (индекс 1 * 8 = 0x08)
    jmp  0x08:pm_entry

; ════════════════════════════════════════════════════════════
;  GDT — Global Descriptor Table
;  Каждый дескриптор = 8 байт
; ════════════════════════════════════════════════════════════
ALIGN 8
gdt_start:

    ; [0] NULL дескриптор — процессор требует первым!
    dq 0x0000000000000000

    ; [1] CODE сегмент — Ring 0, 32-bit, Base=0, Limit=4GB
    ; Байт доступа: Present=1, DPL=00, S=1, Type=1010(Code/Exec/Read)
    ; Флаги:        G=1(4KB гранулярность), D/B=1(32-bit), L=0
    dw 0xFFFF            ; Limit [15:0]
    dw 0x0000            ; Base  [15:0]
    db 0x00              ; Base  [23:16]
    db 10011010b         ; Access: P=1,DPL=00,S=1,Type=1010
    db 11001111b         ; Flags+Limit[19:16]: G=1,D=1,L=0,AVL=0,Lim=F
    db 0x00              ; Base  [31:24]

    ; [2] DATA сегмент — Ring 0, 32-bit, Base=0, Limit=4GB
    ; Type=0010 (Data/Read/Write)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b         ; Access: P=1,DPL=00,S=1,Type=0010
    db 11001111b
    db 0x00

gdt_end:

; GDTR структура
gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Размер GDT - 1
    dd gdt_start                  ; Линейный адрес GDT

; ════════════════════════════════════════════════════════════
;  Protected Mode — 32-bit код
; ════════════════════════════════════════════════════════════
BITS 32
pm_entry:
    ; Грузим DATA селектор во все сегментные регистры
    ; 0x10 = индекс 2 * 8 = 16 = 0x10
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x90000    ; Новый стек выше conventional memory

; ── Прямой вывод в VGA текстовый буфер 0xB8000 ───────────────
; Формат ячейки: [ASCII][Атрибут]
; Атрибут 0x0F = белый символ на чёрном фоне
    mov  edi, 0xB8000

    mov  word [edi + 0],  0x0F50  ; 'P'
    mov  word [edi + 2],  0x0F72  ; 'r'
    mov  word [edi + 4],  0x0F6F  ; 'o'
    mov  word [edi + 6],  0x0F74  ; 't'
    mov  word [edi + 8],  0x0F65  ; 'e'
    mov  word [edi + 10], 0x0F63  ; 'c'
    mov  word [edi + 12], 0x0F74  ; 't'
    mov  word [edi + 14], 0x0F65  ; 'e'
    mov  word [edi + 16], 0x0F64  ; 'd'
    mov  word [edi + 18], 0x0F20  ; ' '
    mov  word [edi + 20], 0x0F4D  ; 'M'
    mov  word [edi + 22], 0x0F6F  ; 'o'
    mov  word [edi + 24], 0x0F64  ; 'd'
    mov  word [edi + 26], 0x0F65  ; 'e'
    mov  word [edi + 28], 0x0F20  ; ' '
    mov  word [edi + 30], 0x0F4F  ; 'O'
    mov  word [edi + 32], 0x0F4B  ; 'K'

.halt:
    cli
    hlt
    jmp .halt

times 510 - ($ - $$) db 0
dw 0xAA55
