; ===========================================================================
;  MSXTRACK - all-in-one chiptune / sound effect tracker for MSX1
;
;  16KB ROM cartridge (4000h-7FFFh). Uses only BIOS calls for video and
;  keyboard and the standard PSG ports, so it runs on every MSX1, MSX2,
;  MSX2+ and turbo R with at least 16KB of RAM.
;
;  Build:  pasmo --bin main.asm msxtrack.bin   (see build.sh)
; ===========================================================================

        include "bios.inc"

NOTE_OFF    equ 97
PATROWS     equ 64
ROWSZ       equ 12          ; 3 channels x 4 bytes
PATSIZE     equ PATROWS*ROWSZ
NINS        equ 16          ; instrument slots (1..15 usable)
INSSZ       equ 96
ORDMAX      equ 128
MAXPAT      equ 64
DIRMAX      equ 40
STACKRES    equ 512

SCR_PAT     equ 0
SCR_SONG    equ 1
SCR_INS     equ 2
SCR_FILE    equ 3
SCR_HELP    equ 4

; print a literal string at row r, column c
PRINTAT macro prow,pcol,ptxt
        local pa_s,pa_e
        ld bc,prow*256+pcol
        ld hl,pa_s
        call at_pstr
        jr pa_e
pa_s:   db ptxt,0
pa_e:
        endm

; print a literal string at the current position
PRINT   macro ptxt
        local pr_s,pr_e
        ld hl,pr_s
        call pstr
        jr pr_e
pr_s:   db ptxt,0
pr_e:
        endm

        org 4000h
        db "AB"
        dw rom_init
        dw 0,0,0
        ds 6,0

; ---------------------------------------------------------------------------
; Cartridge INIT: only hook H.STKE, so we start after every other ROM
; (including disk interfaces) has been initialised.
; ---------------------------------------------------------------------------
rom_init:
        call RSLREG
        rrca
        rrca
        and 3
        ld c,a
        ld b,0
        ld hl,EXPTBL
        add hl,bc
        ld a,(hl)
        and 80h
        or c
        ld c,a
        jr z,ri_noexp
        bit 7,a
        jr z,ri_noexp
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        and 0Ch
        or c
        ld c,a
ri_noexp:
        di
        ld a,0F7h               ; RST 30h = inter-slot call
        ld (H_STKE),a
        ld a,c
        ld (H_STKE+1),a
        ld hl,start
        ld (H_STKE+2),hl
        ld a,0C9h
        ld (H_STKE+4),a
        ei
        ret

; ---------------------------------------------------------------------------
; Program start (called through H.STKE, never returns)
; ---------------------------------------------------------------------------
start:
        di
        ld a,(H_STKE+1)
        ld b,a
        ld a,0C9h
        ld (H_STKE),a
        ; top of usable RAM: HIMEM (lowered by disk interfaces), at most
        ; F370h so the stack never touches the BDOS entry at F37Dh
        ld hl,(HIMEM)
        ld a,h
        cp 0C0h
        jr c,st_top380
        push hl
        ld de,0F371h
        or a
        sbc hl,de
        pop hl
        jr c,st_topok
st_top380:
        ld hl,0F370h
st_topok:
        ; need RAM from C000h up to the pattern area + stack
        push hl
        ld de,PATBASE+STACKRES+PATSIZE
        or a
        sbc hl,de
        pop hl
        jp c,no_memory
        call test_c000
        jp nz,no_memory
        ld sp,hl
        push hl
        push bc
        ; clear our RAM
        ld hl,SCRBUF
        ld de,SCRBUF+1
        ld bc,VARS_END-SCRBUF-1
        ld (hl),0
        ldir
        pop bc
        ld a,b
        ld (MYSLOT),a
        pop hl
        ld (RAMTOP),hl
        ld a,(H_PHYD)
        cp 0C9h
        ld a,0
        jr z,st_nodisk
        inc a
