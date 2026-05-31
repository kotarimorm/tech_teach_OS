[bits 32]

; Порты первичного ATA контроллера
ATA_DATA      equ 0x1F0
ATA_SECTOR_CNT equ 0x1F2
ATA_LBA_LOW   equ 0x1F3
ATA_LBA_MID   equ 0x1F4
ATA_LBA_HIGH  equ 0x1F5
ATA_DRIVE_HEAD equ 0x1F6
ATA_COMMAND   equ 0x1F7
ATA_STATUS    equ 0x1F7

; Функция чтения одного сектора (512 байт)
; Вход: eax = номер сектора (LBA), edi = адрес буфера в памяти
ata_read_sector:
    pusha
    
    ; Подготавливаем диск (LBA режим, Master drive)
    mov ebx, eax          ; Сохраняем LBA
    shr eax, 24           ; Достаем старшие 4 бита LBA
    or al, 0xE0           ; 0xE0 = Master drive, LBA mode
    mov dx, ATA_DRIVE_HEAD
    out dx, al
    
    ; Количество секторов для чтения (1 сектор)
    mov dx, ATA_SECTOR_CNT
    mov al, 1
    out dx, al
    
    ; Отправляем адрес LBA (низкие 8 бит)
    mov eax, ebx
    mov dx, ATA_LBA_LOW
    out dx, al
    
    ; Отправляем адрес LBA (средние 8 бит)
    shr eax, 8
    mov dx, ATA_LBA_MID
    out dx, al
    
    ; Отправляем адрес LBA (высокие 8 бит)
    shr eax, 8
    mov dx, ATA_LBA_HIGH
    out dx, al
    
    ; Команда: Чтение секторов (0x20)
    mov dx, ATA_COMMAND
    mov al, 0x20
    out dx, al

.wait_ready:
    ; Ждем, пока диск не выставит флаг готовности (бит 3: DRQ)
    mov dx, ATA_STATUS
    in al, dx
    test al, 8
    jz .wait_ready

    ; Диск готов, читаем 256 слов (512 байт) из порта данных
    mov ecx, 256
    mov dx, ATA_DATA
    rep insw              ; Втягиваем данные прямо по адресу в edi

    popa
    ret
