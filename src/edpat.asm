; ===========================================================================
; Pattern editor (F1)
; ===========================================================================

draw_pat:
        call draw_title
        PRINTAT 1,0,"ORD "
        ld a,(ED_ORD)
        call phex2
        ld a,'/'
        call pch
        ld a,(SNG_LEN)
        dec a
        call phex2
        PRINT " PAT "
        call cur_patnum
        call phex2
        PRINT " ROW "
        ld a,(ED_ROW)
        call phex2
        PRINT " SPEED "
        ld a,(SNG_SPEED)
        call phex2
        PRINT " STEP "
        ld a,(ED_STEP)
        call phex2
        PRINTAT 2,0,"INS "
        ld a,(ED_INS)
        call phex1
        call pspc
        ld a,(ED_INS)
        call ins_addr
        ld de,I_NAME
        add hl,de
        ld b,8
        call pfix
        PRINT "  OCT "
        ld a,(ED_OCT)
        call phex1
        PRINT "  FOLLOW "
        ld a,(ED_FOLLOW)
        or a
        jr z,dp_foff
        PRINT "ON"
        jr dp_hdr
dp_foff:
        PRINT "OFF"
dp_hdr: PRINTAT 3,0,"RW "
        ld ix,CHAN0
        ld c,'A'
        call dp_chhdr
        ld ix,CHAN1
        ld c,'B'
        call dp_chhdr
        ld ix,CHAN2
        ld c,'C'
        call dp_chhdr
        call pat_hint
        ; 18 pattern rows, cursor row in the middle (screen row 12)
        ld a,(ED_ROW)
        sub 8
        ld c,a
        ld b,4
dp_rows:
        push bc
        ld a,c
        bit 7,a
        jr nz,dp_skip
        ld hl,SNG_PATLEN
        cp (hl)
        jr nc,dp_skip
        call draw_prow
dp_skip:
        pop bc
        inc c
        inc b
        ld a,b
        cp 22
        jr c,dp_rows
        ; cursor field
        ld a,(ED_COL)
        ld e,a
        ld d,0
        ld hl,col_offs
        add hl,de
        ld a,(ED_CH)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        sub c                   ; *11
        add a,3
        add a,(hl)
        ld e,a
        ld c,1
        ld a,(ED_COL)
        or a
        jr nz,dp_cw
        ld c,3
dp_cw:  ld b,12
        jp hilite

col_offs:
        db 0,4,5,7,8,9

dp_chhdr:
        ld a,(ix+C_MUTE)
        or a
        jr nz,dpc_m
        PRINT "CHANNEL "
        ld a,c
        call pch
        call pspc
        jr dpc_e
dpc_m:  ld a,c
        call pch
        PRINT "  MUTED  "
dpc_e:  ld a,'|'
        jp pch

; B = screen row, A = pattern row
draw_prow:
        ld (TMPW),a
        ld c,0
        call at
        ld hl,ED_ROW
        cp (hl)
        ld a,0
        jr nz,dpr_n
        ld a,80h
dpr_n:  ld (INVM),a
        ld a,(TMPW)
        call phex2
        ; play position marker / beat marker
        ld a,(PL_PLAYING)
        or a
        jr z,dpr_beat
        ld a,(PL_DISPORD)
        ld hl,ED_ORD
        cp (hl)
        jr nz,dpr_beat
        ld a,(PL_DISPROW)
        ld hl,TMPW
        cp (hl)
        ld a,'>'
        jr z,dpr_mark
dpr_beat:
        ld a,(TMPW)
        and 3
        ld a,' '
        jr nz,dpr_mark
        ld a,'.'
dpr_mark:
        call pch
        call cur_pat_addr
        push hl
        ld a,(TMPW)
        call row_offset
        pop de
        add hl,de
        ld b,3
dpr_ch: push bc
        call draw_cell
        ld a,'|'
        call pch
        pop bc
        djnz dpr_ch
        xor a
        ld (INVM),a
        ret

; HL = cell -> printed as "C-4 1F A03", HL += 4
draw_cell:
        ld a,(hl)
        push hl
        call pnote
        pop hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call pspc
        ld a,e
        and 0F0h
        jr z,dc_noi
        rrca
        rrca
        rrca
        rrca
        call phex1
        jr dc_vol
