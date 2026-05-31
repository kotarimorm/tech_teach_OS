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
