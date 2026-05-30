; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #10 — UEFI + GOP Framebuffer (Pure NASM, no EDK2)
;  Режим:    64-bit Long Mode (UEFI уже в LM — не надо переходить!)
;  Цель:     Найти GOP, получить framebuffer, залить экран, передать ядру
;  Сборка:   nasm boot10_uefi.asm -f win64 -o boot10.obj
;            lld-link /subsystem:efi_application /entry:efi_main \
;                     /out:BOOTX64.EFI boot10.obj
;  Установка: Скопировать BOOTX64.EFI → ESP:/EFI/BOOT/BOOTX64.EFI
; ═══════════════════════════════════════════════════════════════
;
;  ВАЖНО: UEFI использует Windows x64 ABI (не System V!):
;    - Параметры: RCX, RDX, R8, R9, остальные на стеке
;    - Shadow space: 32 байта ПЕРЕД вызовом (caller резервирует)
;    - Стек выровнен по 16 байт перед CALL
;    - Callee сохраняет: RBX, RBP, RDI, RSI, R12-R15, XMM6-XMM15
; ═══════════════════════════════════════════════════════════════

BITS 64

; ── EFI статусы ──────────────────────────────────────────────
EFI_SUCCESS              equ 0
EFI_UNSUPPORTED          equ 0x8000000000000003
EFI_NOT_FOUND            equ 0x800000000000000E

; ── Смещения в EFI_SYSTEM_TABLE (из UEFI Spec 2.9) ──────────
ST_FIRMWARE_VENDOR       equ 8    ; CHAR16*
ST_FIRMWARE_REVISION     equ 16   ; UINT32
ST_CONSOLE_IN_HANDLE     equ 24   ; EFI_HANDLE
ST_CON_IN                equ 32   ; EFI_SIMPLE_TEXT_INPUT*
ST_CONSOLE_OUT_HANDLE    equ 40   ; EFI_HANDLE
ST_CON_OUT               equ 48   ; EFI_SIMPLE_TEXT_OUTPUT* ← используем
ST_STD_ERR_HANDLE        equ 56
ST_STD_ERR               equ 64
ST_RUNTIME_SERVICES      equ 72   ; EFI_RUNTIME_SERVICES*
ST_BOOT_SERVICES         equ 80   ; EFI_BOOT_SERVICES* ← используем

; ── Смещения в EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL ───────────────
STOP_RESET               equ 0    ; Reset()
STOP_OUTPUT_STRING       equ 8    ; OutputString() ← используем
STOP_TEST_STRING         equ 16
STOP_QUERY_MODE          equ 24
STOP_SET_MODE            equ 32
STOP_SET_ATTRIBUTE       equ 40
STOP_CLEAR_SCREEN        equ 48   ; ClearScreen() ← используем

; ── Смещения в EFI_BOOT_SERVICES ─────────────────────────────
; (полная таблица: UEFI Spec Table 7-1)
BS_RAISE_TPL             equ 0
BS_RESTORE_TPL           equ 8
BS_ALLOCATE_PAGES        equ 16
BS_FREE_PAGES            equ 24
BS_GET_MEMORY_MAP        equ 32   ; GetMemoryMap() ← используем
BS_ALLOCATE_POOL         equ 40
BS_FREE_POOL             equ 48
; ... (пропускаем неиспользуемые) ...
BS_LOCATE_PROTOCOL       equ 320  ; LocateProtocol() ← используем
BS_LOCATE_HANDLES_BY_PROTO equ 312

; ── Смещения в EFI_GRAPHICS_OUTPUT_PROTOCOL ──────────────────
GOP_QUERY_MODE           equ 0    ; QueryMode()
GOP_SET_MODE             equ 8    ; SetMode()
GOP_BLT                  equ 16   ; Blt() (Block Transfer)
GOP_MODE                 equ 24   ; *EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE

; ── Смещения в EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE ─────────────
GOPM_MAX_MODE            equ 0    ; UINT32 — количество режимов
GOPM_MODE                equ 4    ; UINT32 — текущий режим
GOPM_INFO                equ 8    ; *EFI_GRAPHICS_OUTPUT_MODE_INFORMATION
GOPM_INFO_SIZE           equ 16   ; UINTN
GOPM_FB_BASE             equ 24   ; EFI_PHYSICAL_ADDRESS — адрес framebuffer
GOPM_FB_SIZE             equ 32   ; UINTN — размер framebuffer