dc_noi: ld a,'.'
        call pch
dc_vol: bit 7,d
        jr z,dc_nov
        ld a,e
        call phex1
        jr dc_fx
dc_nov: ld a,'.'
        call pch
dc_fx:  call pspc
        bit 6,d
        jr z,dc_nofx
        ld a,d
        call phex1
        ld a,c
        call phex2
        pop hl
        ret
dc_nofx:
        ld a,'.'
        ld b,3
        call prep
        pop hl
        ret

; print note A as "C#4", "---" (empty) or "===" (note off)
pnote:  or a
        jr nz,pn_1
        ld a,'-'
        ld b,3
        jp prep
pn_1:   cp NOTE_OFF
        jr c,pn_2
        ld a,'='
        ld b,3
        jp prep
pn_2:   dec a
        ld c,'1'
pn_div: cp 12
        jr c,pn_d
        sub 12
        inc c
        jr pn_div
pn_d:   add a,a
        ld e,a
        ld d,0
        ld hl,notenames
        add hl,de
        ld a,(hl)
        call pch
        inc hl
        ld a,(hl)
        call pch
        ld a,c
        jp pch

notenames:
        db "C-C#D-D#E-F-F#G-G#A-A#B-"

; ---- addressing helpers ----
cur_patnum:
        ld a,(ED_ORD)
        ld e,a
        ld d,0
        ld hl,ORDERS
        add hl,de
        ld a,(hl)
        ret

cur_pat_addr:
        call cur_patnum
        jp get_pat_addr

; A = row -> HL = cell of the cursor channel (preserves BC)
cell_at:
        push af
        call cur_pat_addr
        pop af
        push hl
        call row_offset
        pop de
        add hl,de
        ld a,(ED_CH)
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ret

cur_cell:
        ld a,(ED_ROW)
        jr cell_at

; HL = table of key/handler pairs, A = key. Z + HL = handler if found
find_key:
        ld c,a
fk_lp:  ld a,(hl)
        or a
        jr z,fk_nf
        cp c
        inc hl
        jr z,fk_f
        inc hl
        inc hl
        jr fk_lp
fk_f:   ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        cp a
        ret
fk_nf:  ld a,c
        or a
        ret nz
        inc a
        ret

; ---------------------------------------------------------------------------
pat_key:
        ld hl,pat_keytab
        call find_key
        jr nz,pat_other
        jp (hl)

pat_keytab:
        db 28
        dw pk_right
        db 29
        dw pk_left
        db 30
        dw pk_up
        db 31
        dw pk_down
        db 9
        dw pk_tab
        db 11
        dw pk_home
        db 32
        dw pk_space
        db 13
        dw pk_return
        db 127
        dw pk_del
        db 8
        dw pk_bs
        db 18
        dw pk_ins
        db '['
        dw octave_dn
        db ']'
        dw octave_up
        db ','
        dw ins_dn
        db '.'
        dw ins_up
        db '<'
        dw pk_patdn
        db '>'
        dw pk_patup
        db '-'
        dw pk_stepdn
        db '='
        dw pk_stepup
        db '+'
        dw pk_stepup
        db '^'
        dw pk_stepup
        db 3
        dw pk_copytrk
        db 22
        dw pk_pastetrk
        db 1
        dw pk_copypat
        db 16
        dw pk_pastepat
        db 21
        dw pk_trup
        db 4
        dw pk_trdn
        db 5
        dw pk_cleartrk
        db 26
        dw pk_undo
        db 10
        dw pk_jam
        db 14
        dw pk_newpos
        db 2
        dw pk_clonepos
        db 0

pat_other:
        ld c,a
        ld a,(ED_COL)
        or a
        ld a,c
        jp z,pat_note_key
        call hexval
        ret c
        push af
        call snapshot
        pop af
        ld c,a
        call cur_cell
        inc hl
        ld a,(ED_COL)
        cp 1
        jr nz,po_vol
        ld a,(hl)               ; instrument
        and 0Fh
        ld b,a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        or b
        ld (hl),a
        ld a,c
        or a
        jr z,advance
        ld (ED_INS),a
        jr advance
po_vol: cp 2
        jr nz,po_fx
        ld a,(hl)               ; volume
        and 0F0h
        or c
        ld (hl),a
        inc hl
        set 7,(hl)
        jr advance
