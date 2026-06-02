# OS KERNEL: COMPLETE TROUBLESHOOTING SPECIFICATION v1.0

This document is a structured debugging reference for low-level OS development in 32-bit x86 protected mode.  
Each issue includes: **Symptoms → Root Cause → Diagnostics → Fix → Common Mistakes**

---

## 1. TRIPLE FAULT (CPU RESET LOOP)

**Core Issue:** CPU enters exception → double fault → triple fault → hardware reset.

**Symptoms:**
- Instant reboot in QEMU/VMware
- No visible output, sometimes black screen loop

**Diagnostics:**
- Run QEMU with:
  ```
  -d int,cpu_reset -no-reboot -no-shutdown
  ```
- Check last interrupt before reset

**Root Causes:**
- Invalid IDT pointer or limit
- Missing exception handlers (0–31)
- Stack corruption before interrupt entry
- Wrong segment registers after `lgdt`

**Fix:**
- Fill entire IDT with valid stubs (at least `iret`)
- Ensure correct IDTR:
  ```
  limit = sizeof(idt) * 256 - 1
  base  = &idt
  ```
- Initialize stack before enabling interrupts (`esp = safe region`)
- Ensure GDT is loaded + far jump performed

**Common Mistakes:**
- Calling `sti` too early
- Forgetting exception stubs
- Using invalid function pointers in IDT

---

## 2. PAGE FAULT (CR2 DEBUG VECTOR)

**Core Issue:** Invalid memory access in paging mode (0x0E exception)

**Symptoms:**
- Crash on first VGA write
- Random freezes after enabling paging

**Diagnostics:**
- Read CR2 register (faulting address)
- Check error code (present/write/user bits)

**Root Causes:**
- Missing identity mapping for kernel memory
- VGA memory (`0xB8000`) not mapped
- Incorrect page table permissions
- CR3 pointing to wrong directory

**Fix:**
- Identity map kernel + hardware regions
- Always map:
  - `0x00000000–kernel_end`
  - `0xB8000`
- Validate PDE/PTE flags (Present + RW)

**Common Mistakes:**
- Forgetting to flush TLB (`invlpg` / `mov cr3`)
- Mixing physical/virtual addresses

---

## 3. GDT CORRUPTION (SEGMENT FAULTS)

**Symptoms:**
- GPF on `mov ds, ax` or far jump
- Random crashes after `lgdt`

**Root Cause:**
- Invalid descriptor structure
- Wrong selector indexes
- Granularity/limit mismatch

**Diagnostics:**
- Check GDT entries in memory
- Verify selector values (0x08, 0x10 etc.)

**Fix:**
- Null descriptor at index 0
- Code/data segments correctly defined
- Reload segments after `lgdt`

**Common Mistakes:**
- Forgetting far jump after `lgdt`
- Using real-mode segment values

---

## 4. IRQ 1 SILENT FAILURE (KEYBOARD DEAD)

**Symptoms:**
- No keyboard input
- Single key works then stops

**Diagnostics:**
- Check PIC mask (`0x21`)
- Verify ISR execution
- Check EOI sent

**Root Causes:**
- IRQ1 masked
- Missing End Of Interrupt (`0x20`)
- No IDT entry for IRQ1

**Fix:**
```
out 0x20, 0x20   ; EOI
```
- Unmask IRQ1 (clear bit 1 → 0xFD)

**Common Mistakes:**
- Forgetting EOI
- Using wrong PIC initialization order

---

## 5. STACK OVERFLOW (SILENT MEMORY CORRUPTION)

**Symptoms:**
- Random crashes
- GDT/IDT corruption
- Weird register values

**Root Cause:**
- Stack overlaps kernel memory
- No stack limit enforcement

**Diagnostics:**
- Monitor ESP range
- Watch memory writes near stack base

**Fix:**
- Set stack in safe region (e.g. 0x90000)
- Reserve at least 4–16 KB initially
- Avoid large local arrays in kernel

