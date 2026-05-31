section .bss
align 4096
page_directory:
    resb 4096
page_table_0:
    resb 4096

section .text
init_paging:
    pusha

    ; clear page directory
    mov edi, page_directory
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; clear page table 0
    mov edi, page_table_0
    mov ecx, 1024
    rep stosd

    ; identity map first 4mb (flags: r/w, present)
    mov edi, page_table_0
    mov eax, 0x00000003
    mov ecx, 1024
.map_pt:
    mov [edi], eax
    add eax, 4096
    add edi, 4
    loop .map_pt

    ; link page table 0 to directory entry 0
    mov eax, page_table_0
    or eax, 3
    mov [page_directory], eax

    ; load directory base to cr3
    mov eax, page_directory
    mov cr3, eax

    ; enable paging bit in cr0
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    popa
    ret
