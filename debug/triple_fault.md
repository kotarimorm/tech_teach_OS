# Triple Fault

A Triple Fault occurs when the CPU attempts to handle an exception, but a new exception happens while trying to invoke the handler. The processor gives up and resets.

## 1. First, see the error (QEMU Logs)
Never debug blindly. Run QEMU with the following flags:
`qemu-system-i386 -d int,cpu_reset -no-reboot -no-shutdown -monitor stdio -hda os.img`

* `-d int`: Logs every interruption.
* `-no-reboot`: Stops the machine immediately after a Triple Fault so you have time to read the logs.

## 2. Most common causes (Checklist)

### A. Incorrect IDT table
This is cause #1.
* **Problem:** The IDT pointer (`lidt`) is invalid, or the handler address in the descriptor points to nowhere.
* **Solution:** Verify that `idt_pointer` points to the start of the table, and the limit is set to `(table_size - 1)`.

### B. Stack overflow or points to "garbage"
* **Problem:** The interrupt handler tries to save registers (`pusha`), but the `ESP` stack pointer points to invalid memory.
* **Solution:** In the bootloader, before jumping into the kernel, make sure `esp` is set to a safe memory area (e.g., `0x90000`).

### C. GDT not loaded or segments are incorrect
* **Problem:** You jumped into 32-bit code but did not execute `mov ax, 0x10; mov ds, ax...` (updating segment selectors).
* **Solution:** After `lgdt`, you must update `cs` (via a far jump) and all other segment registers (`ds`, `es`, `fs`, `gs`, `ss`).

### D. Interrupts enabled, but the handler is empty
* **Problem:** `sti` was executed, an interrupt occurred (e.g., a timer), but there is nothing or just garbage at that vector in the IDT.
* **Solution:** Fill the **entire** IDT table with stub descriptors (at least `iret`) if you do not want to handle all vectors right away.