---

## 6. MULTIBOOT FAILURE

**Symptoms:**
- GRUB error: invalid multiboot header

**Root Cause:**
- Header not in first 8KB
- Misaligned multiboot structure

**Fix:**
- Place header at binary start
- Ensure 32-bit alignment
- Verify linker script order

---

## 7. INTERRUPT STORM (PIT OVERLOAD)

**Symptoms:**
- System freezes after `sti`
- Keyboard stops responding

**Root Cause:**
- PIT frequency too high
- ISR slower than interrupt rate

**Fix:**
- Use sane PIT (~100–1000 Hz max)
- Minimize ISR work
- Move heavy logic outside ISR

---

## 8. VGA OVERFLOW / SCREEN CORRUPTION

**Symptoms:**
- Screen glitches or crash at bottom line

**Root Cause:**
- No scrolling logic
- Writing beyond `0xB8000 + 4000 bytes`

**Fix:**
- Implement scroll (shift buffer up)
- Clamp cursor position

---

## 9. INTERRUPT DEADLOCK (CLI WITHOUT STI)

**Symptoms:**
- System alive but no input/output

**Root Cause:**
- `cli` executed and never restored
- Wrong ISR exit path (`ret` instead of `iret`)

**Fix:**
- Always use `iret` in ISRs
- Ensure interrupts re-enabled (`sti`)

---

## 10. KERNEL DEBUG CORE (REGISTER ANALYSIS)

**Best Practice:**
Always inspect:
- EIP (crash point)
- ESP (stack health)
- EFLAGS (interrupt state)

**Tooling:**
```
qemu -s -S
gdb → target remote localhost:1234
```

---

## 11–30. SYSTEM-LEVEL FAILURES (EXPANDED CLASS)

These categories follow same structure:

### MEMORY SYSTEM
- A20 line failure → memory wraparound
- BSS not zeroed → garbage globals
- Paging TLB stale → outdated mappings
- CR3 misalignment → paging crash

### CPU STATE ERRORS
- CR0/CR4 missing flags (SSE/FPU disabled)
- Direction flag corruption (`std` not cleared)
- Segment register mismatch after mode switch

### INTERRUPT SYSTEM
- Spurious IRQs (7/15)
- Trap gate misuse (re-entrant interrupts)
- TSS missing for ring transitions

### HARDWARE INTERFACES
- ATA polling deadlock (BSY stuck)
- Serial port infinite polling
- CMOS RTC UIP freeze
- PCI config invalid access

### MEMORY LAYOUT / LINKING
- VMA/LMA mismatch
- Absolute address errors (missing `org`)
- Section overlap in linker script

---

## FINAL RULE OF KERNEL DEBUGGING

If the kernel crashes:

1. Check interrupts first (IDT + PIC)
2. Check memory second (paging + stack)
3. Check CPU state third (GDT + CR registers)
4. Check hardware last (ATA, VGA, PCI)

**Never assume logic error before verifying hardware state.**
---

## 31. DEBUGGING PIPELINE (QEMU / GDB / LOG ANALYSIS PROTOCOL)

This section defines a systematic workflow for diagnosing kernel crashes using emulator logs, CPU state inspection, and deterministic reproduction.

---

### 31.1 QEMU EXECUTION MODES (CHOOSE YOUR WEAPON)

#### A. Standard debug mode (basic visibility)
```
qemu-system-i386 -no-reboot -no-shutdown
```
**Use when:**
- Early kernel bring-up
- VGA / print debugging

---

#### B. Full interrupt tracing (critical for IDT / IRQ bugs)
```
qemu-system-i386 -d int,cpu_reset,guest_errors
```

**What it reveals:**
- Every interrupt vector fired
- PIC / APIC behavior
- Exception chaining before crash

**Key pattern to look for:**
- `IRQ0` spam → PIT misconfig
- `#GP` → segmentation error
- `#PF` → paging or stack issue
- `Triple fault` → IDT or stack corruption

