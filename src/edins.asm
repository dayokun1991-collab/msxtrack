; ===========================================================================
; Instrument / sound effect editor (F3)
; ===========================================================================

K_NIB   equ 0                   ; single hex digit
K_BYTE  equ 1                   ; two hex digits, limited
K_SGN   equ 2                   ; signed byte
K_FLAG  equ 3                   ; one bit (mask in "max")
K_WORD  equ 4                   ; 16-bit
K_LOOP  equ 5                   ; 0..F, DEL = no loop

draw_ins:
        call draw_title
        ld bc,4*256+0           ; what the field under the cursor does
        call at
        ld a,(IN_ROW)
        ld b,a
        ld a,(IN_COL)
        dec b
        jp m,dih_go             ; name row: hint 0
        inc a
        dec b
        jp m,dih_go             ; LENGTH row: 1-3
        add a,3
        dec b
        jp m,dih_go             ; ENVELOPE row: 4-6
        add a,3                 ; steps: 7-13
dih_go: ld hl,ins_hints
        call skip_str
        call pstr
        PRINTAT 1,0,"INSTRUMENT "
        ld a,(ED_INS)
        call phex1
        PRINT "   NAME "
        call cur_ins
        push hl
        ld de,I_NAME
        add hl,de
        ld b,8
        call pfix
        PRINT "  OCT "
        ld a,(ED_OCT)
        call phex1
        PRINTAT 2,0,"LENGTH "
        pop iy
        ld a,(iy+I_LEN)
        call phex2
        PRINT "  LOOP "
        ld a,(iy+I_LOOP)
        cp 16
        jr c,di_loop
        PRINT "--"
        jr di_spd
di_loop:
        call phex2
di_spd: PRINT "  SPEED "
        ld a,(iy+I_SPEED)
        call phex2
        PRINTAT 3,0,"ENVELOPE SHAPE "
        ld a,(iy+I_SHAPE)
        call phex1
        PRINT "  MODE "
        ld a,(iy+I_EMODE)
        call phex1
        PRINT "  PERIOD "
        ld a,(iy+I_EPERH)
        call phex2
        ld a,(iy+I_EPERL)
        call phex2
        PRINTAT 5,0,"ST  V  ARP SWP NOI T N E  VOLUME"
        ; 16 step rows
        push iy
        pop hl
        ld de,I_STEPS
        add hl,de
        ld b,6
        ld c,0
di_row: push bc
        push hl
        ld a,c
        ld c,0
        call at
        call phex2
        pop hl
        pop bc
        push bc
        push hl
        ; marker: '>' playing step, 'L' loop start, '.' unused
        ld a,c
        cp (iy+I_LEN)
        ld a,'.'
        jr nc,di_mk
        ld a,(IN_TEST)
        or a
        jr z,di_nop
        ld a,(CHAN0+C_ACTIVE)
        or a
        jr z,di_nop
        ld a,(CHAN0+C_STEP)
        cp c
        ld a,'>'
        jr z,di_mk
di_nop: ld a,(iy+I_LOOP)
        cp c
        ld a,'L'
        jr z,di_mk
        ld a,' '
di_mk:  call pch
        pop hl
        push hl
        call pspc
        ld a,(hl)               ; volume
        call phex1
        call pspc
        call pspc
        inc hl
        ld a,(hl)               ; arpeggio
        call psigned
        call pspc
        inc hl
        ld a,(hl)               ; sweep
        call psigned
        call pspc
        inc hl
        ld a,(hl)               ; noise
        call phex2
        call pspc
        call pspc
        inc hl
        ld c,(hl)               ; flags
        ld b,3
        ld de,flagchars
di_fl:  ld a,'.'
        rr c
        jr nc,di_f0
        ld a,(de)
di_f0:  call pch
        call pspc
        inc de
        djnz di_fl
        pop hl
        pop bc
        push bc
        push hl
        ld a,c                  ; volume bar for used steps
        cp (iy+I_LEN)
        jr nc,di_nobar
        ld a,(hl)
        and 0Fh
        jr z,di_nobar
        ld b,a
        ld a,0A0h
        call prep
di_nobar:
        pop hl
        ld de,STEPSZ
        add hl,de
        pop bc
        inc c
        inc b
        ld a,b
        cp 22
        jp c,di_row
        PRINTAT 22,0,"SPACE=test  -=negate  , . =instrument"
        ; cursor
        call in_cursor
        jp hilite

ins_hints:
        db "Type a name (8 letters)",0
        db "Steps in the sequence (01-10)",0
        db "Step to loop back to (DEL = no loop)",0
        db "Frames per step (01-3F)",0
        db "Hardware envelope shape 0-F (8-F loop)",0
        db "0 = use PERIOD, 1-4 follow the note",0
        db "Hardware envelope period (4 digits)",0
        db "Volume 0-F",0
        db "Semitones added to the note (- = minus)",0
        db "Pitch sweep added every tick (- = up)",0
        db "Noise period 00-1F (needs N on)",0
        db "Tone on (1) / off (0)",0
        db "Noise on (1) / off (0)",0
        db "Hardware envelope on (1) / off (0)",0

