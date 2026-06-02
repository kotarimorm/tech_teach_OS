; PCI Bus Scanner - Production Grade (NASM x86)

global pci_scan_bus
extern devman_device_reg

section .text

pci_scan_bus:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    
    ; After push: ebp-16 is first available local storage
    ; struct pci_dev { uint32_t type; uint32_t class; uint32_t subclass; ... }
    sub esp, 32
    
    %define DESC_TYPE       [ebp - 20]
    %define DESC_CLASS      [ebp - 24]
    %define DESC_SUBCLASS   [ebp - 28]
    
    xor edi, edi                ; EDI = bus counter (0-255)
.bus_loop:
    xor esi, esi                ; ESI = slot counter (0-31)
.slot_loop:
    ; Use EBX for function counter (non-volatile register per cdecl)
    xor ebx, ebx                ; EBX = function counter (0-7)
.func_loop:
    mov edx, 0x00               ; Offset: Vendor ID / Device ID
    mov ecx, ebx                ; Pass function number to pci_read_dword
    call pci_read_dword
    
    cmp eax, 0xFFFFFFFF
    je .func_absent
    
    ; Device found, read header type and class code at offset 0x08
    mov edx, 0x08
    mov ecx, ebx
    call pci_read_dword
    mov edx, eax                ; Save for multi-function check
    
    ; Extract class code from bits 31:24
    mov eax, edx
    shr eax, 24
    mov DESC_CLASS, eax
    
    ; Extract subclass from bits 23:16
    mov eax, edx
    shr eax, 16
    and eax, 0xFF
    mov DESC_SUBCLASS, eax
    
    ; Set device type
    mov dword DESC_TYPE, 2      ; Type 2 = PCI device
    
    ; Save offset 0x08 value across C function call (may be clobbered)
    push edx
    
    ; Build BDF address for C function (compact format)
    ; BDF = (bus << 8) | (slot << 3) | func
    mov eax, edi
    shl eax, 8                  ; Bus at bits 15:8
    mov edx, esi
    shl edx, 3                  ; Slot at bits 7:3
    or eax, edx
    or eax, ebx                 ; Function at bits 2:0
    
    ; Call device manager with cdecl calling convention
    push eax                    ; Argument 2: BDF address
    lea eax, DESC_TYPE
    push eax                    ; Argument 1: &device_descriptor
    call devman_device_reg
    add esp, 8                  ; Clean up C function arguments
    
    pop edx                     ; Restore offset 0x08 value
    
    ; Multi-function device check (only for function 0)
    cmp ebx, 0
    jne .func_next
    
    ; Extract header type from bits 23:16 of register 0x08
    shr edx, 16
    test dl, 0x80               ; Test multi-function bit (bit 7)
    jnz .func_next              ; If set, scan functions 1-7
    jmp .slot_next              ; If not set, skip to next slot
    
.func_absent:
    ; No device at this function position
    cmp ebx, 0
    jne .func_next              ; Not function 0, continue to next function
    jmp .slot_next              ; Function 0 missing, entire slot is empty
    
.func_next:
    inc ebx
    cmp ebx, 8
    jl .func_loop
    
.slot_next:
    inc esi
    cmp esi, 32
    jl .slot_loop
    
.bus_next:
    inc edi
    cmp edi, 256
    jl .bus_loop
    
    ; Cleanup and return
    add esp, 32
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ==========================================================================
; pci_read_dword
; 
; Read 32-bit value from PCI configuration space
; 
; Input:  EDI = bus number (0-255)
;         ESI = slot/device (0-31)
;         ECX = function (0-7)
;         EDX = register offset (must be dword-aligned)
; 
; Output: EAX = configuration data
; 
; Note: EBX is non-volatile, so we save/restore it
; ==========================================================================
pci_read_dword:
    push ebx
    push edx
    
    ; Build CONFIG_ADDRESS value
    mov eax, 1
    shl eax, 31                 ; Enable bit
    
    mov ebx, edi
    shl ebx, 16                 ; Bus number at bits 23:16
    or eax, ebx
    
    mov ebx, esi
    shl ebx, 11                 ; Device/Slot at bits 15:11
    or eax, ebx
    
    mov ebx, ecx
    shl ebx, 8                  ; Function at bits 10:8
    or eax, ebx
    
    and edx, 0xFC               ; Register offset at bits 7:2
    or eax, edx
    
    ; Write address to CONFIG_ADDRESS port 0xCF8
    mov dx, 0xCF8
    out dx, eax
    
    ; Read data from CONFIG_DATA port 0xCFC
    mov dx, 0xCFC
    in eax, dx
    
    pop edx
    pop ebx
    ret