st_nodisk:
        ld (HASDISK),a
        call init_screen
        ld a,1
        ld (SCNCNT),a           ; scan the keyboard on the next interrupt
        call GICINI
        ld hl,ORDERS
        ld (PL_ORDERS),hl
        ld hl,INSTR
        ld (PL_INSTR),hl
        call build_pattab
        call init_ramstub
        call new_song
        call load_demo
        call mark_saved
        ld a,4
        ld (ED_OCT),a
        ld a,1
        ld (ED_INS),a
        ld (ED_STEP),a
        ld (ED_FOLLOW),a
        ld a,30
        ld (JAM_CUT),a
        ld a,3
        ld (IN_ROW),a
        call reset_chans
        ; hook the interrupt (chain the previous hook, e.g. disk motor)
        di
        ld hl,H_TIMI
        ld de,OLDTIMI
        ld bc,5
        ldir
        ld a,0F7h
        ld (H_TIMI),a
        ld a,(MYSLOT)
        ld (H_TIMI+1),a
        ld hl,isr
        ld (H_TIMI+2),hl
        ld a,0C9h
        ld (H_TIMI+4),a
        ei
        ld a,1
        ld (DIRTY),a

; ---------------------------------------------------------------------------
; Main loop
; ---------------------------------------------------------------------------
mainloop:
        ei
        halt
        call poll_fkeys
ml_keys:
        call CHSNS
        jr z,ml_nokey
        call CHGET
        call key_from_bios
        jr ml_keys
ml_nokey:
        ld a,(PL_ROWFLAG)
        or a
        jr z,ml_test
        xor a
        ld (PL_ROWFLAG),a
        ld a,1
        ld (DIRTY),a
        ld a,(ED_FOLLOW)
        or a
        jr z,ml_test
        ld a,(SCREEN)
        cp SCR_PAT
        jr nz,ml_test
        ld a,(PL_PLAYING)
        or a
        jr z,ml_test
        ld a,(PL_DISPROW)
        ld (ED_ROW),a
        ld a,(PL_DISPORD)
        ld (ED_ORD),a
ml_test:
        ld a,(SCREEN)           ; instrument screen shows the live step
        cp SCR_INS
        jr nz,ml_draw
        ld a,(CHAN0+C_ACTIVE)
        or a
        jr z,ml_draw
        ld a,1
        ld (DIRTY),a
ml_draw:
        ld a,(DIRTY)
        or a
        jr z,mainloop
        xor a
        ld (DIRTY),a
        call draw_screen
        call flush
        jr mainloop

draw_screen:
        call cls
        ld a,(SCREEN)
        ld hl,draw_table
        call jump_index
        jp draw_footer

draw_table:
        dw draw_pat,draw_song,draw_ins,draw_file,draw_help

; A = index, HL = table of addresses -> jump
jump_index:
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

; ---- keyboard ----
; HOME, INS and DEL come from the key matrix (C-BIOS does not translate
; them), so their BIOS codes are dropped here.
key_from_bios:
        cp 11
        ret z
        cp 12
        ret z
        cp 18
        ret z
        cp 127
        ret z
key_dispatch:
        ld c,a
        ld a,1
        ld (DIRTY),a
        ld hl,0
        ld (MSGPTR),hl
        ld a,c
        cp 'a'
        jr c,kd_up
        cp 'z'+1
        jr nc,kd_up
        sub 32
kd_up:  ld c,a
        cp 'A'                  ; CTRL+letter -> 1..26 on every BIOS
        jr c,kd_ctl
        cp 'Z'+1
        jr nc,kd_ctl
        push bc
        ld a,6
        call SNSMAT
        pop bc
        bit 1,a
        ld a,c
        jr nz,kd_ctl
        sub 64
        ld c,a
kd_ctl: ld a,c
        cp 27                   ; ESC: stop everything
        jr nz,kd_scr
        xor a
        ld (IN_TEST),a
        jp play_stop
