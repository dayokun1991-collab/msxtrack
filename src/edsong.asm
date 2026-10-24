; ===========================================================================
; Song settings and order list (F2)
; ===========================================================================

draw_song:
        call draw_title
        PRINTAT 1,0,"NAME    "
        ld hl,SNG_NAME
        ld b,16
        call pfix
        PRINTAT 2,0,"SPEED   "
        ld a,(SNG_SPEED)
        call phex2
        PRINT "  ticks/row"
        PRINTAT 3,0,"PATLEN  "
        ld a,(SNG_PATLEN)
        call phex2
        PRINT "  rows"
        PRINTAT 4,0,"LENGTH  "
        ld a,(SNG_LEN)
        call phex2
        PRINT "  positions"
        PRINTAT 5,0,"RESTART "
        ld a,(SNG_LOOP)
        call phex2
        PRINT "  loop to"
        PRINTAT 1,26,"PATTERNS"
        PRINTAT 2,26,"00-"
        ld a,(NUMPAT)
        dec a
        call phex2
        PRINT " fit"
        PRINTAT 6,0,"ORDER LIST    INS/DEL edit  RET=go"
        ; grid: 16 rows x 8 positions
        ld b,7
        ld c,0                  ; first position on the row
ds_row: push bc
        ld a,c
        ld c,0
        call at
        call phex2
        ld a,':'
        call pch
        pop bc
        push bc
        ld e,8
ds_col: call pspc
        call pspc
        ld a,(SNG_LEN)
        dec a
        cp c
        jr c,ds_none
        push de
        ld e,c
        ld d,0
        ld hl,ORDERS
        add hl,de
        ld a,(hl)
        pop de
        call phex2
        jr ds_next
ds_none:
        ld a,'.'
        call pch
        call pch
ds_next:
        inc c
        dec e
        jr nz,ds_col
        pop bc
        ld a,c
        add a,8
        ld c,a
        inc b
        ld a,b
        cp 23
        jr c,ds_row
        ; cursor
        ld a,(SG_FIELD)
        cp 5
        jr z,ds_curgrid
        ld b,a
        inc b
        ld e,8
        ld c,2
        or a
        jr nz,ds_hl
        ld a,(SG_NPOS)
        add a,e
        ld e,a
        ld c,1
ds_hl:  jp hilite
ds_curgrid:
        ld a,(SG_POS)
        ld c,a
        rrca
        rrca
        rrca
        and 1Fh
        add a,7
        ld b,a
        ld a,c
        and 7
        add a,a
        add a,a
        add a,5
        ld e,a
        ld c,2
        jp hilite

; ---------------------------------------------------------------------------
song_key:
        ld c,a
        ld a,(SG_FIELD)
        or a
        ld a,c
        jr nz,sk_tab
        cp 8
        jr z,sk_namebs
        cp 32
        jr c,sk_tab
        cp 127
        jr nc,sk_tab
        ld c,a                  ; type into the song name
        call sg_nameptr
        ld (hl),c
        jp sk_nameright
sk_namebs:
        ld a,(SG_NPOS)
        or a
        ret z
        dec a
        ld (SG_NPOS),a
        call sg_nameptr
        ld (hl),' '
        ret
sk_tab: ld hl,song_keytab
        call find_key
        jr nz,sk_other
        jp (hl)
sk_other:
        call hexval
        ret c
        push af
        call sg_field_ptr
        pop de                  ; D = digit
        ret z
        ld a,(hl)               ; shift the digit in; restart if too big
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        or d
        ld (hl),a
        ld a,c
        cp (hl)
        jr nc,sko_ok
        ld (hl),d
sko_ok: jp sg_clamp

song_keytab:
        db 30
        dw sk_up
        db 31
        dw sk_down
        db 29
        dw sk_left
        db 28
        dw sk_right
        db 32
        dw sk_play
        db 13
        dw sk_return
        db 18
        dw sk_ins
        db 127
        dw sk_del
        db '+'
        dw sk_inc
        db '='
        dw sk_inc
        db '-'
        dw sk_dec
        db 0

sg_nameptr:
        ld a,(SG_NPOS)
        ld e,a
        ld d,0
        ld hl,SNG_NAME
        add hl,de
        ret

; HL = value of the current field, BC = limits (B min, C max). Z if none.
sg_field_ptr:
        ld a,(SG_FIELD)
        or a
        ret z
        cp 1
        jr nz,sfp_2
        ld hl,SNG_SPEED
        ld bc,011Fh
        jr sfp_nz
sfp_2:  cp 2
        jr nz,sfp_3
        ld hl,SNG_PATLEN
        ld bc,0140h
        jr sfp_nz
sfp_3:  cp 3
        jr nz,sfp_4
        ld hl,SNG_LEN
        ld bc,0180h
        jr sfp_nz
