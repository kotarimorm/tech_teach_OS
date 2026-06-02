# Triple Fault (x86 CPU Reset)

A **Triple Fault** happens when the CPU fails to handle an exception, then fails to handle the resulting double fault, and finally resets the system.

In practice:  
Something broke in low-level CPU setup (IDT / stack / paging / segments), and the CPU has no valid recovery path.

---

# 1. How to debug it (DO NOT GUESS)

Always start with QEMU logging:

qemu-system-i386 -d int,cpu_reset -no-reboot -no-shutdown -monitor stdio -hda os.img

Flags:
- -d int → logs all interrupts and exceptions  
- -d cpu_reset → shows why CPU reset happened  
- -no-reboot → freezes after crash (critical for debugging)  
- -monitor stdio → allows runtime inspection  

---

# 2. What actually causes a Triple Fault

Most triple faults come from a small set of low-level failures.

---

## A. Broken or incomplete IDT (MOST COMMON)

If the CPU triggers an interrupt and cannot find a valid handler → #GP or #PF → then double fault → reset.

Check:
- IDT base pointer is correct (lidt)
- Limit is (sizeof(idt) * 256 - 1)
- Every used vector is valid

Critical missing fields:
- present (P) = 1
- correct CS selector
- correct gate type (0x8E interrupt gate)
- correct DPL (usually 0 for kernel)

Common mistake:
IDT entry exists but P-bit is 0 or CS selector is wrong → instant triple fault after sti.

---

## B. Stack is invalid or unmapped

Interrupts require stack usage immediately.

Check:
- ESP points to valid memory
- stack is writable
- stack does not overlap kernel/data/BSS
- paging includes stack region

Common failure:
ESP is valid physically but not mapped in paging → page fault → triple fault.

---

## C. GDT not fully initialized

After lgdt, CPU still depends on segment registers.

Must be done after switching to protected mode:

jmp 0x08:pmode_entry

Then:

mov ax, 0x10
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax

Common mistakes:
- null descriptor not zeroed
- CS selector mismatch
- SS not set correctly
- privilege mismatch → #GP

---

## D. Interrupts enabled too early (sti too soon)

If interrupts are enabled before system is ready:
- IRQ triggers immediately
- CPU jumps into empty IDT entry
- system crashes instantly

Fix:
Enable interrupts only after:
- IDT fully initialized
- PIC initialized
- stack valid
- ISRs installed

---

## E. Missing handlers in IDT

If an interrupt fires and vector is empty:
- CPU jumps to garbage address
- executes invalid instruction
- double fault → triple fault

Early-stage safe stub:

cli
hlt

or:

iret

---

## F. PIC not initialized (IRQ overlap)

If PIC is not remapped:
- IRQs overlap CPU exceptions (0x00–0x1F)
- keyboard/timer break exception vectors
- random crashes after sti

Fix:
- remap PIC (0x20 / 0x28)
- mask unused IRQs

---

# 3. Key idea

A triple fault always means:

CPU lost all valid recovery paths (IDT + stack + handler chain)

---

# 4. Checklist before enabling interrupts

- IDT fully initialized
- PIC remapped
- stack mapped and valid
- GDT loaded + segments reloaded
- no empty ISR entries
- paging includes kernel + stack
- cli used during setup

---

# 5. Mental model

Exception → IDT handler  
→ fail → Double Fault  
→ fail → TRIPLE FAULT → RESET
