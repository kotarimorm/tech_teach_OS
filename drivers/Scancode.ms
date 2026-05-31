# Scancode Set 1 Reference

* **Make Code (Press):** Standard byte value emitted when a key is pressed.
* **Break Code (Release):** Calculated as `Make Code + 0x80` (bit 7 set high).
* **Extended Keys:** Emits a two-byte sequence prefixed with `0xE0`.

---

## 1. Standard Keys (Alphanumeric & Punctuations)

| Key | Make Code | Break Code | | Key | Make Code | Break Code |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`Esc`** | `0x01` | `0x81` | | **`P`** | `0x19` | `0x99` |
| **`1`** | `0x02` | `0x82` | | **`[`** | `0x1A` | `0x9A` |
| **`2`** | `0x03` | `0x83` | | **`]`** | `0x1B` | `0x9B` |
| **`3`** | `0x04` | `0x84` | | **`Enter`**| `0x1C` | `0x9C` |
| **`4`** | `0x05` | `0x85` | | **`A`** | `0x1E` | `0x9E` |
| **`5`** | `0x06` | `0x86` | | **`S`** | `0x1F` | `0x9F` |
| **`6`** | `0x07` | `0x87` | | **`D`** | `0x20` | `0xA0` |
| **`7`** | `0x08` | `0x88` | | **`F`** | `0x21` | `0xA1` |
| **`8`** | `0x09` | `0x89` | | **`G`** | `0x22` | `0xA2` |
| **`9`** | `0x0A` | `0x8A` | | **`H`** | `0x23` | `0xA3` |
| **`0`** | `0x0B` | `0x8B` | | **`J`** | `0x24` | `0xA4` |
| **`-`** | `0x0C` | `0x8C` | | **`K`** | `0x25` | `0xA5` |
| **`=`** | `0x0D` | `0x8D` | | **`L`** | `0x26` | `0xA6` |
| **`Backspace`** | `0x0E` | `0x8E` | | **`;`** | `0x27` | `0xA7` |
| **`Tab`** | `0x0F` | `0x8F` | | **`'`** | `0x28` | `0xA8` |
| **`Q`** | `0x10` | `0x90` | | **`` ` ``** | `0x29` | `0xA9` |
| **`W`** | `0x11` | `0x91` | | **`\`** | `0x2B` | `0x9B` |
| **`E`** | `0x12` | `0x92` | | **`Z`** | `0x2C` | `0xAC` |
| **`R`** | `0x13` | `0x93` | | **`X`** | `0x2D` | `0xAD` |
| **`T`** | `0x14` | `0x94` | | **`C`** | `0x2E` | `0xAE` |
| **`Y`** | `0x15` | `0x95` | | **`V`** | `0x2F` | `0xAF` |
| **`U`** | `0x16` | `0x96` | | **`B`** | `0x30` | `0xB0` |
| **`I`** | `0x17` | `0x97` | | **`N`** | `0x31` | `0xB1` |
| **`O`** | `0x18` | `0x98` | | **`M`** | `0x32` | `0xB2` |
| **`,`** | `0x33` | `0xB3` | | **`.`** | `0x34` | `0xB4` |
| **`/`** | `0x35` | `0xB5` | | **`Space`**| `0x39` | `0xB9` |

---

## 2. Function Keys

| Key | Make Code | Break Code | | Key | Make Code | Break Code |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`F1`** | `0x3B` | `0xBB` | | **`F7`** | `0x41` | `0xC1` |
| **`F2`** | `0x3C` | `0xBC` | | **`F8`** | `0x42` | `0xC2` |
| **`F3`** | `0x3D` | `0xBD` | | **`F9`** | `0x43` | `0xC3` |
| **`F4`** | `0x3E` | `0xBE` | | **`F10`**| `0x44` | `0xC4` |
| **`F5`** | `0x3F` | `0xBF` | | **`F11`**| `0x57` | `0xD7` |
| **`F6`** | `0x40` | `0xC0` | | **`F12`**| `0x58` | `0xD8` |

---

## 3. Standard Modifiers & Lock Keys

| Key Name | Make Code | Break Code | Internal State handling notes |
| :--- | :---: | :---: | :--- |
| **`Left Shift`** | `0x2A` | `0xAA` | Set modifier bitmask flag variable. |
| **`Right Shift`**| `0x36` | `0xB6` | Set modifier bitmask flag variable. |
| **`Left Ctrl`** | `0x1D` | `0x9D` | Set modifier bitmask flag variable. |
| **`Left Alt`** | `0x38` | `0xB8` | Set modifier bitmask flag variable. |
| **`Caps Lock`** | `0x3A` | `0xBA` | Toggle state flag + send 0xED command to update LEDs. |
| **`Num Lock`** | `0x45` | `0xC5` | Toggle state flag + send 0xED command to update LEDs. |
| **`Scroll Lock`**| `0x46` | `0xC6` | Toggle state flag + send 0xED command to update LEDs. |

---

## 4. Extended Navigation & Control (0xE0 Prefix Required)

These hardware entities pass two separate read cycles through port `0x60`. Your ISR must capture the `0xE0` state to parse the subsequent byte correctly.

| Key Name | Full Sequence (Make) | Full Sequence (Break) |
| :--- | :---: | :---: |
| **`Arrow Up`** | `0xE0, 0x48` | `0xE0, 0xC8` |
| **`Arrow Down`** | `0xE0, 0x50` | `0xE0, 0xD0` |
| **`Arrow Left`** | `0xE0, 0x4B` | `0xE0, 0xCB` |
| **`Arrow Right`**| `0xE0, 0x4D` | `0xE0, 0xCD` |
| **`Right Ctrl`** | `0xE0, 0x1D` | `0xE0, 0x9D` |
| **`Right Alt`** | `0xE0, 0x38` | `0xE0, 0xB8` |
| **`Insert`** | `0xE0, 0x52` | `0xE0, 0xD2` |
| **`Delete`** | `0xE0, 0x53` | `0xE0, 0xD3` |
| **`Home`** | `0xE0, 0x47` | `0xE0, 0xC7` |
| **`End`** | `0xE0, 0x4F` | `0xE0, 0xCF` |
| **`Page Up`** | `0xE0, 0x49` | `0xE0, 0xC9` |
| **`Page Down`** | `0xE0, 0x51` | `0xE0, 0xD1` |
| **`Keypad Enter`**| `0xE0, 0x1C` | `0xE0, 0x9C` |
| **`Keypad /`** | `0xE0, 0x35` | `0xE0, 0xB5` |
