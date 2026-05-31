global print_hex_byte
extern print_char

section .text

; ---------------------------------------------------------
; print_hex_byte
; Converts a byte to ASCII (Hex) and prints it to the screen.
; Calling convention: cdecl
; Input:  [ebp + 8]  = byte to print (passed as 32-bit int)
;         [ebp + 12] = current screen position (pos)
; Returns: EAX = new screen position after printing
; ---------------------------------------------------------
print_hex_byte:
    push ebp
    mov ebp, esp
    push esi                ; Save callee-saved register (standard cdecl)
    push edi                ; Save callee-saved register (standard cdecl)

    movzx esi, byte [ebp + 8] ; ESI = byte to print (extracted from stack)
    mov edi, [ebp + 12]       ; EDI = current screen position (pos)

    ; --- Step 1: Print the high nibble (upper 4 bits) ---
    mov eax, esi
    shr eax, 4              ; Shift right to isolate the upper 4 bits
    call .hex_to_ascii      ; Convert 0x0..0xF to an ASCII character
    
    ; Call print_char(character, pos)
    push edi                ; 2nd argument: pos
    movzx eax, al
    push eax                ; 1st argument: ASCII character
    call print_char
    add esp, 8              ; Clean up the stack after the call
    inc edi                 ; Move position forward by 1 character

    ; --- Step 2: Print the low nibble (lower 4 bits) ---
    mov eax, esi
    and eax, 0x0F           ; Mask out the upper bits to keep the lower 4 bits
    call .hex_to_ascii      ; Convert to ASCII
    
    ; Call print_char(character, pos)
    push edi                ; 2nd argument: pos
    movzx eax, al
    push eax                ; 1st argument: ASCII character
    call print_char
    add esp, 8              ; Clean up the stack after the call
    inc edi                 ; Move position forward for the next output

    mov eax, edi            ; Return the new screen position in EAX

    pop edi                 ; Restore EDI
    pop esi                 ; Restore ESI
    mov esp, ebp
    pop ebp
    ret

; --- Helper micro-function to convert 4 bits to ASCII ---
.hex_to_ascii:
    cmp al, 10
    jl .is_digit
    add al, 'A' - 10        ; If it is A..F (convert to letters)
    ret
.is_digit:
    add al, '0'             ; If it is 0..9 (convert to digits)
    ret
