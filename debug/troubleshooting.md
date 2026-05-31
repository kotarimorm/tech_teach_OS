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
 
### 11. A20 LINE NOT ENABLED (MEMORY WRAPAROUND)
**Core Issue:** Attempting to access memory above 1MB wraps around to the first megabyte of RAM, silently overwriting the IVT, BIOS data, or early bootloader code.
**Where to Check:**
* **Memory Test:** Write a distinct signature byte to `0x100000` (1MB mark) and check if the value at `0x000000` changed. If it matches, memory is wrapping around.
* **Activation Routine:** Ensure you toggle the Fast A20 gate via port `0x92` (setting bit 1) or via the keyboard controller ports (`0x64`/`0x60`) strictly before entering Protected Mode.

### 12. PAGE STRUCTURE UNALIGNED (CR3 CORRUPTION)
**Core Issue:** Enabling paging causes an immediate Page Fault (0x0E) or Triple Fault, even though entry mapping logic looks correct.
**Where to Check:**
* **4KB Boundaries:** The MMU ignores the lower 12 bits of the address loaded into `CR3` and the addresses inside PDE/PTE entries. Ensure your page directory and tables use `align 4096` in your assembly allocation.
* **Flag Overwrite:** If a table address is not aligned, its lower bits will blend into the page flags (Present, Read/Write, User), causing the MMU to read a garbage physical address while misinterpreting permissions.

### 13. DIRECTION FLAG CORRUPTION (REVERSE MEMCPY/MEMSET)
**Core Issue:** String operations like `rep movsd` or `rep stosd` start destroying adjacent kernel data or throwing Page Faults because memory is processed backward.
**Where to Check:**
* **The DF Flag:** If an interrupt or an external function executed a `std` (Set Direction Flag) instruction to process data backward and did not clear it, your next `memcpy` or `memset` will decrement `EDI`/`ESI` instead of incrementing them.
* **Safe Entry:** Always put a `cld` (Clear Direction Flag) instruction at the very beginning of your `memcpy`, `memset`, and string-handling subroutines to force forward processing.

### 14. SPURIOUS INTERRUPTS (IRQ 7 / IRQ 15 HANGS)
**Core Issue:** The kernel receives unexpected interrupts on vector 7 or 15 without any hardware triggering them. Handling them like a normal IRQ freezes the PIC.
**Where to Check:**
* **Hardware Noise:** Real hardware and emulators like QEMU generate spurious interrupts when an input line toggles improperly. Master PIC sends an IRQ 7; Slave PIC sends an IRQ 15.
* **Conditional EOI:** Check the In-Service Register (ISR) of the PIC via port `0x20` before sending a generic End-of-Interrupt (`0x20`). Spurious IRQ 7 does *not* require an EOI. Sending an EOI to a spurious interrupt can break the PIC status state.

### 15. MISSING TSS FOR RING 3 (GPF ON HARDWARE INTERRUPT)
**Core Issue:** The system successfully switches to User Mode (Ring 3), but the exact millisecond a hardware interrupt (like the PIT timer) fires, the CPU throws a General Protection Fault or Triple Fault.
**Where to Check:**
* **Stack Switching Registers:** When an interrupt occurs in Ring 3, the CPU must switch back to the Ring 0 kernel stack. It reads where this stack is from the Task State Segment (TSS). If you haven't loaded a valid TSS descriptor into the task register (`ltr`), the CPU cannot save the execution state.
* **TSS Fields:** Ensure your TSS structure has valid `SS0` and `ESP0` fields pointing to your kernel stack space.

### 16. UNPROTECTED ISR ENTRY (REGISTER REUSE SMASHING)
**Core Issue:** Returning from an interrupt handler causes the main kernel loop to exhibit erratic behavior, corrupt loops, or jump to completely wrong conditional branches.
**Where to Check:**
* **Register Preservation:** Interrupts are asynchronous and can fire anywhere. If your ISR modifies `EAX`, `ECX`, or `EDX` without saving them, the underlying code loses its state.
* **Context Macro:** Ensure your ISR entry stub executes a strict `pushad` (or explicitly pushes modified registers) and your exit stub executes `popad` followed by `iret`. Never use a standard `ret` inside an ISR.

### 17. PCI SPACE CONFIGURATION LOCKUP (INVALID PORT ACCESS)
**Core Issue:** The PCI bus scanner reads `0xFFFFFFFF` for every single device/slot, or causes the system bus to hang completely during the scan.
**Where to Check:**
* **Bit Positioning:** Reading PCI configuration space requires writing a 32-bit address to port `0xCF8` and reading the result from port `0xCFC`. The Enable bit (bit 31) of the address sent to `0xCF8` must be set to 1.
* **Alignment:** The offset field within the configuration address must be 4-byte aligned (the lowest two bits must be 0) when reading whole DWORDS.

