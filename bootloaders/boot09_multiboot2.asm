; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #09 — Multiboot2 Kernel (загружается через GRUB)
;  Режим:    32-bit Protected Mode (GRUB уже переводит в PM!)
;  Цель:     Multiboot2 заголовок, парсинг info структуры,
;            получение framebuffer и карты памяти от GRUB
;  Сборка:   nasm boot09_multiboot2.asm -f elf32 -o kernel.o
;            ld -m elf_i386 -T linker.ld kernel.o -o kernel.elf
;  Запуск:   В grub.cfg: multiboot2 /boot/kernel.elf
; ═══════════════════════════════════════════════════════════════
;
;  linker.ld пример:
;    ENTRY(_start)
;    SECTIONS {
;      . = 0x100000;
;      .multiboot2 : { *(.multiboot2) }
;      .text : { *(.text) }
;      .data : { *(.data) }
;      .bss  : { *(.bss)  }
;    }
; ═══════════════════════════════════════════════════════════════

BITS 32

; ── Multiboot2 константы ─────────────────────────────────────
MB2_MAGIC     equ 0xE85250D6
MB2_ARCH      equ 0              ; i386 Protected Mode
MB2_HDR_LEN   equ (mb2_header_end - mb2_header_start)
MB2_CHECKSUM  equ (0x100000000 - (MB2_MAGIC + MB2_ARCH + MB2_HDR_LEN))

; Типы тегов Multiboot2
MB2_TAG_END         equ 0
MB2_TAG_CMDLINE     equ 1
MB2_TAG_MODULE      equ 3
MB2_TAG_MEMORY_MAP  equ 6
MB2_TAG_FRAMEBUFFER equ 8

; GRUB кладёт в EAX при передаче управления
MB2_BOOTLOADER_MAGIC equ 0x36D76289

; ════════════════════════════════════════════════════════════
;  Multiboot2 Header — должен быть в первых 32KB ядра
;  Выравнивание ОБЯЗАТЕЛЬНО по 8 байт для каждого тега!
; ════════════════════════════════════════════════════════════
section .multiboot2
ALIGN 8
mb2_header_start:
    ; Обязательные поля заголовка
    dd MB2_MAGIC          ; Magic number
    dd MB2_ARCH           ; Architecture
    dd MB2_HDR_LEN        ; Header length
    dd MB2_CHECKSUM       ; Checksum (сумма всех 4 полей = 0)

    ; ── Тег 1: Framebuffer ────────────────────────────────
    ; Просим GRUB переключить видео в нужный режим
    ALIGN 8
    dw 5                  ; Type: framebuffer request
    dw 0                  ; Flags: 0 = optional (не фатально если нет)
    dd 20                 ; Size тега в байтах
    dd 1920               ; Желаемая ширина (0 = любая)
    dd 1080               ; Желаемая высота
    dd 32                 ; Глубина цвета (bpp): 32 = BGRA

    ; ── Тег 2: Выравнивание модулей ───────────────────────
    ALIGN 8
    dw 6                  ; Type: module_align
    dw 0                  ; Flags
    dd 8                  ; Size

    ; ── End tag — обязателен! ─────────────────────────────
    ALIGN 8
    dw MB2_TAG_END        ; Type: 0
    dw 0                  ; Flags
    dd 8                  ; Size
mb2_header_end:

; ════════════════════════════════════════════════════════════
;  Точка входа ядра
; ════════════════════════════════════════════════════════════
section .text
global _start

_start:
    ; GRUB передаёт:
    ;   EAX = MB2_BOOTLOADER_MAGIC (0x36D76289)
    ;   EBX = физический адрес Multiboot2 Information Structure

    ; Проверяем magic — если не совпадает, загрузчик не Multiboot2
    cmp  eax, MB2_BOOTLOADER_MAGIC
    jne  .bad_magic

    ; Сохраняем EBX до инициализации стека (стек может затереть)
    mov  [mb2_info_ptr], ebx

    ; Инициализируем стек
    mov  esp, stack_top

    ; Парсим Multiboot2 Information Structure
    call mb2_parse_info

    ; Инициализируем видео
    call video_init

    ; Входим в основное ядро
    ; call kernel_main

.halt:
    cli
    hlt
    jmp .halt

.bad_magic:
    ; Пишем 'ERR' в VGA text mode (на случай если он есть)
    mov  word [0xB8000], 0x0C45   ; 'E' красным
    mov  word [0xB8002], 0x0C52   ; 'R'
    mov  word [0xB8004], 0x0C52   ; 'R'
    cli
    hlt