po_fx:  inc hl
        cp 3
        jr nz,po_fxp
        ld a,(hl)               ; effect command
        and 80h
        or c
        or 40h
        ld (hl),a
        ld a,4
        ld (ED_COL),a
        ret
po_fxp: set 6,(hl)
        inc hl
        cp 4
        jr nz,po_lo
        ld a,(hl)
        and 0Fh
        ld b,a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        or b
        ld (hl),a
        ld a,5
        ld (ED_COL),a
        ret
po_lo:  ld a,(hl)
        and 0F0h
        or c
        ld (hl),a
        ld a,3
        ld (ED_COL),a
        ; fall through

; move the cursor down by the edit step
advance:
        ld a,(ED_STEP)
        ld b,a
        ld a,(ED_ROW)
        add a,b
        ld hl,SNG_PATLEN
adv_w:  cp (hl)
        jr c,adv_ok
        sub (hl)
        jr adv_w
adv_ok: ld (ED_ROW),a
        ret

pat_note_key:
        cp '1'
        jr nz,pnk_1
        ld d,NOTE_OFF
        jr pnk_write
pnk_1:  ld c,a
        ld hl,pianokeys
        ld b,0
pnk_s:  ld a,(hl)
        or a
        ret z
        cp c
        jr z,pnk_f
        inc hl
        inc b
        jr pnk_s
pnk_f:  ld a,(ED_OCT)
        call oct_base
        add a,b
        cp NOTE_OFF
        ret nc
        ld d,a
pnk_write:
        ld a,(ED_JAM)           ; jam mode: only play the note
        or a
        jr z,pnk_rec
        ld a,(ED_INS)
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld bc,0
        ld a,(ED_CH)
        jp jam_cell
pnk_rec:
        push de
        call snapshot
        pop de
        push de
        call cur_cell
        pop de
        ld (hl),d
        inc hl
        ld a,d
        cp NOTE_OFF
        jr z,pnk_j
        ld a,(ED_INS)
        or a
        jr z,pnk_j
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,(hl)
        and 0Fh
        or b
        ld (hl),a
pnk_j:  call jam_cur
        jr advance

; A = octave -> A = first note of that octave (C)
oct_base:
        dec a
        ld e,a
        add a,a
        add a,e
        add a,a
        add a,a
        inc a
        ret

pianokeys:
        db "ZSXDCVGBHNJMQ2W3ER5T6Y7UI9O0P",0

; preview the cell under the cursor (only while stopped)
jam_cur:
        ld a,(PL_PLAYING)
        or a
        ret nz
        call cur_cell
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld a,(ED_CH)
        jp jam_cell

; ---- cursor movement ----
pk_right:
        call shift_held
        jr z,pk_ordnext
        ld a,(ED_COL)
        inc a
        cp 6
        jr c,pk_setcol
        ld a,(ED_CH)
        inc a
        cp 3
        jr c,pkr_1
        xor a
pkr_1:  ld (ED_CH),a
        xor a
pk_setcol:
        ld (ED_COL),a
        ret

pk_left:
        call shift_held
        jr z,pk_ordprev
        ld a,(ED_COL)
        dec a
        jp p,pk_setcol
        ld a,(ED_CH)
        dec a
        jp p,pkl_1
        ld a,2
pkl_1:  ld (ED_CH),a
        ld a,5
        jr pk_setcol

pk_ordnext:
        ld a,(ED_ORD)
        inc a
        ld hl,SNG_LEN
        cp (hl)
        ret nc
        jr pk_setord
pk_ordprev:
        ld a,(ED_ORD)
        or a
        ret z
        dec a
pk_setord:
        ld (ED_ORD),a
        ret

pk_up:  call shift_held
        ld a,(ED_ROW)
        jr z,pku_pg
        or a
        jr nz,pku_1
        ld a,(SNG_PATLEN)
pku_1:  dec a
        jr pk_setrow
pku_pg: sub 16
        jr nc,pk_setrow
        xor a
        jr pk_setrow

pk_down:
        call shift_held
        ld a,(ED_ROW)
        jr z,pkd_pg
        inc a
        ld hl,SNG_PATLEN
        cp (hl)
        jr c,pk_setrow
        xor a
        jr pk_setrow