### 18. ATA PIO POLLING HANG (STATUS REGISTER STUCK)
**Core Issue:** The kernel tries to read a sector from the IDE/ATA hard disk controller using PIO mode, but loops infinitely while waiting for the drive status to become ready.
**Where to Check:**
* **Floating Bus:** Reading from an unmapped or secondary controller port that doesn't exist often returns `0xFF`. A status byte of `0xFF` means the busy bit and error bits look constantly set. Validate your base I/O port mapping (Primary is usually `0x1F0`).
* **The 400ns Delay:** After sending a command byte to the command port, you must read the alternate status register or wait at least 400 nanoseconds before reading the regular status port to give the drive hardware time to set the BSY bit.

### 19. CR4/CR0 MISSING FLAGS FOR FPU/SSE (INVALID OPCODE #UD)
**Core Issue:** Executing any basic floating-point or vector instruction causes an immediate Invalid Opcode Exception (0x06).
**Where to Check:**
* **Coprocessor Bits:** Real x86 CPUs boot with the FPU and SSE extensions disabled or unconfigured in Protected Mode.
* **Initialization Sequence:** You must clear the EM (Emulation) bit and set the MP (Monitor Coprocessor) bit in `CR0`. Additionally, you must set the OSFXSR and OSXMMEXCPT bits in `CR4` to enable SSE support and its respective exceptions before executing those instructions.

### 20. RAW BINARY ORG MISMATCH (BROKEN ABSOLUTE JUMPS)
**Core Issue:** You compile your kernel into a raw flat binary (`-f bin`), everything compiles without warnings, but conditional jumps and data memory lookups point to absolute garbage locations.
**Where to Check:**
* **The `org` Directive:** If your bootloader loads your kernel at physical memory address `0x100000` (1MB mark), but your `kernel.asm` file does not specify `org 0x100000` at the very top, NASM calculates all labels relative to `0x0000`. 
* **Relative vs Absolute:** Short jumps (`jmp short` / `jz`) will work because they use relative offsets, but any absolute reference like `mov eax, [my_variable]` or calls to functional pointers will completely miss the target.

### 21. STALE TLB CACHE (PAGE UPDATES NOT REFLECTING)
**Core Issue:** You update a Page Table Entry (PTE) to point to a new physical address or change its permissions, but the CPU continues to use the old mapping, causing random Page Faults or silent data corruption.
**Where to Check:**
* **Translation Lookaside Buffer (TLB):** The CPU caches paging structures in the TLB. Modifying a page table entry in memory does not automatically update this cache.
* **Invalidation:** You must invalidate the stale cache entry using the `invlpg [address]` instruction right after updating a PTE, or completely flush the TLB by reloading `CR3` (`mov cr3, eax`).

### 22. EXCEPTION ERROR CODE MISMATCH (STACK ALIGNMENT DESTROYED)
**Core Issue:** Returning from specific interrupt handlers via `iret` causes an immediate General Protection Fault (0x03) or executes garbage code because the stack pointer is misaligned.
**Where to Check:**
* **Automatic Pushes:** x86 Exceptions 8, 10, 11, 12, 13, and 14 automatically push an extra 32-bit error code onto the stack *after* pushing EIP/CS/EFLAGS. Other interrupts (like the PIT or keyboard) do not.
* **ISR Alignment:** If your generic ISR macro handles both types the same way without popping the error code off the stack before executing `iret`, the CPU will interpret the error code as the return EIP. Ensure your error-code handlers execute an explicit `add esp, 4` before `popad` and `iret`.

### 23. INTERRUPT VS TRAP GATES (UNINTENDED RE-ENTRANCY)
**Core Issue:** While executing a hardware interrupt handler, the exact same interrupt fires again, stacking up contexts until the kernel hits a Stack Overflow or a Double Fault.
**Where to Check:**
* **IDT Flags:** Check the access byte of your IDT descriptors. An Interrupt Gate (`0x8E`) automatically clears the IF bit in `EFLAGS` when triggered, blocking further interrupts until `iret` restores them. 
* **Trap Gates:** A Trap Gate (`0xEF`) leaves the IF bit enabled. If you accidentally used Trap Gate attributes for hardware IRQs (like PIT or Keyboard), any prolonged ISR processing allows interrupts to nest uncontrollably.

