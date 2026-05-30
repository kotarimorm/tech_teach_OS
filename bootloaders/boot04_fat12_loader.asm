; ═══════════════════════════════════════════════════════════════
;  BOOTLOADER #04 — FAT12 Kernel Loader
;  Режим:    16-bit Real Mode
;  Цель:     Найти KERNEL.BIN на FAT12 дискете, загрузить, запустить
;  Сборка:   nasm boot04_fat12.asm -f bin -o boot04.bin
;  Образ:    dd if=boot04.bin of=disk.img && mcopy -i disk.img kernel.bin ::KERNEL.BIN
; ═══════════════════════════════════════════════════════════════

BITS 16
ORG  0x7C00

; ══ BPB (BIOS Parameter Block) — описание FAT12 дискеты 1.44MB ══
jmp  short main          ; Прыжок через BPB (3 байта: EB XX 90)
nop

; Метаданные файловой системы — строго по стандарту FAT12
bpb_oem_name        db "SENTINEL"   ; 8 байт OEM имя
bpb_bytes_per_sec   dw 512          ; Байт на сектор
bpb_sec_per_clust   db 1            ; Секторов на кластер
bpb_reserved_secs   dw 1            ; Зарезервировано (бутсектор)
bpb_fat_count       db 2            ; Количество копий FAT
bpb_root_entries    dw 224          ; Записей в корневом каталоге
bpb_total_secs      dw 2880         ; Всего секторов (1.44MB)
bpb_media_type      db 0xF0         ; 3.5" флоппи
bpb_secs_per_fat    dw 9            ; Секторов на FAT
bpb_secs_per_track  dw 18           ; Секторов на дорожке
bpb_num_heads       dw 2            ; Голов
bpb_hidden_secs     dd 0
bpb_large_secs      dd 0
bpb_drive_num       db 0            ; 0 = флоппи
bpb_reserved        db 0
bpb_boot_sig        db 0x29         ; Расширенная подпись
bpb_vol_id          dd 0xDEAD1337
bpb_vol_label       db "SENTINEL OS"  ; 11 байт
bpb_fs_type         db "FAT12   "     ; 8 байт

; ════════════════════════════════════════════════════════════
main:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti

    mov  [bpb_drive_num], dl     ; BIOS кладёт номер диска в DL

; ── Загружаем Root Directory в 0x0200 ────────────────────────
; Root Dir начинается после: Reserved(1) + FAT*2(9*2=18) = сектор 19
; Размер Root Dir: 224 записи * 32 байта / 512 = 14 секторов
    mov  ax, 19                  ; LBA первого сектора Root Dir
    mov  bx, 0x0200              ; Буфер → ES:BX = 0x0000:0x0200
    mov  cx, 14                  ; Читаем 14 секторов
    call read_sectors

; ── Ищем "KERNEL  BIN" в Root Directory ──────────────────────
; Каждая запись каталога = 32 байта, имя = 11 байт в формате 8.3
    mov  cx, 224                 ; Максимум записей
    mov  di, 0x0200             ; Начало Root Dir

.search:
    push cx
    push di
    mov  si, kernel_filename     ; "KERNEL  BIN"
    mov  cx, 11
    repe cmpsb                   ; Сравниваем 11 байт имени
    pop  di
    pop  cx
    je   .found
    add  di, 32                  ; Следующая запись
    loop .search

    ; Файл не найден
    mov  si, err_no_kernel
    call print_str
    jmp  .halt

.found:
    ; DI указывает на начало найденной записи
    ; Смещение 26 = поле FirstCluster (первый кластер файла)
    mov  ax, [di + 26]           ; AX = первый кластер ядра

; ── Загружаем FAT таблицу в 0x0200+14*512 = 0x1C00 ──────────
    push ax
    mov  ax, 1                   ; FAT начинается с сектора 1
    mov  bx, 0x1C00
    mov  cx, 9                   ; 9 секторов FAT
    call read_sectors
    pop  ax

; ── Читаем ядро по цепочке кластеров FAT12 ───────────────────
; Data Area начинается с сектора 33 (после Root Dir)
    mov  bx, 0x1000              ; Сегмент для ядра
    mov  es, bx
    xor  bx, bx                  ; Смещение = 0 → физически 0x10000

