# OS KERNEL: COMPLETE TROUBLESHOOTING CHEAT SHEET v1.0

### 1. TRIPLE FAULT (CPU RESET LOOP)
**Core Issue:** The CPU failed to handle an Exception, triggered a Double Fault, failed to handle that too, and went into a hardware reset.
**Where to Check:**
* **IDT Limit:** Check your `idtr` structure. The `limit` field must be strictly `(sizeof(idt_entry) * 256) - 1`.
* **Unmapped Handlers:** Calling `sti` with empty vectors 0-31 (Exceptions). The slightest hiccup (like a GPF) will make it jump to a garbage address. Fill the entire table with addresses pointing to a dummy `iret` stub.

### 2. PAGE FAULT (CR2 IS YOUR GOD)
**Core Issue:** Exception 0x0E. The kernel tried to read/write memory that doesn't exist in the page tables, or violated access rights (Ring 3 vs Ring 0).
**Where to Check:**
* **CR2 Register:** Immediately upon crashing, read CR2 — it holds the exact physical/virtual address that caused the crash.
* **VGA Paging:** Turned on paging? Did you forget to identity map `0xB8000` (video memory)? Without this, the very first attempt to print a character will kill the system.

### 3. GDT CORRUPTION (GPF ON SEGMENT LOAD)
**Core Issue:** General Protection Fault (0x0D) when trying to do a `jmp 0x08:kmain` or update segment registers (`mov ds, ax`).
**Where to Check:**
* **Null Descriptor:** The first entry in the GDT (index 0) must be absolutely empty (8 bytes of zeros).
* **Granularity:** If the granularity bit is set to 1, the limit is multiplied by 4KB. Mix up this bit, and you get a segment sized in bytes instead of gigabytes.

### 4. IRQ 1 (KEYBOARD) HANG / SILENCE
**Core Issue:** Keyboard interrupts only arrive once or remain completely silent.
**Where to Check:**
* **PIC Masking:** Port `0x21`. The mask is inverted. To enable IRQ 1, you need to clear the 1st bit. The mask should be `0xFD` (11111101b).
* **Missing EOI (End Of Interrupt):** If one scan code is read and everything freezes, the PIC is waiting for confirmation. Add `outb(0x20, 0x20)` strictly before the `iret` in your handler.

### 5. STACK OVERFLOW (SILENT DEATH)
**Core Issue:** The stack grew downwards, overwrote kernel data (like the GDT), or hit an unallocated memory page.
**Where to Check:**
* **Where is your ESP?:** If you allocated 4KB (one page) for the stack in `boot.asm`, and then created a local array `char buffer[8192]` in your C code, you instantly wiped out the memory below the stack.
* **Recursion in interrupts:** If an interrupt calls itself before sending an EOI, the stack will fly out of bounds in milliseconds.

### 6. MULTIBOOT MAGIC FAILURE
**Core Issue:** GRUB (or QEMU) refuses to load your binary. Returns an "Invalid Multiboot header" error.
**Where to Check:**
* **Alignment:** The Multiboot header must be 32-bit aligned.
* **File Position:** It must be located within the first 8 KB (8192 bytes) of the binary file. If the linker shoved `.text` or `.data` before it, the bootloader won't find it. Check your `linker.ld` script.

### 7. PIT TIMER SPAM (INTERRUPT STORM)
**Core Issue:** As soon as you execute `sti`, the kernel freezes dead, completely ignoring the keyboard.
**Where to Check:**
* **Timer Frequency:** The default PIT frequency is ~18.2 Hz. If you reprogrammed channel 0 to 1000 Hz, and your interrupt handler (with `pushad` and text output) takes longer than 1 ms to execute, interrupts will start stacking on top of each other. Stack overflows = crash.

### 8. VGA BUFFER OVERFLOW
**Core Issue:** The `kprint` function outputs a long log, reaches the bottom line of the screen, and the system crashes.
**Where to Check:**
* **Memory Boundaries:** Standard screen size is 80 by 25 characters (2 bytes per char = 4000 bytes). If you didn't write scrolling logic and continued writing at address `0xB8000 + 4001`, you started overwriting other memory (or flew out of your Identity mapping bounds).

### 9. INTERRUPT DEADLOCK (CLI WITHOUT STI)
**Core Issue:** The kernel is running, but peripherals (keyboard, timer) "dropped off" for no visible reason and without a kernel panic.
**Where to Check:**
* **Lost Flags:** If you executed `cli` (disabled interrupts) inside an interrupt handler, and upon exit did a standard `ret` instead of `iret`, the `IF` flag in the `EFLAGS` register remains cleared. Not a single interrupt will pass through anymore.

### 10. KERNEL PANIC & REGISTER DUMP
**Core Issue:** In any confusing situation — don't guess, look at the registers.
**Where to Check:**
* **GDB Attach:** Run QEMU with `-s -S`, and attach GDB (`target remote localhost:1234`).
* **The `info registers` command will show you:**
    * **EIP** — the exact instruction where it crashed.
    * **ESP/EBP** — where the stack is right now (and if it's alive).
    * **EFLAGS** — whether interrupts are currently enabled (bit 9).
