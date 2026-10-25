; ---------------------------------------------------------------------------
; RAM layout (page 3, starting at C000h - present on every MSX with >=16KB)
; Nothing here is stored in the ROM image; the build truncates it away.
; ---------------------------------------------------------------------------

        org 0C000h

SCRBUF:     ds 960          ; 40x24 text screen mirror
PATBUF:     ds PATSIZE      ; pattern clipboard (also font-inversion scratch)
TRKBUF:     ds 256          ; track clipboard (must follow PATBUF)
INSBUF:     ds INSSZ        ; instrument clipboard
UNDOBUF:    ds PATSIZE      ; pattern before the last edit
DIRBUF:     ds DIRMAX*8     ; disk directory names

; ---- song data block (saved/loaded as one piece) --------------------------
SONGDATA:
SNG_SPEED:  ds 1            ; ticks per row
SNG_PATLEN: ds 1            ; rows per pattern (1..64)
SNG_LEN:    ds 1            ; order list length (1..128)
SNG_LOOP:   ds 1            ; restart position
SNG_NAME:   ds 16
            ds 12           ; reserved
ORDERS:     ds ORDMAX
INSTR:      ds NINS*INSSZ
SONGDATA_END:

PATTAB:     ds MAXPAT*2     ; address of every pattern
NUMPAT:     ds 1            ; patterns that fit in this machine's RAM
RAMTOP:     ds 2
PAGE2RAM:   ds 1
MYSLOT:     ds 1
HASDISK:    ds 1
OLDTIMI:    ds 5            ; previous H.TIMI contents (chained)

; ---- player state ----------------------------------------------------------
CHAN0:      ds CHSIZE
CHAN1:      ds CHSIZE
CHAN2:      ds CHSIZE
PSGREG:     ds 14
PL_ORDERS:  ds 2            ; -> order list
PL_INSTR:   ds 2            ; -> instrument 0
PL_PLAYING: ds 1            ; 0 stop, 1 song, 2 pattern loop
PL_TICK:    ds 1
PL_SPEED:   ds 1
PL_ORDPOS:  ds 1
PL_ROW:     ds 1
PL_PATPTR:  ds 2
PL_JUMP:    ds 1
PL_BREAK:   ds 1
PL_FIRST:   ds 1
PL_ENVTRIG: ds 1
PL_ENVMAN:  ds 1
PL_ROWFLAG: ds 1
PL_DISPROW: ds 1
PL_DISPORD: ds 1
PU_BIT:     ds 1

; ---- user interface state --------------------------------------------------
PCUR:       ds 2            ; print position in SCRBUF
INVM:       ds 1            ; 80h = print inverted
DIRTY:      ds 1
SCREEN:     ds 1
FKPREV:     ds 1
R8PREV:     ds 1
R8REP:      ds 1
MSGPTR:     ds 2
ED_ORD:     ds 1
ED_ROW:     ds 1
ED_CH:      ds 1
ED_COL:     ds 1
ED_OCT:     ds 1
ED_INS:     ds 1
ED_STEP:    ds 1
ED_FOLLOW:  ds 1
SG_FIELD:   ds 1
SG_POS:     ds 1
SG_NPOS:    ds 1
IN_ROW:     ds 1
IN_COL:     ds 1
IN_NPOS:    ds 1
IN_TEST:    ds 1
HELPPG:     ds 1
ED_JAM:     ds 1
UNDOPAT:    ds 1            ; pattern saved in UNDOBUF (FF = none)
SONGMOD:    ds 1            ; song changed since load/save
JAM_CUT:    ds 1
DIRCNT:     ds 1
TMPW:       ds 2
CHKSUM:     ds 1

; ---- file I/O ----------------------------------------------------------------
FILENAME:   ds 8
FILEHDR:    ds 8
FCB:        ds 37
SAVESP:     ds 2
OLDDSKVE:   ds 2
OLDBRKV:    ds 2
DSKERR:     ds 1
DSKVEPTR:   ds 2            ; pointer variables handed to Disk BASIC
BRKVPTR:    ds 2
RAMSTUB:    ds RAMSTUB_LEN  ; disk error/abort handlers (must run from RAM)
DMABUF:     ds 128

VARS_END:
