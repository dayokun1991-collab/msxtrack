; MSX BIOS entry points and system variables (MSX1 standard - valid on all models)

RDSLT   equ 000Ch
CALSLT  equ 001Ch
ENASLT  equ 0024h
FILVRM  equ 0056h
LDIRMV  equ 0059h       ; VRAM(HL) -> RAM(DE), BC bytes
LDIRVM  equ 005Ch       ; RAM(HL) -> VRAM(DE), BC bytes
CHGCLR  equ 0062h
INITXT  equ 006Ch
GICINI  equ 0090h
CHSNS   equ 009Ch
CHGET   equ 009Fh
BEEP    equ 00C0h
ERAFNK  equ 00CCh
TAPION  equ 00E1h
TAPIN   equ 00E4h
TAPIOF  equ 00E7h
TAPOON  equ 00EAh
TAPOUT  equ 00EDh
TAPOOF  equ 00F0h
RSLREG  equ 0138h
SNSMAT  equ 0141h
KILBUF  equ 0156h

DISKVE  equ 0F323h      ; pointer to pointer to disk error handler
BREAKV  equ 0F325h      ; pointer to pointer to break (abort) handler
BDOS    equ 0F37Dh      ; Disk BASIC BDOS entry
LINL40  equ 0F3AEh
CRTCNT  equ 0F3B1h
TXTNAM  equ 0F3B3h
TXTCGP  equ 0F3B7h
CLIKSW  equ 0F3DBh
CNSDFG  equ 0F3DEh
SCNCNT  equ 0F3F6h
FORCLR  equ 0F3E9h
BAKCLR  equ 0F3EAh
BDRCLR  equ 0F3EBh
FNKSTR  equ 0F87Fh
HIMEM   equ 0FC4Ah
CSRSW   equ 0FCA9h
EXPTBL  equ 0FCC1h
SLTTBL  equ 0FCC5h
H_TIMI  equ 0FD9Fh
H_STKE  equ 0FEDAh
H_PHYD  equ 0FFA7h

PSG_ADR equ 0A0h
PSG_WR  equ 0A1h
