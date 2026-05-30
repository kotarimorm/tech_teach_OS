; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #03 — Full Long Mode (64-bit)
;  Режим:    16-bit → 32-bit PM → 64-bit Long Mode
;  Цель:     Полная цепочка переходов, Identity Paging первых 2MB
;  Сборка:   nasm boot03_longmode.asm -f bin -o boot03.bin
;  Тест:     qemu-system-x86_64 -drive format=raw,file=boot03.bin
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

; ── A20 Enable ───────────────────────────────────────────────
    in   al, 0x92
    or   al, 0x02
    and  al, 0xFE
    out  0x92, al

; ── CPUID: проверяем поддержку Long Mode ─────────────────────
    mov  eax, 0x80000000     ; Запрашиваем максимальный extended CPUID
    cpuid
    cmp  eax, 0x80000001    ; Поддерживается ли 0x80000001?
    jb   .no_long_mode

    mov  eax, 0x80000001    ; Extended CPUID: Feature bits
    cpuid
    bt   edx, 29            ; Бит 29 = Long Mode (LM)
    jnc  .no_long_mode      ; Нет поддержки LM

; ── Загружаем 64-bit GDT ─────────────────────────────────────
    lgdt [gdt64_ptr]

; ── Включаем PM ──────────────────────────────────────────────
    mov  eax, cr0
    or   eax, 0x1
    mov  cr0, eax
    jmp  0x08:pm32_setup    ; Far jump в 32-bit код

.no_long_mode:
    mov  si, err_no_lm
.print:
    lodsb
    test al, al
    jz   .halt
    mov  ah, 0x0E
    int  0x10
    jmp  .print
.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
;  GDT для Long Mode (ключевой бит L=1 в CODE дескрипторе)
; ════════════════════════════════════════════════════════════
ALIGN 8
gdt64_start:
    dq 0                    ; NULL

    ; CODE 64-bit: L=1 (бит 53) — это обязательно для Long Mode!
    ; D=0 (бит 54 должен быть 0 когда L=1)
    dw 0xFFFF               ; Limit (игнорируется в LM, но ставим)
    dw 0x0000               ; Base
    db 0x00
    db 10011010b            ; P=1, DPL=0, S=1, Type=1010
    db 10101111b            ; G=1, D=0, L=1 ← Long Mode!, Limit[19:16]=F
    db 0x00

    ; DATA: в LM сегменты почти не используются, но SS нужен
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

err_no_lm db "ERROR: CPU does not support Long Mode!", 0

; ════════════════════════════════════════════════════════════
;  32-bit PM: настройка страниц и переход в LM
; ════════════════════════════════════════════════════════════
BITS 32
pm32_setup:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  esp, 0x7C00

; ── Очищаем 16KB под таблицы страниц (0x1000–0x4FFF) ────────
    mov  edi, 0x1000
    xor  eax, eax
    mov  ecx, 0x1000         ; 4096 DWORD = 16KB
    rep  stosd               ; Заполняем нулями

; ── Строим Identity Map первых 2MB ───────────────────────────
;  Структура: PML4[0] → PDPT[0] → PD[0] → 2MB huge page
;
;  Адреса таблиц:
;    PML4 = 0x1000
;    PDPT = 0x2000
;    PD   = 0x3000
;
;  Флаги записей: Present(bit 0) + Writable(bit 1)
;  Для Huge Page в PD: добавляем PageSize(bit 7)

    ; PML4[0] → PDPT @ 0x2000
    mov  dword [0x1000], 0x2003      ; 0x2000 | Present | Writable

    ; PDPT[0] → PD @ 0x3000
    mov  dword [0x2000], 0x3003      ; 0x3000 | Present | Writable

    ; PD[0] → Huge Page 2MB @ физический адрес 0x000000
    ; Флаг 0x83 = Present(1) + Writable(2) + PageSize(128)
    mov  dword [0x3000], 0x000083

; ── Загружаем PML4 в CR3 ─────────────────────────────────────
    mov  eax, 0x1000
    mov  cr3, eax

; ── Включаем PAE (Physical Address Extension) ────────────────
; Обязательно ПЕРЕД включением Long Mode!
    mov  eax, cr4
    or   eax, (1 << 5)      ; CR4.PAE = 1
    mov  cr4, eax

; ── Включаем Long Mode через MSR EFER ────────────────────────
; EFER = Extended Feature Enable Register, MSR 0xC0000080
    mov  ecx, 0xC0000080
    rdmsr                    ; EDX:EAX = EFER
    or   eax, (1 << 8)      ; EFER.LME = Long Mode Enable
    wrmsr

; ── Включаем Paging → активируется Long Mode ─────────────────
    mov  eax, cr0
    or   eax, (1 << 31)     ; CR0.PG = Paging Enable
    mov  cr0, eax

; ── Far jump в 64-bit код ────────────────────────────────────
    jmp  0x08:lm_entry

; ════════════════════════════════════════════════════════════
;  64-bit Long Mode Entry
; ════════════════════════════════════════════════════════════
BITS 64
lm_entry:
    ; Обновляем сегменты (DATA = 0x10)
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    xor  ax, ax
    mov  fs, ax              ; FS/GS = 0 (для TLS используем MSR)
    mov  gs, ax
    mov  rsp, 0x90000        ; 64-bit стек

; ── Вывод в VGA: "LM 64 OK" ──────────────────────────────────
    mov  rdi, 0xB8000
    ; Цвет 0x02 = зелёный, пишем строку побайтово
    mov  byte [rdi + 0],  'L'
    mov  byte [rdi + 1],  0x0A   ; Зелёный атрибут
    mov  byte [rdi + 2],  'M'
    mov  byte [rdi + 3],  0x0A
    mov  byte [rdi + 4],  ' '
    mov  byte [rdi + 5],  0x0A
    mov  byte [rdi + 6],  '6'
    mov  byte [rdi + 7],  0x0A
    mov  byte [rdi + 8],  '4'
    mov  byte [rdi + 9],  0x0A
    mov  byte [rdi + 10], '-'
    mov  byte [rdi + 11], 0x0A
    mov  byte [rdi + 12], 'b'
    mov  byte [rdi + 13], 0x0A
    mov  byte [rdi + 14], 'i'
    mov  byte [rdi + 15], 0x0A
    mov  byte [rdi + 16], 't'
    mov  byte [rdi + 17], 0x0A
    mov  byte [rdi + 18], ' '
    mov  byte [rdi + 19], 0x0A
    mov  byte [rdi + 20], 'O'
    mov  byte [rdi + 21], 0x0A
    mov  byte [rdi + 22], 'K'
    mov  byte [rdi + 23], 0x02   ; Финальный атрибут

.halt:
    cli
    hlt
    jmp .halt

times 510 - ($ - $$) db 0
dw 0xAA55
