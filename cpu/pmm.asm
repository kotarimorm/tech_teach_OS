; ============================================================
; File: cpu/pmm.asm
; Topic: Physical Memory Manager
; Type: Reference snippet
;
; Purpose:
;   Demonstrates a simple bitmap-based physical page allocator.
;
; Assumes:
;   - 32-bit protected mode
;   - 4 KiB page size
;   - Caller provides a safe memory environment
;
; WARNING:
;   This is a learning PMM.
;   It does not parse BIOS/E820/UEFI memory maps.
;   It does not automatically reserve kernel memory.
;   It does not automatically reserve the bitmap itself.
;   It may treat reserved or device memory as free unless adapted.
;
; Notes:
;   - Mark kernel, stack, modules, MMIO, and reserved regions as used.
;   - Do not use this unchanged in a real kernel memory subsystem.
; ============================================================
[bits 32]

PAGE_SIZE   equ 4096
BITMAP_SIZE equ 131072      ; 128 KB bitmap -> 4 GB physical memory

section .bss
align 4

memory_bitmap:
    resb BITMAP_SIZE

section .text

global pmm_init
global pmm_alloc_page
global pmm_free_page


; ---------------------------------------------------------
; Clear bitmap
; 0 = free
; 1 = used
; ---------------------------------------------------------

pmm_init:
    pusha
    cld

    mov edi, memory_bitmap
    xor eax, eax
    mov ecx, BITMAP_SIZE / 4
    rep stosd

    popa
    ret


; ---------------------------------------------------------
; Allocate one 4KB page
;
; Return:
;   EAX = physical address
;   EAX = 0 if out of memory
; ---------------------------------------------------------

pmm_alloc_page:
    push ebx
    push ecx
    push edx
    push esi

    mov esi, memory_bitmap
    xor ebx, ebx

.find_byte:

    cmp ebx, BITMAP_SIZE
    jae .out_of_memory

    mov al, [esi + ebx]

    cmp al, 0FFh
    jne .find_bit

    inc ebx
    jmp .find_byte


.find_bit:

    xor edx, edx

.bit_loop:

    mov ecx, 1
    shl ecx, dl

    test al, cl
    jz .found

    inc edx
    cmp edx, 8
    jl .bit_loop

    inc ebx
    jmp .find_byte


.found:

    ; mark page as used

    or al, cl
    mov [esi + ebx], al

    ; page_index = byte_index * 8 + bit_index

    mov eax, ebx
    shl eax, 3
    add eax, edx

    ; convert page index -> physical address

    shl eax, 12

    jmp .done


.out_of_memory:

    xor eax, eax


.done:

    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


; ---------------------------------------------------------
; Free page
;
; Input:
;   EAX = physical address
; ---------------------------------------------------------

pmm_free_page:
    pusha

    ; must be 4KB aligned

    test eax, 0FFFh
    jnz .done

    ; physical address -> page index

    shr eax, 12

    mov ebx, eax
    shr ebx, 3

    mov edx, eax
    and edx, 7

    mov esi, memory_bitmap

    mov al, [esi + ebx]

    mov ecx, 1
    shl ecx, dl

    not cl
    and al, cl

    mov [esi + ebx], al

.done:
    popa
    ret
