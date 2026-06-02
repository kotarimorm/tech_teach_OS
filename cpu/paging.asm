section .bss
align 4096

page_directory:
    resb 4096

page_table_0:
    resb 4096


section .text
global init_paging

init_paging:
    pusha

    ; -----------------------------------
    ; 1. Clear page directory (1024 entries)
    ; -----------------------------------
    mov edi, page_directory
    xor eax, eax
    mov ecx, 1024
    cld
    rep stosd

    ; -----------------------------------
    ; 2. Clear page table (1024 entries)
    ; -----------------------------------
    mov edi, page_table_0
    xor eax, eax
    mov ecx, 1024
    cld
    rep stosd

    ; -----------------------------------
    ; 3. Identity map first 4MB
    ; -----------------------------------
    mov edi, page_table_0
    mov eax, 0x00000003     ; present + RW

    mov ecx, 1024
.map_pt:
    mov [edi], eax
    add eax, 4096
    add edi, 4
    loop .map_pt

    ; -----------------------------------
    ; 4. Link page table into directory
    ; -----------------------------------
    mov eax, page_table_0
    or eax, 0x3
    mov [page_directory], eax

    ; -----------------------------------
    ; 5. Load CR3
    ; -----------------------------------
    mov eax, page_directory
    mov cr3, eax

    ; -----------------------------------
    ; 6. Enable paging (CR0.PG = bit 31)
    ; -----------------------------------
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    popa
    ret
