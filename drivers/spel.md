# Hardware Drivers Specification

- [1. PS/2 Keyboard](#1-ps2-keyboard)
- [2. ATA PIO (Pending)](#)
- [3. VGA Text Mode (Pending)](#)
- [4. PCI Bus (Pending)](#)

---

## 1. PS/2 Keyboard

### I/O Ports
* `0x60` (R/W): Data Port. Reads scancodes, writes controller commands.
* `0x64` (R): Status Register.

### Status Register Bits (Port 0x64)
* **Bit 0 (OBF - Output Buffer Full):** Must be 1 before reading from `0x60`.
* **Bit 1 (IBF - Input Buffer Full):** Must be 0 before writing to `0x60` or `0x64`.

### Port I/O Wait Routines
```assembly
kbd_wait_write:
    in al, 0x64
    test al, 0x02
    jnz kbd_wait_write
    ret

kbd_wait_read:
    in al, 0x64
    test al, 0x01
    jz kbd_wait_read
    ret
Scancode Set 1 ReferencePress (Make Code): Standard byte value.Release (Break Code): Make Code + 0x80 (bit 7 set).Extended Keys: Prefixed with 0xE0 byte.Standard Keys (Make Codes)KeyCodeKeyCodeKeyCodeKeyCodeA0x1EN0x3110x02Space0x39B0x30O0x1820x03Enter0x1CC0x2EP0x1930x04Backspace0x0ED0x20Q0x1040x05Tab0x0FE0x12R0x1350x06Escape0x01F0x21S0x1F60x07G0x22T0x1470x08H0x23U0x1680x09I0x17V0x2F90x0AJ0x24W0x110x00x0BModifiers & Special KeysKey NameMakeBreakDescriptionLeft Shift0x2A0xAAUpdates modifier state variableRight Shift0x360xB6Left Ctrl0x1D0x9DLeft Alt0x380xB8Caps Lock0x3A0xBAToggles keyboard LEDs / internal stateExtended Navigation (0xE0 Prefix Required)Key NameSequence (Make)Sequence (Break)Arrow Up0xE0, 0x480xE0, 0xC8Arrow Down0xE0, 0x500xE0, 0xD0Arrow Left0xE0, 0x4B0xE0, 0xCBArrow Right0xE0, 0x4D0xE0, 0xCDInterrupt Service Routine ImplementationФрагмент коду; Keyboard IRQ 1 Handler
kbd_handler:
    pusha

    ; check if data exists
    in al, 0x64
    test al, 0x01
    jz .empty

    ; read scancode
    in al, 0x60

    ; separate press vs release
    test al, 0x80
    jnz .released

.pressed:
    ; AL = make code
    ; handle buffering here
    jmp .empty

.released:
    and al, 0x7F
    ; AL = clean scancode of released key

.empty:
    ; send EOI to master PIC
    mov al, 0x20
    out 0x20, al

    popa
    iret