; ── Смещения в EFI_GRAPHICS_OUTPUT_MODE_INFORMATION ──────────
GOMI_VERSION             equ 0
GOMI_HORIZ_RES           equ 4    ; ширина в пикселях
GOMI_VERT_RES            equ 8    ; высота в пикселях
GOMI_PIXEL_FORMAT        equ 12   ; EFI_GRAPHICS_PIXEL_FORMAT
GOMI_PIXELS_PER_SCANLINE equ 28   ; может быть > ширины (padding)

; ── EFI_GRAPHICS_PIXEL_FORMAT значения ───────────────────────
PixelRedGreenBlueReserved8BitPerColor equ 0   ; RGBX
PixelBlueGreenRedReserved8BitPerColor equ 1   ; BGRX ← самый частый
PixelBitMask                          equ 2
PixelBltOnly                          equ 3

; ── BLT операции ─────────────────────────────────────────────
EfiBltVideoFill          equ 2    ; Заливка прямоугольника цветом

section .text
global efi_main

; ════════════════════════════════════════════════════════════
;  efi_main — точка входа UEFI приложения
;  IN: RCX = EFI_HANDLE ImageHandle
;      RDX = EFI_SYSTEM_TABLE* SystemTable
; ════════════════════════════════════════════════════════════
efi_main:
    ; Сохраняем callee-saved регистры (Windows x64 ABI)
    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 32             ; Shadow space для наших вызовов

    ; Сохраняем параметры в callee-saved регистрах
    mov  rbx, rcx            ; ImageHandle
    mov  r12, rdx            ; SystemTable

; ── Очищаем экран ────────────────────────────────────────────
    mov  rax, [r12 + ST_CON_OUT]   ; ConOut
    mov  rcx, rax                   ; this
    call qword [rax + STOP_CLEAR_SCREEN]

; ── Выводим приветствие через ConOut.OutputString ────────────
; OutputString(this, CHAR16* string)
    mov  rax, [r12 + ST_CON_OUT]
    mov  rcx, rax
    lea  rdx, [rel msg_banner]
    call qword [rax + STOP_OUTPUT_STRING]

; ── Получаем GOP через BootServices.LocateProtocol ───────────
; LocateProtocol(GUID*, Registration*, Interface**)
    mov  rax, [r12 + ST_BOOT_SERVICES]
    mov  rcx, rax                          ; BootServices (для вызова)
    ; Нет, LocateProtocol — это функция, не метод интерфейса через "this"
    ; Правильно: вызываем через указатель в таблице BootServices
    lea  rcx, [rel gop_guid]              ; EFI_GUID*
    xor  rdx, rdx                          ; Registration = NULL
    lea  r8,  [rel gop_interface]         ; OUT: *Interface
    mov  rax, [r12 + ST_BOOT_SERVICES]
    call qword [rax + BS_LOCATE_PROTOCOL]

    cmp  rax, EFI_SUCCESS
    jne  .gop_failed

    ; Сохраняем GOP interface
    mov  r13, [gop_interface]

; ── Читаем информацию о текущем режиме ───────────────────────
    mov  rax, [r13 + GOP_MODE]             ; Mode pointer
    mov  r14, rax

    ; Читаем framebuffer base адрес
    mov  rax, [r14 + GOPM_FB_BASE]
    mov  [fb_base], rax

    ; Читаем размер framebuffer
    mov  rax, [r14 + GOPM_FB_SIZE]
    mov  [fb_size], rax

    ; Читаем Info структуру
    mov  rax, [r14 + GOPM_INFO]            ; *EFI_GRAPHICS_OUTPUT_MODE_INFORMATION
    mov  eax, [rax + GOMI_HORIZ_RES]
    mov  [fb_width], eax
    mov  rax, [r14 + GOPM_INFO]
    mov  eax, [rax + GOMI_VERT_RES]
    mov  [fb_height], eax
    mov  rax, [r14 + GOPM_INFO]
    mov  eax, [rax + GOMI_PIXELS_PER_SCANLINE]
    mov  [fb_stride], eax