pkd_pg: add a,16
pk_clamprow:
        ld hl,SNG_PATLEN
        cp (hl)
        jr c,pk_setrow
        ld a,(hl)
        dec a
pk_setrow:
        ld (ED_ROW),a
        ret

pk_tab: ld a,(ED_CH)
        inc a
        cp 3
        jr c,pkt_1
        xor a
pkt_1:  ld (ED_CH),a
        xor a
        ld (ED_COL),a
        ret

pk_home:                        ; HOME first row, SHIFT+HOME last row
        call shift_held
        ld a,0
        jr nz,pk_setrow
        ld a,(SNG_PATLEN)
        dec a
        jr pk_setrow

; ---- playback ----
pk_space:
        ld a,(PL_PLAYING)
        or a
        jp nz,play_stop
        ld a,(ED_ORD)
        ld b,a
        ld a,(ED_ROW)
        ld c,a
        ld a,2
        jp play_start

pk_return:                      ; SHIFT+RETURN: from the cursor row
        ld a,(PL_PLAYING)
        or a
        jp nz,play_stop
        ld c,0
        call shift_held
        jr nz,pkr_go
        ld a,(ED_ROW)
        ld c,a
pkr_go: ld a,(ED_ORD)
        ld b,a
        ld a,1
        jp play_start

; ---- editing ----
pk_del: call snapshot
        call cur_cell
        ld a,(ED_COL)
        or a
        jr nz,pkd_1
        ld (hl),a               ; note column: note, instrument, volume
        inc hl
        ld (hl),a
        inc hl
        res 7,(hl)
        jp advance
pkd_1:  inc hl
        cp 1
        jr nz,pkd_2
        ld a,(hl)
        and 0Fh
        ld (hl),a
        jp advance
pkd_2:  inc hl
        cp 2
        jr nz,pkd_3
        res 7,(hl)
        jp advance
pkd_3:  ld a,(hl)               ; effect
        and 80h
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,3
        ld (ED_COL),a
        jp advance

; delete the row under the cursor in this track, pull the rest up
pk_bs:  call snapshot
        ld a,(ED_ROW)
        call cell_at
        ld a,(ED_ROW)
        ld b,a
        ld a,(SNG_PATLEN)
        sub b
        dec a
        jr z,pkb_last
        ld b,a
pkb_lp: push bc
        ld d,h
        ld e,l
        ld bc,ROWSZ
        add hl,bc
        push hl
        ld bc,4
        ldir
        pop hl
        pop bc
        djnz pkb_lp
pkb_last:
        jp clear4

; insert an empty row at the cursor in this track
pk_ins: call snapshot
        ld a,(SNG_PATLEN)
        dec a
        call cell_at
        ld a,(ED_ROW)
        ld b,a
        ld a,(SNG_PATLEN)
        sub b
        dec a
        jr z,clear4
        ld b,a
pki_lp: push bc
        ld d,h
        ld e,l
        ld bc,-ROWSZ
        add hl,bc
        push hl
        ld bc,4
        ldir
        pop hl
        pop bc
        djnz pki_lp
clear4: xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

octave_dn:
        ld a,(ED_OCT)
        dec a
        ret z
        ld (ED_OCT),a
        ret
octave_up:
        ld a,(ED_OCT)
        cp 8
        ret nc
        inc a
        ld (ED_OCT),a
        ret

ins_dn: ld a,(ED_INS)
        dec a
        ret z
        ld (ED_INS),a
        ret
ins_up: ld a,(ED_INS)
        cp 15
        ret nc
        inc a
        ld (ED_INS),a
        ret

pk_patdn:
        call set_modified
        call cur_ord_ptr
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
pk_patup:
        call set_modified
        call cur_ord_ptr
        ld a,(NUMPAT)
        dec a
        cp (hl)
        ret z
        ret c
        inc (hl)
        ret

cur_ord_ptr:
        ld a,(ED_ORD)
        ld e,a
        ld d,0
        ld hl,ORDERS
        add hl,de
        ret

pk_stepdn:
        ld a,(ED_STEP)
        or a
        ret z
        dec a
        ld (ED_STEP),a
        ret
pk_stepup:
        ld a,(ED_STEP)
        cp 16
        ret nc
        inc a
        ld (ED_STEP),a
        ret

