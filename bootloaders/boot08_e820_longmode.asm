; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #08 — E820 Memory Map + Long Mode (64-bit)
;  Режим:    16-bit → 64-bit Long Mode
;  Цель:     Собрать карту физической памяти через BIOS E820,
;            перейти в Long Mode, передать карту ядру через RDI/RSI
;  Сборка:   nasm boot08_e820_lm.asm -f bin -o boot08.bin
;  Тест:     qemu-system-x86_64 -drive format=raw,file=boot08.bin
; ═══════════════════════════════════════════════════════════════

BITS 16
ORG  0x7C00

; E820 запись: Base(8 байт) + Length(8 байт) + Type(4 байта) + Attrs(4 байта) = 24 байта
; Type: 1=Usable RAM, 2=Reserved, 3=ACPI Reclaimable, 4=ACPI NVS, 5=Bad RAM
E820_ENTRY_SIZE equ 24
MMAP_BUFFER     equ 0x0500    ; Куда пишем записи (выше IVT/BDA)
MAX_ENTRIES     equ 32

start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

; ── Шаг 1: E820 — карта физической памяти ────────────────────
; КРИТИЧЕСКИ важно! Без карты памяти ядро не знает где RAM,
; где MMIO, где ACPI таблицы и т.д.
    mov  si, msg_e820
    call print16

    mov  di, MMAP_BUFFER     ; ES:DI = буфер для записей
    xor  ebx, ebx            ; EBX = 0 (первый вызов)
    xor  bp,  bp             ; BP = счётчик записей

.e820_loop:
    ; INT 15h, EAX=0xE820 — запрос следующей записи карты памяти
    mov  eax, 0xE820
    mov  edx, 0x534D4150     ; "SMAP" — сигнатура
    mov  ecx, E820_ENTRY_SIZE
    int  0x15

    ; CF=1 означает ошибку или конец списка
    jc   .e820_done

    ; Проверяем что BIOS вернул правильную сигнатуру
    cmp  eax, 0x534D4150
    jne  .e820_done

    ; Пропускаем записи с нулевой длиной (некоторые BIOSы шлют мусор)
    mov  eax, [es:di + 8]    ; Length low 32 бита
    or   eax, [es:di + 12]   ; Length high 32 бита
    jz   .e820_skip

    ; Запись валидна — принимаем
    inc  bp                  ; Счётчик++
    add  di, E820_ENTRY_SIZE ; DI → следующая запись

    ; Защита от переполнения буфера
    cmp  bp, MAX_ENTRIES
    jge  .e820_done

.e820_skip:
    ; EBX=0 после последней записи
    test ebx, ebx
    jz   .e820_done
    jmp  .e820_loop

.e820_done:
    ; Сохраняем количество записей прямо перед буфером
    mov  [mmap_count], bp

    ; Выводим количество найденных регионов
    mov  si, msg_mmap_count
    call print16
    mov  ax, bp
    call print_dec16
    call print_crlf

; ── Шаг 2: Включение A20 ─────────────────────────────────────
    in   al, 0x92
    or   al, 0x02
    and  al, 0xFE
    out  0x92, al

; ── Шаг 3: Проверка Long Mode через CPUID ────────────────────
    mov  eax, 0x80000000
    cpuid
    cmp  eax, 0x80000001
    jb   .no_lm

    mov  eax, 0x80000001
    cpuid
    bt   edx, 29             ; LM бит
    jnc  .no_lm

; ── Шаг 4: Загружаем 64-bit GDT ──────────────────────────────
    lgdt [gdt64_ptr]

; ── Шаг 5: Включаем Protected Mode ──────────────────────────
    mov  eax, cr0
    or   eax, 0x1
    mov  cr0, eax
    jmp  0x08:setup_paging   ; Far jump в 32-bit код

.no_lm:
    mov  si, err_no_lm
    call print16
    cli
    hlt

; ════════════════════════════════════════════════════════════
;  32-bit PM: настраиваем страничную адресацию
; ════════════════════════════════════════════════════════════
BITS 32
setup_paging:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  esp, 0x7C00

; ── Очищаем 4 таблицы страниц по 4KB = 16KB начиная с 0x10000 ─
    mov  edi, 0x10000
    xor  eax, eax
    mov  ecx, (0x4000 / 4)   ; 16384 dword
    rep  stosd