; ── Выводим размер framebuffer ────────────────────────────────
    mov  rax, [r12 + ST_CON_OUT]
    mov  rcx, rax
    lea  rdx, [rel msg_fb_found]
    call qword [rax + STOP_OUTPUT_STRING]

; ── Заливаем весь экран тёмно-синим через BLT ────────────────
; GOP.Blt(this, BltBuffer, BltOp, SrcX, SrcY, DstX, DstY, W, H, Delta)
; При EfiBltVideoFill: BltBuffer = один пиксель-образец
    mov  rax, r13                          ; GOP interface
    sub  rsp, 48                           ; Место для параметров 5-10 на стеке
    ; Windows x64: 5й параметр и дальше на стеке (после shadow space)
    ; shadow space уже зарезервировано, пишем с [rsp+32]
    mov  qword [rsp + 32], 0              ; DstX = 0
    mov  qword [rsp + 40], 0              ; DstY = 0
    ; W и H — через стек тоже (>4 параметров)
    ; ... упрощение: используем прямую запись в framebuffer

    add  rsp, 48

; ── Прямая запись в framebuffer (проще чем BLT) ──────────────
    mov  rdi, [fb_base]
    mov  ecx, [fb_width]
    imul ecx, [fb_height]

    ; Определяем формат пикселя и выбираем цвет
    ; Большинство систем — BGRX (Blue, Green, Red, Reserved)
    mov  eax, 0x00204080     ; BGRX: B=0x80, G=0x40, R=0x20 (синий)
    rep  stosd               ; Заливаем весь экран

; ── Рисуем белую полосу заголовка (первые 60px) ──────────────
    mov  rdi, [fb_base]
    mov  ecx, [fb_width]
    imul ecx, 60             ; 60 строк
    mov  eax, 0x00CCCCCC     ; Светло-серый
    rep  stosd

; ── Рисуем красную полосу снизу (последние 40px) ─────────────
    mov  rdi, [fb_base]
    mov  eax, [fb_height]
    sub  eax, 40
    imul eax, [fb_stride]    ; stride строк * 4 байта/пиксель
    shl  eax, 2
    add  rdi, rax            ; Указатель на начало последних 40 строк
    mov  ecx, [fb_width]
    imul ecx, 40
    mov  eax, 0x00002080     ; Красноватый BGRX
    rep  stosd

    jmp  .halt

.gop_failed:
    ; GOP не найден — пишем сообщение об ошибке
    mov  rax, [r12 + ST_CON_OUT]
    mov  rcx, rax
    lea  rdx, [rel msg_gop_fail]
    call qword [rax + STOP_OUTPUT_STRING]

.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
section .data

; EFI_GRAPHICS_OUTPUT_PROTOCOL GUID
; {0x9042A9DE, 0x23DC, 0x4A38, {0x96,0xFB,0x7A,0xDE,0xD0,0x80,0x51,0x6A}}
gop_guid:
    dd 0x9042A9DE
    dw 0x23DC
    dw 0x4A38
    db 0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A

; UCS-2 строки (UEFI требует 16-bit Unicode!)
msg_banner:
    dw 'S','e','n','t','i','n','e','l',' ','O','S',' ','U','E','F','I'
    dw ' ','B','o','o','t','l','o','a','d','e','r'
    dw 0x000D, 0x000A, 0

msg_fb_found:
    dw 'F','r','a','m','e','b','u','f','f','e','r',':',' ','O','K'
    dw 0x000D, 0x000A, 0

msg_gop_fail:
    dw 'E','R','R','O','R',':',' ','G','O','P',' ','n','o','t',' ','f','o','u','n','d','!'
    dw 0x000D, 0x000A, 0

; Цвет для BLT операции (EFI_GRAPHICS_OUTPUT_BLT_PIXEL)
; Структура: Blue(1) + Green(1) + Red(1) + Reserved(1)
blt_color_blue:
    db 0x80, 0x20, 0x00, 0x00   ; Тёмно-синий

section .bss
gop_interface resq 1
fb_base       resq 1
fb_size       resq 1
fb_width      resd 1
fb_height     resd 1
fb_stride     resd 1