; ---- clipboard / track tools ----
pk_copytrk:
        xor a
        call cell_at
        ld de,TRKBUF
        ld b,PATROWS
pct_lp: push bc
        ld bc,4
        ldir
        ld bc,ROWSZ-4
        add hl,bc
        pop bc
        djnz pct_lp
        ld hl,msg_trkcopy
        jp set_msg

pk_pastetrk:
        call snapshot
        xor a
        call cell_at
        ex de,hl
        ld hl,TRKBUF
        ld b,PATROWS
ppt_lp: push bc
        ld bc,4
        ldir
        ex de,hl
        ld bc,ROWSZ-4
        add hl,bc
        ex de,hl
        pop bc
        djnz ppt_lp
        ld hl,msg_paste
        jp set_msg

pk_copypat:
        call cur_pat_addr
        ld de,PATBUF
        ld bc,PATSIZE
        ldir
        ld hl,msg_patcopy
        jp set_msg

pk_pastepat:
        call snapshot
        call cur_pat_addr
        ex de,hl
        ld hl,PATBUF
        ld bc,PATSIZE
        ldir
        ld hl,msg_paste
        jp set_msg

pk_cleartrk:
        ld hl,msg_clrtrk
        call confirm
        ret nz
        call snapshot
        xor a
        call cell_at
        ld b,PATROWS
pclr_lp:
        push hl
        call clear4
        pop hl
        ld de,ROWSZ
        add hl,de
        djnz pclr_lp
        ret

pk_trup:
        ld c,1
        jr tr_do
pk_trdn:
        ld c,0FFh
tr_do:  push bc
        call snapshot
        pop bc
        xor a
        call cell_at
        ld b,PATROWS
        ld de,ROWSZ
tr_lp:  ld a,(hl)
        or a
        jr z,tr_n
        cp NOTE_OFF
        jr nc,tr_n
        add a,c
        jr z,tr_n
        cp NOTE_OFF
        jr nc,tr_n
        ld (hl),a
tr_n:   add hl,de
        djnz tr_lp
        ret

; ---- undo: the pattern as it was before the last change ----
snapshot:
        call set_modified
        call cur_patnum
        ld (UNDOPAT),a
        call cur_pat_addr
        ld de,UNDOBUF
        ld bc,PATSIZE
        ldir
        ret

pk_undo:                        ; swap pattern and snapshot (undo/redo)
        ld a,(UNDOPAT)
        cp 0FFh
        ld hl,msg_noundo
        jp z,set_msg
        call get_pat_addr
        ld de,UNDOBUF
        ld bc,PATSIZE
pu_lp:  ld a,(de)
        push af
        ld a,(hl)
        ld (de),a
        pop af
        ld (hl),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,pu_lp
        ld hl,msg_undo
        jp set_msg

pk_jam: ld hl,ED_JAM
        ld a,(hl)
        xor 1
        ld (hl),a
        ld hl,msg_recmode
        jp z,set_msg
        ld hl,msg_jammode
        jp set_msg

; ---- new song positions ----
pk_newpos:                      ; CTRL+N: empty pattern after this position
        call find_free
        jr nc,new_position
np_none:
        ld hl,msg_nofree
        jp set_msg
pk_clonepos:                    ; CTRL+B: copy of this pattern after it
        call find_free
        jr c,np_none
        push af
        call get_pat_addr
        push hl
        call cur_pat_addr
        pop de
        ld bc,PATSIZE
        ldir
        pop af
new_position:                   ; A = pattern
        call set_modified
        push af
        ld a,(SNG_LEN)
        cp ORDMAX
        jr nc,np_full
        ld a,(ED_ORD)
        inc a
        ld (ED_ORD),a
        ld b,a
        ld a,ORDMAX-1
        sub b
        jr z,np_set
        ld c,a
        ld b,0
        ld hl,ORDERS+ORDMAX-2
        ld de,ORDERS+ORDMAX-1
        lddr
np_set: call cur_ord_ptr
        pop af
        ld (hl),a
        ld hl,SNG_LEN
        inc (hl)
        xor a
        ld (ED_ROW),a
        ld hl,msg_newpos
        jp set_msg
np_full:
        pop af
        ld hl,msg_full
        jp set_msg

; A = a pattern not used in the song and empty; carry if there is none
find_free:
        ld c,0
