[bits 32]

; Pointers to the current and next task context structures
current_task_esp dd 0
next_task_esp    dd 0

timer_handler_multitasking:
    ; 1. Save the context of the current task
    pusha                    ; Save all general-purpose registers
    push ds                  ; Also highly recommended to save data segments
    push es
    push fs
    push gs

    ; 2. Send End of Interrupt (EOI) immediately to the PIC
    mov al, 0x20
    out 0x20, al

    ; 3. Save current ESP directly into the task structure pointer
    ; (Assuming current_task_esp holds the address of the variable/field)
    mov eax, [current_task_esp]
    mov [eax], esp          

    ; 4. Switch to the next task's stack
    mov eax, [next_task_esp] 
    mov esp, [eax]

    ; (Optional: dynamic GDT/TSS ESP0 update would go here for Ring 3)

    ; 5. Restore the context of the NEW task
    pop gs
    pop fs
    pop es
    pop ds
    popa
    iret                    ; Jump to the new task's EIP/CS/EFLAGS