sfp_4:  cp 4
        jr nz,sfp_5
        ld a,(SNG_LEN)
        dec a
        ld c,a
        ld b,0
        ld hl,SNG_LOOP
        jr sfp_nz
sfp_5:  ld a,(SG_POS)
        ld e,a
        ld d,0
        ld hl,ORDERS
        add hl,de
        ld a,(NUMPAT)
        dec a
        ld c,a
        ld b,0
sfp_nz: or 1
        ret

; keep the value at HL inside B..C, then fix dependent settings
sg_clamp:
        ld a,(hl)
        cp b
        jr nc,sgc_1
        ld (hl),b
sgc_1:  ld a,c
        cp (hl)
        jr nc,song_fix
        ld (hl),c
song_fix:
        ld a,(SNG_LEN)
        ld b,a
        ld a,(SNG_LOOP)
        cp b
        jr c,sf_1
        xor a
        ld (SNG_LOOP),a
sf_1:   ld a,(ED_ORD)
        cp b
        jr c,sf_2
        ld a,b
        dec a
        ld (ED_ORD),a
sf_2:   ld a,(SNG_PATLEN)
        ld b,a
        ld a,(ED_ROW)
        cp b
        ret c
        ld a,b
        dec a
        ld (ED_ROW),a
        ret

sk_inc: call sg_field_ptr
        ret z
        ld a,(hl)
        cp c
        ret nc
        inc (hl)
        jr song_fix
sk_dec: call sg_field_ptr
        ret z
        ld a,(hl)
        cp b
        ret z
        ret c
        dec (hl)
        jr song_fix

sk_up:  ld a,(SG_FIELD)
        cp 5
        jr z,sku_g
        or a
        ret z
        dec a
        ld (SG_FIELD),a
        ret
sku_g:  ld a,(SG_POS)
        sub 8
        jr c,sku_f
        ld (SG_POS),a
        ret
sku_f:  ld a,4
        ld (SG_FIELD),a
        ret

sk_down:
        ld a,(SG_FIELD)
        cp 5
        jr z,skd_g
        inc a
        ld (SG_FIELD),a
        ret
skd_g:  ld a,(SG_POS)
        add a,8
        cp ORDMAX
        ret nc
        ld (SG_POS),a
        ret

sk_left:
        ld a,(SG_FIELD)
        or a
        jr z,skl_n
        cp 5
        jr nz,sk_dec
        ld a,(SG_POS)
        or a
        ret z
        dec a
        ld (SG_POS),a
        ret
skl_n:  ld a,(SG_NPOS)
        or a
        ret z
        dec a
        ld (SG_NPOS),a
        ret

sk_right:
        ld a,(SG_FIELD)
        or a
        jr z,sk_nameright
        cp 5
        jr nz,sk_inc
        ld a,(SG_POS)
        cp ORDMAX-1
        ret nc
        inc a
        ld (SG_POS),a
        ret
sk_nameright:
        ld a,(SG_NPOS)
        cp 15
        ret nc
        inc a
        ld (SG_NPOS),a
        ret

sk_play:
        ld a,(PL_PLAYING)
        or a
        jp nz,play_stop
        ld b,0
        ld a,(SG_FIELD)
        cp 5
        jr nz,skp_1
        ld a,(SG_POS)
        ld hl,SNG_LEN
        cp (hl)
        jr nc,skp_1
        ld b,a
skp_1:  ld c,0
        ld a,1
        jp play_start

sk_return:
        ld a,(SG_FIELD)
        cp 5
        ret nz
        ld a,(SG_POS)
        ld hl,SNG_LEN
        cp (hl)
        ret nc
        ld (ED_ORD),a
        xor a
        ld (ED_ROW),a
        ld (SCREEN),a
        ret

; insert a position (copy of the current one) at the cursor
sk_ins: ld a,(SG_FIELD)
        cp 5
        ret nz
        ld a,(SNG_LEN)
        cp ORDMAX
        ret nc
        ld b,a
        ld a,(SG_POS)
        cp b
        ret nc
        ld c,a
        ld a,ORDMAX-1
        sub c
        ld c,a
        ld b,0
        ld hl,ORDERS+ORDMAX-2
        ld de,ORDERS+ORDMAX-1
        lddr
        ld hl,SNG_LEN
        inc (hl)
        ret

; delete the position under the cursor
sk_del: ld a,(SG_FIELD)
        cp 5
        ret nz
        ld a,(SNG_LEN)
        cp 2
        ret c
        ld b,a
        ld a,(SG_POS)
        cp b
        ret nc
        ld e,a
        ld d,0
        ld hl,ORDERS
        add hl,de
        ld d,h
        ld e,l
        inc hl
        ld c,a
        ld a,ORDMAX-1
        sub c
        jr z,skd_x
        ld c,a
        ld b,0
        ldir
skd_x:  ld hl,SNG_LEN
        dec (hl)
        jp song_fix