ff_lp:  ld a,(NUMPAT)
        cp c
        jr nz,ff_chk
        scf
        ret
ff_chk: ld hl,ORDERS
        ld a,(SNG_LEN)
        ld b,a
ff_o:   ld a,(hl)
        cp c
        jr z,ff_next
        inc hl
        djnz ff_o
        ld a,c
        push bc
        call pat_empty
        pop bc
        jr nz,ff_next
        ld a,c
        or a
        ret
ff_next:
        inc c
        jr ff_lp

; A = pattern -> Z if it holds nothing
pat_empty:
        call get_pat_addr
        ld bc,PATSIZE
pe_lp:  ld a,(hl)
        or a
        ret nz
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,pe_lp
        ret

set_modified:
        push af
        ld a,1
        ld (SONGMOD),a
        pop af
        ret

; keys that only move around or play leave the song unchanged
; (A = key; also preserved)
mark_if_edit:
        cp 13
        ret z
        cp 32
        jr z,mie_sp
        cp 28
        jr c,set_modified
        cp 32
        ret c
        jr set_modified
mie_sp: push af                 ; SPACE types into names only
        ld a,(SCREEN)
        cp SCR_SONG
        ld a,(SG_FIELD)
        jr z,mie_nm
        ld a,(IN_ROW)
mie_nm: or a
        pop af
        ret nz
        jr set_modified

; ---- hint line: what the field under the cursor does ----
pat_hint:
        ld bc,22*256+0
        call at
        ld a,(ED_COL)
        or a
        jr nz,ph_1
        ld hl,hint_note
        ld a,(ED_JAM)
        or a
        jp z,pstr
        ld hl,hint_jam
        jp pstr
ph_1:   ld hl,hint_ins
        dec a
        jp z,pstr
        ld hl,hint_vol
        dec a
        jp z,pstr
        call cur_cell
        inc hl
        inc hl
        ld a,(hl)
        ld hl,hint_fx
        bit 6,a
        jp z,pstr
        and 0Fh
        ld hl,fx_desc
        call skip_str
        jp pstr

; HL = list of zero-terminated strings, A = index -> HL = that string
skip_str:
        or a
        ret z
        ld b,a
ss_lp:  ld a,(hl)
        inc hl
        or a
        jr nz,ss_lp
        djnz ss_lp
        ret

hint_note:
        db "Z-M Q-P notes 1=off [ ]=octave ,.=instr",0
hint_jam:
        db "JAM: keys only play (CTRL+J = record)",0
hint_ins:
        db "0-F instrument for this note (0 = none)",0
hint_vol:
        db "0-F volume for this note",0
hint_fx:
        db "Effect: 0-F + 2 digits (F5 = list)",0
fx_desc:
        db "0xy ARPEGGIO note, +x, +y semitones",0
        db "1xx SLIDE UP by xx every tick",0
        db "2xx SLIDE DOWN by xx every tick",0
        db "3xx PORTAMENTO to this note, speed xx",0
        db "4xy VIBRATO speed x, depth y",0
        db "5xx ENVELOPE PERIOD high byte",0
        db "6xx ENVELOPE PERIOD low byte",0
        db "7xy ENVELOPE SHAPE y (restarts it)",0
        db "8xx NOISE PERIOD (20+ = instrument)",0
        db "9xx DELAY the note by xx ticks",0
        db "Axy VOLUME SLIDE up x or down y",0
        db "Bxx JUMP to song position xx",0
        db "Cxx CUT the note after xx ticks",0
        db "Dxx NEXT POSITION, start at row xx",0
        db "Exx DETUNE (signed period offset)",0
        db "Fxx SPEED: xx ticks per row",0

msg_undo:
        db "Undone (CTRL+Z again = redo)",0
msg_noundo:
        db "Nothing to undo",0
msg_jammode:
        db "JAM mode: notes are played, not written",0
msg_recmode:
        db "REC mode: notes are written",0
msg_newpos:
        db "New position added",0
msg_nofree:
        db "No free pattern left",0
msg_full:
        db "Song is full (128 positions)",0
msg_trkcopy:
        db "Track copied (CTRL+V pastes)",0
msg_patcopy:
        db "Pattern copied (CTRL+P pastes)",0
msg_paste:
        db "Pasted",0
msg_clrtrk:
        db "Clear this track? (Y/N)",0
