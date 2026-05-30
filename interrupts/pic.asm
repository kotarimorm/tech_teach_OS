[bits 32]

PIC1_COMMAND equ 0x20
PIC1_DATA    equ 0x21
PIC2_COMMAND equ 0xA0
PIC2_DATA    equ 0xA1

remap_pic:
    ; ICW1: начало инициализации
    mov al, 0x11
    out PIC1_COMMAND, al
    call io_wait
    out PIC2_COMMAND, al
    call io_wait

    ; ICW2: смещение векторов (Мастер = 0x20, Слейв = 0x28)
    mov al, 0x20
    out PIC1_DATA, al
    call io_wait
    mov al, 0x28
    out PIC2_DATA, al
    call io_wait

    ; ICW3: настройка каскадирования
    mov al, 0x04
    out PIC1_DATA, al
    call io_wait
    mov al, 0x02
    out PIC2_DATA, al
    call io_wait

    ; ICW4: режим 8086/88
    mov al, 0x01
    out PIC1_DATA, al
    call io_wait
    out PIC2_DATA, al
    call io_wait

    ; Временно маскируем все аппаратные прерывания
    mov al, 0xFF
    out PIC1_DATA, al
    out PIC2_DATA, al
    ret
    
; Искусственная задержка для медленных I/O портов старого железа
io_wait:
    out 0x80, al
    ret
