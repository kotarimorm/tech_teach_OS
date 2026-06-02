; ============================================================
; PURE PCI SCANNER (NO C, NO EXTERNAL CALLS)
; NASM x86, CF8/CFC
; ============================================================

section .text
global pci_scan_bus

pci_scan_bus:

    push ebp
    mov ebp, esp

    push ebx
    push esi
    push edi

    xor edi, edi            ; bus = 0

; ============================================================
.bus_loop:
    xor esi, esi            ; slot = 0

; ============================================================
.slot_loop:
    xor ebx, ebx            ; function = 0

; ============================================================
.func_loop:

    ; --------------------------------------------------------
    ; READ VENDOR ID (0x00)
    ; --------------------------------------------------------
    mov edx, 0x00
    call pci_read_dword

    cmp eax, 0xFFFFFFFF
    je .next_function

    ; --------------------------------------------------------
    ; READ CLASS (0x08)
    ; --------------------------------------------------------
    mov edx, 0x08
    call pci_read_dword

    mov ecx, eax

    shr eax, 24              ; class
    mov [class_buf], eax

    mov eax, ecx
    shr eax, 16
    and eax, 0xFF
    mov [subclass_buf], eax

    ; --------------------------------------------------------
    ; HERE YOU CAN:
    ; - log to screen
    ; - store in table
    ; - ignore completely
    ; --------------------------------------------------------

.next_function:
    inc ebx
    cmp ebx, 8
    jl .func_loop

.next_slot:
    inc esi
    cmp esi, 32
    jl .slot_loop

.next_bus:
    inc edi
    cmp edi, 256
    jl .bus_loop

    pop edi
    pop esi
    pop ebx

    mov esp, ebp
    pop ebp
    ret


; ============================================================
; pci_read_dword (PURE HARDWARE ACCESS)
; IN:
;   EDI = bus
;   ESI = slot
;   EBX = function
;   EDX = offset
; OUT:
;   EAX = value
; ============================================================

pci_read_dword:
    push ebx
    push ecx

    mov eax, 0x80000000

    ; bus
    mov ecx, edi
    and ecx, 0xFF
    shl ecx, 16
    or eax, ecx

    ; slot
    mov ecx, esi
    and ecx, 0x1F
    shl ecx, 11
    or eax, ecx

    ; function
    mov ecx, ebx
    and ecx, 0x07
    shl ecx, 8
    or eax, ecx

    ; offset
    and edx, 0xFC
    or eax, edx

    mov dx, 0xCF8
    out dx, eax

    mov dx, 0xCFC
    in eax, dx

    pop ecx
    pop ebx
    ret


; ============================================================
; SIMPLE STORAGE (optional)
; ============================================================

section .bss
class_buf:     resd 1
subclass_buf:  resd 1
