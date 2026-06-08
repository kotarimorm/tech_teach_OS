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