kd_scr: ld c,a
        ld a,(SCREEN)
        ld hl,key_table
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        jp (hl)

key_table:
        dw pat_key,song_key,ins_key,file_key,help_key

; returns Z if SHIFT is held
shift_held:
        push bc
        push de
        push hl
        ld a,6
        call SNSMAT
        pop hl
        pop de
        pop bc
        bit 0,a
        ret

; function keys are read from the keyboard matrix (layout independent)
poll_fkeys:
        call poll_row8
        ld a,6
        call SNSMAT
        cpl
        ld b,a
        ld a,7
        call SNSMAT
        cpl
        and 3
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,b
        rlca
        rlca
        rlca
        and 7
        or c
        ld d,a                  ; bit0..4 = F1..F5 held
        ld a,(FKPREV)
        cpl
        and d
        ld e,a
        ld a,d
        ld (FKPREV),a
        ld a,e
        or a
        ret z
        ld c,0
pf_find:
        rrca
        jr c,pf_found
        inc c
        jr pf_find
pf_found:
        ld a,1
        ld (DIRTY),a
        bit 0,b                 ; SHIFT -> F6..F10
        jr nz,pf_shift
        ld a,c
        ld (SCREEN),a
        ret
pf_shift:
        ld a,c
        cp 3
        jr c,pf_mute
        jr nz,pf_f10
        ld hl,ED_FOLLOW         ; F9: follow on/off
        ld a,(hl)
        xor 1
        ld (hl),a
        ret
pf_f10: ld hl,CHAN0+C_MUTE      ; F10: unmute all
        xor a
        ld (CHAN0+C_MUTE),a
        ld (CHAN1+C_MUTE),a
        ld (CHAN2+C_MUTE),a
        ret
pf_mute:
        call chan_ix
        ld a,(ix+C_MUTE)
        xor 1
        ld (ix+C_MUTE),a
        ret

; HOME / INS / DEL with auto-repeat
poll_row8:
        ld a,8
        call SNSMAT
        cpl
        and 0Eh                 ; bits 1-3: HOME, INS, DEL held
        ld d,a
        ld a,(R8PREV)
        ld e,a
        ld a,d
        ld (R8PREV),a
        cp e
        jr nz,pr8_change
        or a
        ret z
        ld hl,R8REP
        dec (hl)
        ret nz
        ld (hl),3
        jr pr8_go
pr8_change:
        ld a,20
        ld (R8REP),a
        ld a,e
        cpl
        and d
pr8_go: or a
        ret z
        ld e,11
        bit 1,a
        jr nz,pr8_key
        ld e,18
        bit 2,a
        jr nz,pr8_key
        ld e,127
pr8_key:
        ld a,e
        jp key_dispatch

; ---------------------------------------------------------------------------
; Initialisation helpers
; ---------------------------------------------------------------------------
init_screen:
        xor a
        ld (CLIKSW),a
        ld (CNSDFG),a
        ld (CSRSW),a
        ld a,40
        ld (LINL40),a
        ld a,24
        ld (CRTCNT),a
        ld a,15
        ld (FORCLR),a
        ld a,4
        ld (BAKCLR),a
        ld (BDRCLR),a
        call INITXT
        call CHGCLR
        call ERAFNK
        ld hl,FNKSTR            ; function keys must not type text
        ld de,16
        ld b,10
is_fk:  ld (hl),0
        add hl,de
        djnz is_fk
        call KILBUF
        ; characters 128-255 = inverted copies of 0-127
        ld hl,(TXTCGP)
        ld de,PATBUF
        ld bc,1024
        call LDIRMV
        ld hl,PATBUF
        ld bc,1024
is_inv: ld a,(hl)
        cpl
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,is_inv
        ld hl,(TXTCGP)
        ld de,1024
        add hl,de
        ex de,hl
        ld hl,PATBUF
        ld bc,1024
        call LDIRVM
        call cls
        jp flush