flagchars:
        db "TNE"

; -> B row, E column, C width of the cursor field
in_cursor:
        ld a,(IN_ROW)
        or a
        jr nz,ic_1
        ld a,(IN_NPOS)
        add a,20
        ld e,a
        ld bc,0101h
        ret
ic_1:   ld hl,curpos_r1
        cp 1
        jr z,ic_t
        ld hl,curpos_r2
        cp 2
        jr z,ic_t
        add a,2                 ; step rows start at screen row 6
        ld hl,curpos_st
ic_t:   ld b,a
        inc b
        ld a,(IN_COL)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld c,(hl)
        ret

curpos_r1:
        db 7,2,16,2,26,2
curpos_r2:
        db 15,1,23,1,33,4
curpos_st:
        db 4,1,7,3,11,3,15,2,19,1,21,1,23,1

fld_r1: db I_LEN,K_BYTE,1,16
        db I_LOOP,K_LOOP,0,15
        db I_SPEED,K_BYTE,1,3Fh
fld_r2: db I_SHAPE,K_NIB,0,15
        db I_EMODE,K_NIB,0,4
        db I_EPERL,K_WORD,0,0
fld_st: db 0,K_NIB,0,15
        db 1,K_SGN,0,0
        db 2,K_SGN,0,0
        db 3,K_BYTE,0,1Fh
        db 4,K_FLAG,0,1
        db 4,K_FLAG,0,2
        db 4,K_FLAG,0,4

cur_ins:
        ld a,(ED_INS)
        jp ins_addr

; current field -> HL value address, D kind, B min, C max
in_field:
        call cur_ins
        ld a,(IN_ROW)
        ld de,fld_r1
        cp 1
        jr z,if_t
        ld de,fld_r2
        cp 2
        jr z,if_t
        sub 3                   ; step: HL += 16 + step*5
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,I_STEPS
        ld e,a
        ld d,0
        add hl,de
        ld de,fld_st
if_t:   ld a,(IN_COL)
        add a,a
        add a,a
        add a,e
        ld e,a
        jr nc,if_1
        inc d
if_1:   ld a,(de)
        add a,l
        ld l,a
        jr nc,if_2
        inc h
if_2:   inc de
        ld a,(de)
        ld b,a
        inc de
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        ld d,b
        ld b,c
        ld c,a
        ret

in_ncols:
        ld a,(IN_ROW)
        or a
        ld a,1
        ret z
        ld a,(IN_ROW)
        cp 3
        ld a,3
        ret c
        ld a,7
        ret

; ---------------------------------------------------------------------------
ins_key:
        call mark_if_edit
        ld c,a
        ld a,(IN_ROW)
        or a
        ld a,c
        jr nz,ik_tab
        cp 8
        jr z,ik_namebs
        cp 32
        jr c,ik_tab
        cp 127
        jr nc,ik_tab
        call in_nameptr         ; type into the name
        ld (hl),c
        jp ik_nameright
ik_namebs:
        ld a,(IN_NPOS)
        or a
        ret z
        dec a
        ld (IN_NPOS),a
        call in_nameptr
        ld (hl),' '
        ret
ik_tab: ld hl,ins_keytab
        call find_key
        jr nz,ik_other
        jp (hl)
ik_other:
        call hexval
        ret c
        push af
        call in_field
        pop af
        ld e,a                  ; E = digit
        ld a,d
        cp K_NIB
        jr z,ik_nib
        cp K_LOOP
        jr z,ik_nib
        cp K_FLAG
        jr z,ik_flag
        cp K_WORD
        jr z,ik_word
        ld a,(hl)               ; byte / signed: shift the digit in
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        or e
        ld (hl),a
        ld a,d
        cp K_SGN
        ret z
        ld a,c
        cp (hl)
        jr nc,ik_min
        ld (hl),e
        jr ik_clamp
ik_nib: ld (hl),e
ik_clamp:
        ld a,c
        cp (hl)
        jr nc,ik_min
        ld (hl),c
ik_min: ld a,(hl)
        cp b
        ret nc
        ld (hl),b
        ret
ik_flag:
        ld a,e
        or a
        jr z,ik_clrflag
        ld a,c
        or (hl)
        ld (hl),a
        ret
ik_clrflag:
        ld a,c
        cpl
        and (hl)
        ld (hl),a
        ret
ik_word:
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,4
ikw_l:  add hl,hl
        djnz ikw_l
        ld a,l
        or e
        ld l,a
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

