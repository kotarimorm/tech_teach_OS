# tech_teach_OS

Course and reference implementation for building a 32-bit x86 operating system from scratch.

Данный репозиторий представляет собой практическое руководство и кодовую базу для создания 32-битной ОС. Проект ориентирован на разработчиков, энтузиастов и авторов технических материалов, желающих разобраться во внутреннем устройстве операционных систем на низком уровне. 

Стек технологий намеренно сведен к минимуму для чистоты эксперимента: **NASM** (ассемблер) и **QEMU** (эмулятор). Проект адаптирован для сборки и запуска в среде Windows без использования утилит вроде `make`.

---

## Prerequisites

Для сборки и запуска проекта вам потребуется следующий инструментарий под Windows:

* [NASM for Windows](https://www.nasm.us/) (ассемблер)
* [QEMU for Windows](https://www.qemu.org/download/#windows) (эмулятор архитектуры x86)
* Стандартная командная строка Windows (CMD или PowerShell)
Компиляция исходного кода (Pure Assembly):

DOS
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin
Сборка образа диска (Склейка бинарных файлов):

DOS
copy /b boot.bin + kernel.bin os_image.bin
Запуск в эмуляторе QEMU:

DOS
qemu-system-i386 -drive format=raw,file=os_image.bin,index=0,if=floppy

---
### Philosophy
This is a minimal test stand. No C, no makefiles, no dependencies. 
Just raw hardware control and NASM. 
For learning how the iron actually works before building the real thing.
