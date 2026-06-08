; ============================================================
; File: drivers/kbd_buffer.asm
; Topic: Keyboard Buffer
; Type: Utility snippet
;
; Purpose:
;   Provides a small circular buffer for keyboard input.
;
; Assumes:
;   - Single producer / single consumer usage
;   - Keyboard IRQ handler pushes data
;   - Kernel loop or input layer pops data
;
; Notes:
;   - Buffer overflow drops new input.
;   - No locking is implemented.
;   - Adapt synchronization if used outside a simple early kernel.
; ============================================================

global kbd_buf_push
global kbd_buf_pop

section .bss
    ; Reserve 256 bytes for the buffer itself
    kbd_buffer resb 256
    
    ; Pointers to head (write) and tail (read)
    kbd_head resd 1
    kbd_tail resd 1

section .text

; ---------------------------------------------------------
; kbd_buf_push
; Adds scan code to buffer. CALLED ONLY FROM INTERRUPT!
; Input: AL = scan code
; ---------------------------------------------------------
kbd_buf_push:
    push ebx
    push ecx

    mov ebx, [kbd_head]       ; Get current write index
    
    ; Calculate next index (head + 1)
    mov ecx, ebx
    inc ecx
    and ecx, 255              ; Optimization magic: ecx = ecx % 256
    
    ; Overflow check: if next index == tail, buffer is full
    cmp ecx, [kbd_tail]
    je .drop                  ; If full - just drop scan code

    ; Write byte to memory
    mov byte [kbd_buffer + ebx], al
    
    ; Advance head
    mov [kbd_head], ecx

.drop:
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------
; kbd_buf_pop
; Reads scan code from buffer. Called from kmain main loop.
; Output: EAX = scan code, or EAX = -1 (0xFFFFFFFF) if buffer is empty
; ---------------------------------------------------------
kbd_buf_pop:
    push ebx

    mov ebx, [kbd_tail]       ; Get current read index
    
    ; Emptiness check: if tail catches up to head - nothing to read
    cmp ebx, [kbd_head]
    je .empty

    ; Read byte from buffer
    xor eax, eax              ; Clear EAX so higher bits are zero
    mov al, byte [kbd_buffer + ebx]
    
    ; Advance tail
    inc ebx
    and ebx, 255              ; ebx = ebx % 256
    mov [kbd_tail], ebx
    
    pop ebx
    ret

.empty:
    mov eax, -1               ; Return -1 signaling no data available
    pop ebx
    ret