; ── Строим Identity Map первых 4MB (два huge page по 2MB) ─────
;  Таблицы:
;    PML4 @ 0x10000
;    PDPT @ 0x11000
;    PD   @ 0x12000
;
;  Identity map значит: виртуальный адрес == физический адрес
;  Это нужно чтобы код продолжал работать после включения paging

    ; PML4[0] → PDPT @ 0x11000 | Present | Writable
    mov  dword [0x10000], 0x11003

    ; PDPT[0] → PD @ 0x12000 | Present | Writable
    mov  dword [0x11000], 0x12003

    ; PD[0] → Huge Page 0MB-2MB | Present | Writable | PageSize(2MB)
    mov  dword [0x12000], 0x000083   ; Флаги: P=1, W=1, PS=1

    ; PD[1] → Huge Page 2MB-4MB
    mov  dword [0x12008], 0x200083   ; Base = 0x200000 (2MB)

; ── CR3 = адрес PML4 ─────────────────────────────────────────
    mov  eax, 0x10000
    mov  cr3, eax

; ── CR4.PAE = 1 (Physical Address Extension) ─────────────────
    mov  eax, cr4
    or   eax, (1 << 5)
    mov  cr4, eax

; ── EFER.LME = 1 (Long Mode Enable) ─────────────────────────
    mov  ecx, 0xC0000080     ; EFER MSR номер
    rdmsr                    ; EDX:EAX = EFER
    or   eax, (1 << 8)       ; LME bit
    wrmsr

; ── CR0.PG = 1 → Long Mode активируется! ─────────────────────
    mov  eax, cr0
    or   eax, (1 << 31)
    mov  cr0, eax

; ── Far jump в 64-bit код ────────────────────────────────────
    jmp  0x08:long_mode_entry

; ════════════════════════════════════════════════════════════
;  64-bit Long Mode
; ════════════════════════════════════════════════════════════
BITS 64
long_mode_entry:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    xor  ax, ax
    mov  fs, ax
    mov  gs, ax
    mov  rsp, 0x90000

; ── Передаём карту памяти ядру ───────────────────────────────
; Соглашение: передаём через регистры (System V AMD64 ABI)
; RDI = указатель на массив E820 записей
; RSI = количество записей
    mov  rdi, MMAP_BUFFER
    movzx rsi, word [mmap_count]

; ── Показываем что мы в LM — пишем в VGA ─────────────────────
    mov  rax, 0xB8000
    mov  byte [rax + 0],  'L'
    mov  byte [rax + 1],  0x0A    ; Зелёный
    mov  byte [rax + 2],  'M'
    mov  byte [rax + 3],  0x0A
    mov  byte [rax + 4],  '6'
    mov  byte [rax + 5],  0x0A
    mov  byte [rax + 6],  '4'
    mov  byte [rax + 7],  0x0A
    mov  byte [rax + 8],  ' '
    mov  byte [rax + 9],  0x0A
    mov  byte [rax + 10], 'O'
    mov  byte [rax + 11], 0x0A
    mov  byte [rax + 12], 'K'
    mov  byte [rax + 13], 0x0A

    ; Здесь вызов ядра: call kernel_main
    ; kernel_main(E820_entry* mmap, uint64_t count)

.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
BITS 16

; print16 — вывод строки через BIOS
print16:
    lodsb
    test al, al
    jz   .d
    mov  ah, 0x0E
    int  0x10
    jmp  print16
.d: ret

print_crlf:
    mov  al, 0x0D
    mov  ah, 0x0E
    int  0x10
    mov  al, 0x0A
    int  0x10
    ret

; Вывод AX как десятичного числа (до 5 цифр)
print_dec16:
    push bx
    push cx
    push dx
    mov  bx, 10
    xor  cx, cx
.div_loop:
    xor  dx, dx
    div  bx
    push dx
    inc  cx
    test ax, ax
    jnz  .div_loop
.print_loop:
    pop  ax
    add  al, '0'
    mov  ah, 0x0E
    int  0x10
    loop .print_loop
    pop  dx
    pop  cx
    pop  bx
    ret

; ── GDT для Long Mode ────────────────────────────────────────
ALIGN 8
gdt64_start:
    dq 0                          ; NULL
    ; Code 64-bit: L=1 обязателен!
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 10101111b, 0x00
    ; Data
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt64_end:
gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

; ── Данные ───────────────────────────────────────────────────
mmap_count    dw 0
msg_e820      db "Collecting memory map (E820)...", 0x0D, 0x0A, 0
msg_mmap_count db "Memory regions found: ", 0
err_no_lm     db "ERROR: Long Mode not supported!", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55