.load_cluster:
    push ax
    call cluster_to_lba          ; Переводим кластер → LBA
    push es
    push bx
    mov  cx, 1
    call read_sectors_es         ; Читаем в ES:BX
    pop  bx
    pop  es
    add  bx, 512                 ; Следующий буфер
    pop  ax
    call fat12_next              ; Следующий кластер из FAT
    cmp  ax, 0xFF8               ; >= 0xFF8 = конец файла (EOC)
    jb   .load_cluster

; ── Передаём управление ядру ──────────────────────────────────
    mov  dl, [bpb_drive_num]
    jmp  0x1000:0x0000           ; Прыжок в ядро!

.halt:
    cli
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════
;  Кластер → LBA
;  IN:  AX = номер кластера
;  OUT: AX = LBA сектор
; ════════════════════════════════════════════════════════════
cluster_to_lba:
    sub  ax, 2                   ; Кластеры начинаются с 2
    xor  cx, cx
    mov  cl, [bpb_sec_per_clust]
    mul  cx                      ; AX = (cluster-2) * SectorsPerCluster
    add  ax, 33                  ; + начало Data Area (= 19+14)
    ret

; ════════════════════════════════════════════════════════════
;  Следующий кластер в цепочке FAT12
;  IN:  AX = текущий кластер
;  OUT: AX = следующий кластер (>= 0xFF8 = конец)
;  FAT12 хранит 12-bit значения, упакованные попарно
; ════════════════════════════════════════════════════════════
fat12_next:
    mov  bx, ax
    shr  bx, 1                   ; BX = cluster / 2
    add  bx, ax                  ; BX = cluster * 3/2 (смещение в FAT)
    mov  ax, [bx + 0x1C00]      ; Читаем 2 байта из FAT
    ; Чётные кластеры: биты [11:0], нечётные: биты [15:4]
    test ax, 1                   ; Нечётный кластер?
    jz   .even
    shr  ax, 4                   ; Нечётный: сдвигаем на 4
    ret
.even:
    and  ax, 0x0FFF              ; Чётный: маска нижних 12 бит
    ret

; ════════════════════════════════════════════════════════════
;  Чтение секторов через INT 13h (с CHS конвертацией)
;  IN: AX=LBA, BX=буфер (DS:BX), CX=количество
; ════════════════════════════════════════════════════════════
read_sectors:
    push es
    push ds
    pop  es
    call read_sectors_es
    pop  es
    ret

read_sectors_es:
    push ax
    push bx
    push cx
    push dx
.retry:
    ; LBA → CHS
    push ax
    push cx
    xor  dx, dx
    div  word [bpb_secs_per_track]
    inc  dx
    mov  cl, dl                  ; CL = сектор (1-based)
    xor  dx, dx
    div  word [bpb_num_heads]
    mov  dh, dl                  ; DH = головка
    mov  ch, al                  ; CH = цилиндр [7:0]
    shl  ah, 6
    or   cl, ah                  ; CL[7:6] = цилиндр [9:8]
    mov  dl, [bpb_drive_num]
    pop  cx
    pop  ax

    mov  ah, 0x02                ; INT 13h: Read Sectors
    int  0x13
    jnc  .done
    ; Ошибка — сбрасываем и повторяем
    xor  ah, ah                  ; INT 13h: Reset Drive
    int  0x13
    jmp  .retry

.done:
    pop  dx
    pop  cx
    ; Переходим к следующему сектору
    inc  ax                      ; LBA++
    add  bx, 512                 ; Буфер += 512
    loop .retry_check            ; Если CX > 1, ещё раз — упрощённо
    pop  bx
    pop  ax
    ret
.retry_check:
    jmp  .retry                  ; (CX уже декрементирован loop-ом)

; ════════════════════════════════════════════════════════════
print_str:
    lodsb
    test al, al
    jz   .done
    mov  ah, 0x0E
    int  0x10
    jmp  print_str
.done:
    ret

; ── Данные ───────────────────────────────────────────────────
kernel_filename  db "KERNEL  BIN"   ; 8+3 формат FAT (пробелами дополнен!)
err_no_kernel    db "KERNEL.BIN not found!", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55