ins_keytab:
        db 30
        dw ik_up
        db 31
        dw ik_down
        db 29
        dw ik_left
        db 28
        dw ik_right
        db 32
        dw ik_test
        db 13
        dw ik_retest
        db 127
        dw ik_del
        db '-'
        dw ik_minus
        db '+'
        dw ik_inc
        db '='
        dw ik_inc
        db '['
        dw octave_dn
        db ']'
        dw octave_up
        db ','
        dw ins_dn
        db '.'
        dw ins_up
        db 3
        dw ik_copy
        db 22
        dw ik_paste
        db 0

in_nameptr:
        call cur_ins
        ld de,I_NAME
        add hl,de
        ld a,(IN_NPOS)
        ld e,a
        add hl,de
        ret

ik_up:  ld a,(IN_ROW)
        or a
        ret z
        dec a
        jr ik_setrow
ik_down:
        ld a,(IN_ROW)
        cp 18
        ret nc
        inc a
ik_setrow:
        ld (IN_ROW),a
        call in_ncols
        ld b,a
        ld a,(IN_COL)
        cp b
        ret c
        ld a,b
        dec a
        ld (IN_COL),a
        ret

ik_left:
        call shift_held
        jp z,ins_dn
        ld a,(IN_ROW)
        or a
        jr z,ikl_n
        ld a,(IN_COL)
        or a
        ret z
        dec a
        ld (IN_COL),a
        ret
ikl_n:  ld a,(IN_NPOS)
        or a
        ret z
        dec a
        ld (IN_NPOS),a
        ret

ik_right:
        call shift_held
        jp z,ins_up
        ld a,(IN_ROW)
        or a
        jr z,ik_nameright
        call in_ncols
        ld b,a
        ld a,(IN_COL)
        inc a
        cp b
        ret nc
        ld (IN_COL),a
        ret
ik_nameright:
        ld a,(IN_NPOS)
        cp 7
        ret nc
        inc a
        ld (IN_NPOS),a
        ret

ik_del: ld a,(IN_ROW)
        or a
        ret z
        call in_field
        ld a,d
        cp K_LOOP
        jr nz,ikd_1
        ld (hl),0FFh
        ret
ikd_1:  cp K_FLAG
        jp z,ik_clrflag
        cp K_WORD
        jr nz,ikd_2
        ld (hl),0
        inc hl
ikd_2:  ld (hl),b
        ret

ik_minus:
        ld a,(IN_ROW)
        or a
        ret z
        call in_field
        ld a,d
        cp K_SGN
        jr nz,ik_dec
        xor a
        sub (hl)
        ld (hl),a
        ret
ik_dec: cp K_FLAG
        jp z,ik_clrflag
        cp K_WORD
        jr z,ikw_dec
        cp K_SGN
        jr z,ikdc_2
        cp K_LOOP
        jr nz,ikdc_1
        ld a,(hl)
        cp 16
        ret nc
ikdc_1: ld a,(hl)
        cp b
        ret z
        ret c
ikdc_2: dec (hl)
        ret
ikw_dec:
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec de
        jr ikw_st

ik_inc: ld a,(IN_ROW)
        or a
        ret z
        call in_field
        ld a,d
        cp K_FLAG
        jr nz,iki_1
        ld a,c
        or (hl)
        ld (hl),a
        ret
iki_1:  cp K_WORD
        jr z,ikw_inc
        cp K_SGN
        jr z,iki_2
        ld a,(hl)
        cp 0FFh                 ; "no loop" -> 0
        jr nz,iki_3
        ld (hl),0
        ret
iki_3:  cp c
        ret nc
iki_2:  inc (hl)
        ret
ikw_inc:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc de
ikw_st: ld (hl),d
        dec hl
        ld (hl),e
        ret

ik_test:
        ld a,(IN_TEST)
        or a
        jr z,ik_retest
        xor a
        ld (IN_TEST),a
        ld (CHAN0+C_ACTIVE),a
        ret
ik_retest:
        ld a,(PL_PLAYING)
        or a
        call nz,play_stop
        ld a,1
        ld (IN_TEST),a
        ld a,0FFh
        ld (JAM_CUT),a
        ld a,(ED_OCT)
        call oct_base
        ld d,a
        ld a,(ED_INS)
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld bc,0
        xor a
        call jam_cell
        ld a,30
        ld (JAM_CUT),a
        ret

ik_copy:
        call cur_ins
        ld de,INSBUF
        ld bc,INSSZ
        ldir
        ld hl,msg_inscopy
        jp set_msg
ik_paste:
        call cur_ins
        ex de,hl
        ld hl,INSBUF
        ld bc,INSSZ
        ldir
        ld hl,msg_paste
        jp set_msg

msg_inscopy:
        db "Instrument copied (CTRL+V pastes)",0
