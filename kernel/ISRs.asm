[bits 32]

; Исключение 0: Деление на ноль (Divide by Zero Exception)
isr_divide_by_zero:
    pusha
    
    ; Выводим красный символ 'X' в левый верхний угол экрана (ошибка)
    mov dword [0xB8000], 0x0458 
    
    ; Глушим систему, так как продолжать работу после такого нельзя
    cli
    hlt

; Программное прерывание 0x80: Пример системного вызова (Syscall)
; Ожидает номер функции в EAX
isr_syscall:
    pusha
    
    cmp eax, 1
    je .sys_print
    cmp eax, 2
    je .sys_exit
    jmp .done

.sys_print:
    ; Логика вывода на экран (например, адреса строки из EBX)
    jmp .done
    
.sys_exit:
    ; Логика завершения процесса
    
.done:
    popa
    iret