; Find RAM for patterns: page 2 (8000h-BFFFh) if present, then the rest of
; page 3 above our variables up to RAMTOP - stack.
build_pattab:
        xor a
        ld (NUMPAT),a
        ld (PAGE2RAM),a
        call test_page2
        jr nz,bp_nop2
        ld a,1
        ld (PAGE2RAM),a
        ld hl,8000h
        ld de,0C000h-PATSIZE
        call bp_fill
bp_nop2:
        ld hl,(RAMTOP)
        ld de,STACKRES+PATSIZE
        or a
        sbc hl,de
        ex de,hl                ; DE = last start address allowed
        ld hl,PATBASE
bp_fill:                        ; add patterns from HL while HL <= DE
        ld a,(NUMPAT)
        cp MAXPAT
        ret nc
        push hl
        or a
        sbc hl,de
        pop hl
        jr z,bp_add
        ret nc
bp_add: push hl
        push de
        ex de,hl
        ld a,(NUMPAT)
        ld l,a
        ld h,0
        add hl,hl
        ld bc,PATTAB
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,NUMPAT
        inc (hl)
        pop de
        pop hl
        ld bc,PATSIZE
        add hl,bc
        jr bp_fill

; Z if 8000h-BFFFh is writable RAM that does not mirror page 3
test_page2:
        ld hl,8000h
        call tp_one
        ret nz
        ld hl,0BFFFh
tp_one: ld a,(hl)
        ld c,a
        ld a,(SCRBUF)
        ld b,a
        ld a,55h
        ld (hl),a
        ld a,0AAh
        ld (SCRBUF),a
        ld a,(hl)
        cp 55h
        jr nz,tp_bad
        cpl
        ld (hl),a
        ld a,(hl)
        cp 0AAh
        jr nz,tp_bad
        ld a,(SCRBUF)
        cp 0AAh
tp_bad: ld (hl),c
        ld a,b
        ld (SCRBUF),a
        ret

; Z if C000h-DFFFh is RAM (rules out 8KB machines). Preserves BC, HL.
test_c000:
        ld a,(0C000h)
        ld d,a
        ld a,(0E000h)
        ld e,a
        ld a,5Ah
        ld (0C000h),a
        cpl
        ld (0E000h),a
        ld a,(0C000h)
        cp 5Ah
        ld a,d
        ld (0C000h),a
        ld a,e
        ld (0E000h),a
        ret

no_memory:
        call INITXT
        ld hl,nomem_msg
        ld de,(TXTNAM)
        ld bc,nomem_end-nomem_msg
        call LDIRVM
nm_hang:
        jr nm_hang
nomem_msg:
        db "MSXTRACK needs 16KB of free RAM."
nomem_end:

; Disk error and abort handlers live in RAM: the disk ROM pages itself into
; page 1 while it calls them.
init_ramstub:
        ld hl,ramstub_src
        ld de,RAMSTUB
        ld bc,RAMSTUB_LEN
        ldir
        ld hl,RAMSTUB
        ld (DSKVEPTR),hl
        ld hl,RAMSTUB+(rs_brk-ramstub_src)
        ld (BRKVPTR),hl
        ret

ramstub_src:
        ld a,1                  ; disk error -> remember, answer "abort"
        ld (DSKERR),a
        ld a,2
        ld c,2
        ret
rs_brk: di                      ; abort -> back to our page 1 and stack
        ld sp,(SAVESP)
        ld a,(MYSLOT)
        ld h,40h
        call ENASLT
        ei
        jp disk_aborted
RAMSTUB_LEN equ $-ramstub_src

        include "ui.asm"
        include "player.asm"
        include "edpat.asm"
        include "edsong.asm"
        include "edins.asm"
        include "file.asm"
        include "help.asm"
        include "song.asm"
        include "tables.inc"

ROM_END:
        ds 8000h-$,0FFh

        include "vars.asm"
PATBASE equ (VARS_END+0FFh)/256*256
