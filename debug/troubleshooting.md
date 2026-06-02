# OS KERNEL DEBUGGING SPECIFICATION & TROUBLESHOOTING SYSTEM v3.0

This document defines a structured methodology for diagnosing, reproducing, and fixing low-level x86 kernel failures in protected mode systems.

It is designed as a **debugging decision system**, not a static checklist.

---

# 0. DEBUGGING PHILOSOPHY (READ FIRST)

Kernel failures are NEVER random.

Every crash belongs to one of four layers:

1. CPU State Failure (GDT / IDT / registers)
2. Memory Model Failure (paging / stack / heap / BSS)
3. Interrupt System Failure (PIC / IRQ / ISR / TSS)
4. Hardware Interface Failure (VGA / ATA / PCI / serial)

> If the system reboots, you lost observability — not execution.

---

# 1. TRIAGE FLOW (FIRST 60 SECONDS RULE)

Before reading logs, classify the symptom:

```
IF instant reboot → TRIPLE FAULT / IDT / STACK
IF freeze after STI → IRQ / PIC / missing handlers
IF crash on memory write → PAGING / CR3 / identity map
IF garbage output → DF flag / segment registers / BSS
IF slow freeze → PIT / interrupt storm / ISR overload
```

---

# 2. QEMU DEBUGGING TOOLCHAIN

## 2.1 Standard execution
```
qemu-system-i386 -no-reboot -no-shutdown
```

Use for:
- VGA debugging
- early boot output

---

## 2.2 Full interrupt tracing
```
qemu-system-i386 -d int,cpu_reset,guest_errors
```

Shows:
- every IRQ
- exception chaining
- triple fault path

---

## 2.3 Memory / paging debugging
```
qemu-system-i386 -d mmu
```

Shows:
- page faults
- address translation failures

---

## 2.4 Full forensic dump
```
qemu-system-i386 -d int,cpu_reset,mmu,guest_errors -D log.txt
```

Use when system is fully dead.

---

## 2.5 GDB live debugging
```
qemu-system-i386 -s -S
gdb
target remote localhost:1234
```

Key commands:
```
info registers
x/10i $eip
x/32x $esp
si
```

---

# 3. CRITICAL CRASH PATTERNS

## 3.1 TRIPLE FAULT LOOP
Symptoms:
- instant reboot
- no output

Causes:
- invalid IDT
- missing exception handlers
- broken stack
- invalid segment registers

Fix priority:
1. IDT validity
2. stack pointer
3. GDT reload
4. all ISR stubs exist

---

## 3.2 STI FREEZE
Symptoms:
- kernel stops after enabling interrupts

Causes:
- IRQ enabled but handlers missing
- PIC misconfigured
- missing EOI

Fix:
- verify IDT entries 0–15
- unmask IRQ lines
- ensure `out 0x20, 0x20`

---

## 3.3 VGA WRITE CRASH
Symptoms:
- crash on `0xB8000` write

Causes:
- paging not mapped
- identity map missing

Fix:
- map VGA region
- verify CR3

---

## 3.4 RANDOM GARBAGE OUTPUT
Symptoms:
- broken characters / corruption

Causes:
- direction flag set (`std`)
- uninitialized BSS
- wrong DS/ES selectors

Fix:
- enforce `cld`
- zero `.bss`
- reload segments after `lgdt`

---

# 4. SYSTEM STATE MODEL

Kernel must be validated in layers:

```
BOOTLOADER STATE
→ GDT LOADED
→ IDT INITIALIZED
→ PAGING ENABLED
→ INTERRUPTS ENABLED
→ DRIVERS ACTIVE
```

Failure at each layer maps to specific bug class.

---

# 5. QEMU LOG INTERPRETATION RULES

## 5.1 CRASH KEYWORDS

| Log Output | Meaning |
|----------|--------|
| #GP | segmentation fault |
| #PF | paging error |
| #DF | double fault |
| triple fault | IDT or stack fatal failure |

---

## 5.2 PATTERN INTERPRETATION

### Pattern: "CPU RESET"
→ triple fault occurred

### Pattern: "IRQ spam"
→ PIC misconfigured or PIT too fast

### Pattern: "no interrupt ever appears"
→ PIC fully masked or STI never executed

---

# 6. GOLDEN RULES OF DEBUGGING

## RULE 1:
Always check interrupts before memory.

## RULE 2:
Always check memory before hardware.

## RULE 3:
If CPU resets → assume IDT is broken until proven otherwise.

## RULE 4:
Never trust execution flow after undefined behavior.

---

# 7. FAILURE CHAINS (REAL SYSTEM BEHAVIOR)

Kernel bugs are rarely isolated:

```
missing EOI
→ IRQ freeze
→ interrupt backlog
→ stack overflow
→ triple fault
```

```
no identity mapping
→ VGA crash
→ page fault
→ double fault
→ reset
```

```
wrong GDT
→ segment fault
→ ISR corruption
→ invalid return
```

---

# 8. DEBUGGING TOOL MAPPING

| Symptom | Tool | Flag |
|--------|------|------|
| reboot loop | qemu log | -d cpu_reset |
| irq issue | interrupt trace | -d int |
| memory crash | paging trace | -d mmu |
| IO freeze | full trace | -d guest_errors |

---

# 9. LOW LEVEL ANTI-PATTERNS

NEVER:
- use `ret` in ISR
- enable paging without identity map
- assume interrupts disabled after CLI
- write VGA before mapping memory
- ignore stack alignment

---

# 10. DIAGNOSTIC HEURISTIC ENGINE

When kernel fails:

STEP 1 → check IDT
STEP 2 → check stack
STEP 3 → check paging
STEP 4 → check PIC / IRQ
STEP 5 → check hardware IO

If unsure → assume memory corruption first.

---
