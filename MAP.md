# OSDev Reference Map

## CPU Setup
- `cpu/gdt.asm` — basic GDT setup
- `cpu/paging.asm` — minimal identity paging
- `cpu/pmm.asm` — bitmap physical memory manager
- `cpu/timer.asm` — PIT timer setup
- `cpu/ports.asm` — I/O port helpers

## Interrupts
- `interrupts/idt.asm` — IDT setup helpers
- `interrupts/isr.asm` — ISR examples
- `interrupts/pic.asm` — PIC remapping

## Drivers
- `drivers/vga.asm` — VGA text output
- `drivers/keyboard/keyboard.asm` — PS/2 keyboard IRQ handler
- `drivers/kbd_buffer.asm` — keyboard circular buffer
- `drivers/disk/ATA.asm` — ATA PIO sector read
- `drivers/pci.asm` — PCI scanning

## Kernel Concepts
- `kernel/panic.asm` — panic screen helper
- `kernel/scheduler.asm` — scheduler/context-switch experiment

## Debugging
- `debug/triple_fault.md` — triple fault checklist
- `debug/troubleshooting.md` — kernel debugging flow
# Snippet Status

This file describes the current role and maturity of each reference file in the repository.

The files are independent by design and are not intended to compile together as one OS.

| File | Status | Notes |
|---|---|---|
| `README.md` | Project overview | Explains the purpose, scope, and philosophy of the repository. |
| `MAP.md` | Navigation | Quick map for finding the right reference file by topic or problem. |
| `cpu/gdt.asm` | Reference | Minimal flat GDT setup for 32-bit protected mode experiments. |
| `cpu/paging.asm` | Experimental | Basic identity paging example; not a complete virtual memory manager. |
| `cpu/pmm.asm` | Unsafe demo | Bitmap-based PMM; does not parse memory maps or reserve kernel regions automatically. |
| `cpu/ports.asm` | Utility | Small I/O port helper macros for low-level hardware access. |
| `cpu/timer.asm` | Reference | PIT timer configuration example; does not install IRQ handlers by itself. |
| `interrupts/idt.asm` | Reference | IDT storage and gate setup helpers; requires valid handlers before interrupts are enabled. |
| `interrupts/isr.asm` | Reference | Basic ISR examples for timer, keyboard, and exceptions. |
| `interrupts/pic.asm` | Reference | Legacy PIC remapping example for moving IRQs away from CPU exception vectors. |
| `drivers/vga.asm` | Reference | Minimal VGA text mode output; no scrolling, newline handling, or bounds checks. |
| `drivers/kbd_buffer.asm` | Utility | Simple circular keyboard buffer for early input experiments. |
| `drivers/keyboard/keyboard.asm` | Experimental | PS/2 keyboard IRQ1 handler; requires scancode translation and kernel integration. |
| `drivers/keyboard/Scancode.md` | Notes | Reference notes for keyboard scancodes. |
| `drivers/disk/ATA.asm` | Unsafe demo | Minimal ATA PIO sector read example; lacks full timeout and error handling. |
| `drivers/pci.asm` | Experimental | Basic PCI bus scanning via CF8/CFC configuration ports. |
| `drivers/manager/manager.asm` | Concept | Simple table-based driver initialization idea. |
| `drivers/manager/drivers.asm` | Stub | Placeholder driver init/handler routines for manager experiments. |
| `kernel/panic.asm` | Debug helper | Minimal VGA panic output that disables interrupts and halts. |
| `kernel/scheduler.asm` | Experimental | Early context-switching idea; not a complete scheduler. |
| `lib/memory.asm` | Utility | Basic memcpy/memset routines; no bounds checking or overlap handling. |
| `lib/print.asm` | Utility | Hex byte print helper; depends on an external `print_char` implementation. |
| `debug/triple_fault.md` | Debug guide | Focused checklist for diagnosing triple faults and instant resets. |
| `debug/troubleshooting.md` | Debug guide | General OS kernel debugging decision system and failure classification. |