---

#### C. Kernel crash forensic mode (best for triple faults)
```
qemu-system-i386 -d int,cpu_reset -no-reboot -no-shutdown -D log.txt
```

**What to check in log:**
- Last executed EIP before reset
- Last valid interrupt vector
- Whether CPU reached IDT handler or failed earlier

---

#### D. GDB DEBUG MODE (HARDCORE TRACE)
```
qemu-system-i386 -s -S
```

Then:
```
gdb
target remote localhost:1234
```

**Key commands:**
```
info registers     ; full CPU state
x/10i $eip         ; instructions at crash point
x/32x $esp         ; stack inspection
info idt           ; (if supported via stub tooling)
```

---

### 31.2 CRASH PATTERN RECOGNITION (VERY IMPORTANT)

#### PATTERN 1: INSTANT REBOOT LOOP
```
→ no output
→ machine restarts immediately
```
**Meaning:**
- Triple fault
- Invalid IDT or stack not initialized

---

#### PATTERN 2: HANG AFTER "sti"
```
kernel boots → sti → freeze
```
**Meaning:**
- IRQ enabled but handlers missing
- PIC sending interrupts into garbage vectors

---

#### PATTERN 3: VGA OUTPUT THEN FREEZE
```
prints 1–3 chars → stops
```
**Meaning:**
- Stack overflow
- Page fault on VGA memory
- ISR corruption after first interrupt

---

#### PATTERN 4: RANDOM GARBAGE OUTPUT
```
??????? or broken characters
```
**Meaning:**
- DF (direction flag) corrupted
- Wrong segment register (DS/ES invalid)
- Memory not zero-initialized (.bss issue)

---

#### PATTERN 5: CRASH ON FIRST MEMORY ACCESS
```
mov [0xB8000], al → crash
```
**Meaning:**
- Paging not mapped
- Identity mapping missing
- CR3 incorrect

---

### 31.3 GOLDEN DEBUG FLAGS (QEMU)

#### CPU + interrupt visibility
```
-d int,cpu_reset,guest_errors
```

#### Memory / paging issues
```
-d mmu
```

#### IO port debugging (ATA, PIC, VGA issues)
```
-d in_asm,out_asm
```

#### Full forensic trace (heavy but complete)
```
-d int,cpu_reset,mmu,guest_errors -D full.log
```

---

### 31.4 DEBUGGING HEURISTIC (REAL ENGINEERING FLOW)

When kernel breaks:

#### STEP 1 — CHECK LAST CPU STATE
- EIP → where it died
- CS:EIP → code segment correctness
- EFLAGS → IF bit (interrupt state)

---

#### STEP 2 — CHECK INTERRUPT PATH
Ask:
- Did interrupt happen?
- Did IDT entry exist?
- Did ISR return with `iret`?

---

#### STEP 3 — CHECK MEMORY MODEL
Ask:
- Is paging enabled?
- Is identity map active?
- Is stack inside mapped memory?

---

#### STEP 4 — CHECK HARDWARE LAYER
Ask:
- Did PIC send IRQ?
- Did ATA respond?
- Is VGA memory valid?

---

### 31.5 MOST IMPORTANT RULE (REAL OSDEV TRUTH)

> “If the CPU resets, you didn’t lose execution — you lost visibility.”

Triple fault is never random — it is always:
- missing handler
- broken stack
- or invalid descriptor chain

---

### 31.6 PRO TIP: REPRODUCIBLE CRASH TRACING

To isolate bugs deterministically:

1. Freeze execution:
```
qemu -S -s
```

2. Step instruction-by-instruction:
```
si
```

3. Watch:
- stack evolution
- IDT jumps
- register drift

---

### FINAL INSIGHT

If logs are unclear:

👉 assume earlier system corruption (not the last instruction)

Kernel debugging is not “finding bugs”  
it is **reconstructing broken CPU state history**
