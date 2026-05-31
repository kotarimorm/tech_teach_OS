; memory.asm
; basic memory manipulation routines

; memcpy
; inputs:
;   esi - source
;   edi - destination
;   ecx - byte count
memcpy:
    pusha

    ; copy by dwords (4 bytes) for speed
    mov eax, ecx
    shr ecx, 2
    rep movsd

    ; copy remaining 0-3 bytes
    mov ecx, eax
    and ecx, 3
    rep movsb

    popa
    ret

; memset
; inputs:
;   edi - destination
;   al  - value to fill (e.g., 0x00)
;   ecx - byte count
memset:
    pusha

    ; duplicate AL to entire EAX (0xAB -> 0xABABABAB)
    mov ah, al
    mov edx, eax
    shl eax, 16
    mov ax, dx

    ; fill by dwords
    mov edx, ecx
    shr ecx, 2
    rep stosd

    ; fill remainder
    mov ecx, edx
    and ecx, 3
    rep stosb

    popa
    ret
