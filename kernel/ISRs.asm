[bits 32]

; Exception 0: Divide by Zero Exception
isr_divide_by_zero:
    ; Safe crash dump approach for kernel panic
    pusha
    
    ; Print a red 'X' character to the top-left corner of the screen
    mov dword [0xB8000], 0x0458 
    
    ; Halt the system safely (interrupts are already disabled by Interrupt Gate)
    hlt
    jmp $                   ; In case of a spurious NMI wakeup, trap execution here

; Software Interrupt 0x80: Example of a System Call (Syscall)
; Expects the function number in EAX
isr_syscall:
    pusha
    
    cmp eax, 1
    je .sys_print
    cmp eax, 2
    je .sys_exit
    jmp .done

.sys_print:
    ; Screen output logic (e.g., string address from EBX)
    jmp .done               ; Explicit jump to prevent falling into sys_exit
    
.sys_exit:
    ; Process termination logic
    cli                     ; Disable interrupts for this thread
.loop_exit:
    hlt                     ; Safely halt this thread/core
    jmp .loop_exit          ; Prevent fall-through into popa/iret
    
.done:
    popa
    iret
