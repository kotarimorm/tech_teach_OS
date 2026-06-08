# tech_teach_OS

A practical collection of low-level OSDev references for people building their own operating system from scratch.

This repository is **not a complete operating system**, **not a bootable kernel**, and **not a framework**.

Instead, it is a collection of independent NASM x86 assembly snippets, hardware experiments, debugging notes, and small reference implementations for common OS development topics.

## Topics Covered

* GDT
* IDT
* PIC
* ISR
* PIT timer
* Paging
* Physical memory management
* VGA text mode
* PS/2 keyboard input
* ATA PIO disk access
* PCI scanning
* Scheduler experiments
* Kernel panic/debug helpers
* Triple fault troubleshooting

---

## Goal

The purpose of this repository is simple:

> When your kernel explodes at 3 AM, this repository should help you remember how the low-level pieces work.

The project acts as a practical reference while building your own operating system.

Files are intentionally small, focused, independent, and easy to study.

---

## What This Repository Is

* A learning resource
* A debugging companion
* A collection of OSDev notes
* A hardware experimentation stand
* A source of small reusable NASM examples

Each file focuses on one concept rather than trying to build a complete system.

---

## What This Repository Is Not

This repository is **not**:

* a finished operating system
* a bootable disk image
* a full kernel source tree
* a universal OSDev library
* a production-ready framework

Files are independent by design and are not intended to compile together as one OS.

---

## Repository Layout

```text
cpu/
interrupts/
drivers/
kernel/
lib/
debug/
```

Examples include:

* cpu/gdt.asm
* cpu/paging.asm
* interrupts/idt.asm
* interrupts/pic.asm
* drivers/keyboard/keyboard.asm
* drivers/disk/ATA.asm
* kernel/panic.asm
* debug/triple_fault.md
* debug/troubleshooting.md

---

## How To Use

1. Pick the topic you are working on.
2. Open the matching file.
3. Study the implementation and comments.
4. Adapt it to your own kernel.
5. Test it in your own OSDev environment.

Examples:

* Working on protected mode → `cpu/gdt.asm`
* Debugging triple faults → `debug/triple_fault.md`
* Setting up interrupts → `interrupts/idt.asm`
* Writing a keyboard driver → `drivers/keyboard/keyboard.asm`

---

## Philosophy

One concept.

One file.

One thing to understand.

No unnecessary abstractions.

No hidden framework.

Just NASM, x86 hardware, registers, interrupts, memory management, and debugging notes.

The goal is to understand how the machine actually behaves before building something larger.

---

## Tooling

Recommended:

* NASM
* QEMU
* Text editor
* Your own OS project

No specific build system is required.

---

## Status

**BETA**

Expect:

* incomplete examples
* experimental code
* rough edges
* debugging-oriented implementations

This repository exists as a reference stand, not a finished product.

---

## Project Goal

The final goal is not to ship an operating system from this repository.

The goal is to build a practical collection of low-level references that helps OSDev learners and hobby kernel developers move faster when working on their own systems.

If this repository saves someone from wasting two hours on a triple fault, it is doing its job.