### 24. UNINITIALIZED DATA SEGMENTS POST-CR0 PROTECTED MODE SWITCH
**Core Issue:** You successfully execute the far jump after setting the PE bit in `CR0`, but the very first instruction that accesses a memory variable causes an instant General Protection Fault.
**Where to Check:**
* **Segment Registers:** The far jump only updates the `CS` register. The remaining segment registers (`DS`, `ES`, `FS`, `GS`, `SS`) still hold real-mode selectors or undefined garbage values.
* **Explicit Reload:** Immediately after your protected mode far label, reload all data segment registers with your GDT data selector index (e.g., `0x10` if your data descriptor is at offset 16).

### 25. SERIAL PORT (COM1) DEBUG HANG (INFINITE POLLING)
**Core Issue:** Adding serial output logs for debugging causes the entire system boot process to hang indefinitely on a real machine, though it might work fine in QEMU.
**Where to Check:**
* **Line Status Register:** Your `serial_putc` routine polls port `0x3FD` waiting for bit 5 (Transmitter Holding Register Empty) to become 1.
* **Hardware Initialization:** If you forgot to properly initialize the baud rate, parity, and line control registers on ports `0x3F8`-`0x3FE` early in the boot sequence, the serial hardware state will never signal readiness to receive bytes.

### 26. CMOS / RTC READ LOCKUP (UIP BIT STALL)
**Core Issue:** Reading the system real-time clock via ports `0x70`/`0x71` returns corrupted time metrics or hangs the kernel execution loop.
**Where to Check:**
* **Update In Progress (UIP):** Before reading RTC registers (Seconds, Minutes, Hours), you must poll CMOS Status Register A (Index `0x0A`) and check bit 7. If it is 1, the clock update is currently happening.
* **Timeout Guards:** A raw `jmp $` polling loop on this bit can lock up if the hardware state freezes. Always implement a loop counter or read the data quickly during the safe update-ended status window.

### 27. TEXT MODE INVISIBLE TEXT (VGA COLOR MISMATCH)
**Core Issue:** Your VGA string functions execute without errors, but the monitor screen remains completely blank or characters look completely wiped out.
**Where to Check:**
* **Attribute Byte Structure:** VGA Text Mode (`0xB8000`) uses 2 bytes per character: `Byte 0` is the ASCII character, `Byte 1` is the attribute (colors).
* **Color Schemes:** If your attribute mask evaluates to `0x00`, you are printing black text on a black background. Ensure the attribute byte sets high bits for background and low bits for foreground (e.g., `0x0F` for white text on a black background).

### 28. UNINITIALIZED BSS SECTION (GARBAGE GLOBAL VARIABLES)
**Core Issue:** Global variables initialized to 0 or left uninitialized in your assembly/C structures contain random, unpredictable junk RAM values upon kernel execution.
**Where to Check:**
* **Linker Allocation:** The compiler/assembler separates uninitialized globals into the `.bss` section. Unlike `.text` and `.data`, the `.bss` section does not take up real byte space inside the compiled binary file on disk.
* **Boot Initialization:** Your bootloader must explicitly read the `.bss` bounds from the linker script and clear that entire memory area with zeros using a `memset` routine before launching the main kernel routines.

### 29. 16-BYTE ALIGNMENT FAULTS FOR SSE INSTRUCTIONS
**Core Issue:** Executing basic vector instructions like `movaps` or `movntps` inside an ISR or core function throws an Invalid Opcode (#UD) or General Protection Fault (#GP).
**Where to Check:**
* **Stack Pointer (ESP) Alignment:** SIMD/SSE optimization instructions expect operands in memory to be aligned to a strict 16-byte boundary. If your stack pointer or memory buffer address is misaligned by even 1 byte, the instruction fails at hardware level.
* **ISR Entry Adjustments:** Ensure that when setting up your kernel execution stacks or interrupt stack frames, the base pointer is aligned to 16 bytes before processing complex instructions.

### 30. MALFORMED LINKER SCRIPT VMA/LMA OVERLAP
**Core Issue:** The kernel builds cleanly, but variables contain data that belongs to completely different functions, or code structures appear truncated.
**Where to Check:**
* **Virtual vs Load Memory Address:** Check your linker script sections layout. If the Virtual Memory Address (VMA) and Load Memory Address (LMA) layout bounds cross or overlap, code blocks might overwrite initial data structures when loaded into RAM by the bootloader.
* **Binary Analysis:** Verify the output map or use parsing utilities (`readelf -S kernel.bin`) to ensure section memory offsets increments linearly without layout collisions.
