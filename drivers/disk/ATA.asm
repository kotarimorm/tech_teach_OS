; ============================================================
; File: drivers/disk/ATA.asm
; Topic: ATA PIO Disk Access
; Type: Reference snippet
;
; Purpose:
;   Demonstrates reading one sector using ATA PIO.
;
; Assumes:
;   - Primary ATA bus
;   - Master drive
;   - LBA28 addressing
;   - Destination buffer is valid and writable
;   - ES:EDI points to the destination for string I/O
;
; WARNING:
;   This is a minimal ATA example.
;   It does not provide full error handling.
;   It does not implement timeouts.
;   It does not support all controllers or storage devices.
;
; Notes:
;   - Add BSY/DRQ/ERR/DF checks before serious use.
;   - Add timeouts to avoid infinite waits on broken hardware.
;   - Prefer emulator testing before real hardware experiments.
; ============================================================
; TODO:
;   - Add timeout handling for all wait loops.
;   - Check ERR and DF status bits.
;   - Return success/error status to the caller.
;   - Support reading more than one sector.
;   - Support slave drive selection.
;   - Validate destination buffer assumptions.
;
; FIXME:
;   - The ready-wait logic must distinguish BSY, DRQ, ERR, and DF.
;   - Do not rely on infinite polling loops in real kernels.
[bits 32]

; ============================================================
; Primary ATA PIO ports
; ============================================================
ATA_DATA        equ 0x1F0
ATA_SECTOR_CNT  equ 0x1F2
ATA_LBA_LOW     equ 0x1F3
ATA_LBA_MID     equ 0x1F4
ATA_LBA_HIGH    equ 0x1F5
ATA_DRIVE_HEAD  equ 0x1F6
ATA_COMMAND     equ 0x1F7
ATA_STATUS      equ 0x1F7

; ============================================================
; ata_read_sector
; IN:
;   EAX = LBA sector number
;   EDI = destination buffer (512 bytes)
; OUT:
;   none
; ============================================================
global ata_read_sector

ata_read_sector:
    pusha

    mov ebx, eax              ; save LBA

    ; --------------------------------------------------------
    ; Select drive + LBA mode (master drive assumed)
    ; --------------------------------------------------------
    mov eax, ebx
    shr eax, 24               ; high 4 bits of LBA (LBA28 upper bits)
    and eax, 0x0F

    or al, 0xE0               ; 1110_0000 = LBA + master drive
    mov dx, ATA_DRIVE_HEAD
    out dx, al

    ; --------------------------------------------------------
    ; Sector count = 1
    ; --------------------------------------------------------
    mov dx, ATA_SECTOR_CNT
    mov al, 1
    out dx, al

    ; --------------------------------------------------------
    ; LBA low / mid / high
    ; --------------------------------------------------------
    mov eax, ebx

    mov dx, ATA_LBA_LOW
    out dx, al               ; bits 0–7

    shr eax, 8
    mov dx, ATA_LBA_MID
    out dx, al               ; bits 8–15

    shr eax, 8
    mov dx, ATA_LBA_HIGH
    out dx, al               ; bits 16–23

    ; --------------------------------------------------------
    ; Send READ SECTORS command
    ; --------------------------------------------------------
    mov dx, ATA_COMMAND
    mov al, 0x20
    out dx, al

.wait_ready:
    mov dx, ATA_STATUS
    in al, dx

    ; BSY (bit 7) must be 0, DRQ (bit 3) must be 1
    test al, 0x88
    jnz .wait_ready

    ; --------------------------------------------------------
    ; Read 256 words (512 bytes)
    ; IMPORTANT: must use ES:EDI for insw
    ; --------------------------------------------------------
    mov ecx, 256
    mov dx, ATA_DATA

    rep insw

    popa
    ret