; ════════════════════════════════════════════════════════════
;  Парсинг Multiboot2 Info Structure
;  Формат: total_size(4) + reserved(4) + теги...
;  Каждый тег: type(4) + size(4) + данные
; ════════════════════════════════════════════════════════════
mb2_parse_info:
    push esi
    push eax
    push ebx

    mov  esi, [mb2_info_ptr]
    add  esi, 8              ; Пропускаем total_size + reserved

.tag_loop:
    mov  eax, [esi]          ; Тип тега
    cmp  eax, MB2_TAG_END
    je   .done

    cmp  eax, MB2_TAG_FRAMEBUFFER
    je   .parse_fb

    cmp  eax, MB2_TAG_MEMORY_MAP
    je   .parse_mmap

    ; Пропускаем неизвестный тег (size выровнен по 8)
.next_tag:
    mov  ebx, [esi + 4]     ; Размер тега
    add  esi, ebx
    add  esi, 7
    and  esi, 0xFFFFFFF8    ; Выравниваем по 8
    jmp  .tag_loop

.parse_fb:
    ; Framebuffer tag структура:
    ; [0]=type(4) [4]=size(4) [8]=addr(8) [16]=pitch(4)
    ; [20]=width(4) [24]=height(4) [28]=bpp(1) [29]=fb_type(1)
    mov  eax, [esi + 8]     ; framebuffer_addr lo
    mov  [fb_addr], eax
    mov  eax, [esi + 12]    ; framebuffer_addr hi
    mov  [fb_addr_hi], eax
    mov  eax, [esi + 16]    ; framebuffer_pitch (байт на строку)
    mov  [fb_pitch], eax
    mov  eax, [esi + 20]    ; framebuffer_width
    mov  [fb_width], eax
    mov  eax, [esi + 24]    ; framebuffer_height
    mov  [fb_height], eax
    movzx eax, byte [esi + 28]  ; framebuffer_bpp
    mov  [fb_bpp], eax
    jmp  .next_tag

.parse_mmap:
    ; Memory map tag:
    ; [0]=type(4) [4]=size(4) [8]=entry_size(4) [12]=entry_version(4)
    ; [16+] = массив записей
    mov  eax, [esi + 8]     ; entry_size
    mov  [mmap_entry_size], eax
    lea  eax, [esi + 16]    ; Адрес первой записи
    mov  [mmap_addr], eax
    mov  ebx, [esi + 4]     ; Общий размер тега
    sub  ebx, 16            ; Вычитаем заголовок тега
    xor  edx, edx
    div  dword [mmap_entry_size]  ; Количество записей
    mov  [mmap_count], eax
    jmp  .next_tag

.done:
    pop  ebx
    pop  eax
    pop  esi
    ret

; ════════════════════════════════════════════════════════════
;  Инициализация видео
; ════════════════════════════════════════════════════════════
video_init:
    ; Проверяем есть ли framebuffer от GRUB
    cmp  dword [fb_addr], 0
    jne  .use_fb

    ; Нет framebuffer — используем VGA text mode
    mov  edi, 0xB8000
    mov  ecx, 80 * 25
    mov  ax, 0x0720          ; Пробел, серый атрибут
    rep  stosw

    ; Пишем приветствие в VGA text mode
    mov  edi, 0xB8000
    mov  esi, msg_no_fb
.vga_loop:
    lodsb
    test al, al
    jz   .vga_done
    mov  ah, 0x0F            ; Белый атрибут
    stosw
    jmp  .vga_loop
.vga_done:
    ret

.use_fb:
    ; Заливаем framebuffer синим цветом (предполагаем 32bpp BGRA)
    mov  edi, [fb_addr]
    mov  ecx, [fb_width]
    imul ecx, [fb_height]
    mov  eax, 0x00002080     ; BGRA: B=0x80, G=0x20, R=0x00
    rep  stosd

    ; Рисуем белую полосу сверху (высота 40px)
    mov  edi, [fb_addr]
    mov  ecx, [fb_width]
    imul ecx, 40             ; 40 строк
    mov  eax, 0x00FFFFFF     ; Белый
    rep  stosd
    ret

; ════════════════════════════════════════════════════════════
section .data
msg_no_fb   db "Sentinel OS - No framebuffer, VGA mode", 0

section .bss
mb2_info_ptr     resd 1
fb_addr          resd 1
fb_addr_hi       resd 1
fb_pitch         resd 1
fb_width         resd 1
fb_height        resd 1
fb_bpp           resd 1
mmap_addr        resd 1
mmap_count       resd 1
mmap_entry_size  resd 1

ALIGN 16
resb 16384               ; 16KB стек
stack_top:
