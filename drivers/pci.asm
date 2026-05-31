; drivers/pci.asm
; PCI Bus Scanner on Pure Assembly (NASM)

global pci_scan_bus
extern devman_device_reg

section .text

; ---------------------------------------------------------
; pci_scan_bus
; Сканирует всю PCI-шину (256 шин, 32 слота, 8 функций)
; и регистрирует найденные устройства.
; ---------------------------------------------------------
pci_scan_bus:
    push ebp
    mov ebp, esp
    push bgx                    ; Сохраняем регистры согласно cdecl
    push esi
    push edi

    ; Выделяем локальную переменную под структуру device_desc на стеке
    ; struct device_desc { uint32_t type; uint32_t class; uint32_t subclass; }
    ; Это займет 12 байт (3 dword)
    sub esp, 12                 
    %define LOCAL_DESC_TYPE     ebp - 24
    %define LOCAL_DESC_CLASS    ebp - 20
    %define LOCAL_DESC_SUBCLASS ebp - 16

    ; Инициализируем циклы
    xor edi, edi                ; EDI = bus (0 .. 255)

.loop_bus:
    xor esi, esi                ; ESI = slot (0 .. 31)

.loop_slot:
    xor ecx, ecx                ; ECX = func (0 .. 7)

.loop_func:
    ; Читаем Vendor ID и Device ID (смещение 0)
    xor edx, edx                ; смещение = 0
    call pci_read_dword
    
    mov bx, ax                  ; AX = Vendor ID
    cmp bx, 0xFFFF              ; Если Vendor ID == 0xFFFF, устройства нет
    je .next_func

    ; Устройство найдено! Читаем регистр класса (смещение 0x08)
    mov edx, 0x08
    call pci_read_dword         ; EAX = Class, Subclass, ProgIF, Revision

    ; Парсим класс и подкласс
    mov edx, eax
    shr edx, 24                 ; DL = Class Code
    mov [LOCAL_DESC_CLASS], edx
    
    mov edx, eax
    shr edx, 16
    and edx, 0xFF               ; DL = Subclass
    mov [LOCAL_DESC_SUBCLASS], edx

    mov dword [LOCAL_DESC_TYPE], 2 ; Наш кастомный тип 2 (PCI-устройство)

    ; Кодируем data (pci_address): (bus << 16) | (slot << 8) | func
    mov edx, edi
    shl edx, 16
    mov eax, esi
    shl eax, 8
    or edx, eax
    or edx, ecx                 ; EDX = упакованный адрес PCI железа

    ; Вызываем Си-функцию: devman_device_reg(&d_desc, data)
    ; Передаем аргументы через стек (справа налево)
    push edx                    ; 2-й аргумент: void* data (наш EDX)
    lea eax, [LOCAL_DESC_TYPE]  ; EAX = указатель на созданную структуру на стеке
    push eax                    ; 1-й аргумент: struct device_desc* desc
    
    call devman_device_reg      ; Прыгаем в его менеджер девайсов!
    add esp, 8                  ; Очищаем стек после вызова (cdecl)

.next_func:
    inc ecx
    cmp ecx, 8
    jl .loop_func

    inc esi
    cmp esi, 32
    jl .loop_slot

    inc edi
    cmp edi, 256
    jl .loop_bus

    ; Восстанавливаем всё обратно
    add esp, 12                 ; Убираем структуру со стека
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ---------------------------------------------------------
; pci_read_dword
; Вход: EDI = bus, ESI = slot, ECX = func, EDX = offset
; Выход: EAX = 32-битное значение из конфигурационного пространства
; ---------------------------------------------------------
pci_read_dword:
    push ebx
    push edx

    ; Формируем Configuration Address:
    ; Bit 31 = Enable (1)
    ; Bits 23-16 = Bus
    ; Bits 15-11 = Slot
    ; Bits 10-8  = Func
    ; Bits 7-2   = Offset (выровненный по 4 байтам)
    
    mov eax, 1
    shl eax, 31                 ; Сеттим 31-й бит (Enable bit)

    mov ebx, edi
    shl ebx, 16
    or eax, ebx                 ; Добавляем Bus

    mov ebx, esi
    shl ebx, 11
    or eax, ebx                 ; Добавляем Slot

    mov ebx, ecx
    shl ebx, 8
    or eax, ebx                 ; Добавляем Func

    and edx, 0xFC               ; Выравниваем смещение по границе 4 байт
    or eax, edx                 ; Добавляем Offset

    ; Шлем адрес в CONFIG_ADDRESS (0xCF8)
    mov dx, 0xCF8
    out dx, eax

    ; Читаем данные из CONFIG_DATA (0xCFC)
    mov dx, 0xCFC
    in eax, dx

    pop edx
    pop ebx
    ret
