; ===========================================================================
; Text screen helpers. Everything is drawn into SCRBUF and copied to VRAM
; with the BIOS (LDIRVM), which is safe on every VDP.
; ===========================================================================

cls:    ld hl,SCRBUF
        ld de,SCRBUF+1
        ld bc,959
        ld (hl),' '
        ldir
        xor a
        ld (INVM),a
        ret

flush:  ld hl,SCRBUF
        ld de,(TXTNAM)
        ld bc,960
        jp LDIRVM

; B = row, C = column -> PCUR (preserves BC)
at:     push de
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        ld de,SCRBUF
        add hl,de
        ld (PCUR),hl
        pop de
        ret

at_pstr:
        push hl
        call at
        pop hl
pstr:   ld a,(hl)
        inc hl
        or a
        ret z
        call pch
        jr pstr

; print character A (preserves all but AF)
pch:    push hl
        ld hl,INVM
        or (hl)
        ld hl,(PCUR)
        ld (hl),a
        inc hl
        ld (PCUR),hl
        pop hl
        ret

pspc:   ld a,' '
        jr pch

phex2:  push af
        rrca
        rrca
        rrca
        rrca
        call phex1
        pop af
phex1:  and 0Fh
        add a,'0'
        cp '9'+1
        jr c,pch
        add a,7
        jr pch

; print signed byte A as +XX / -XX
psigned:
        bit 7,a
        jr nz,ps_neg
        push af
        ld a,'+'
        call pch
        pop af
        jr phex2
ps_neg: neg
        push af
        ld a,'-'
        call pch
        pop af
        jr phex2

; print B characters from HL (zero bytes shown as spaces)
pfix:   ld a,(hl)
        inc hl
        or a
        jr nz,pf_c
        ld a,' '
pf_c:   call pch
        djnz pfix
        ret

; A = char, B = count
prep:   call pch
        djnz prep
        ret

; invert C characters at row B, column E (toggles bit 7)
hilite: push bc
        ld c,e
        call at
        pop bc
        ld b,c
hl_lp:  ld a,(hl)
        xor 80h
        ld (hl),a
        inc hl
        djnz hl_lp
        ret

; show the screen header line (inverted)
draw_title:
        ld a,80h
        ld (INVM),a
        PRINTAT 0,0," MSXTRACK F1 PAT F2 SONG F3 INS F4 FILE "
        xor a
        ld (INVM),a
        ld a,(SCREEN)           ; current tab shown un-inverted
        cp SCR_HELP
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,tab_pos
        add hl,de
        ld e,(hl)
        inc hl
        ld c,(hl)
        ld b,0
        jr hilite
tab_pos:
        db 10,6,17,7,25,6,32,7

; status line (row 23): message or play state
draw_footer:
        ld hl,(MSGPTR)
        ld a,h
        or l
        jr z,df_state
        ld bc,23*256+0
        jp at_pstr
df_state:
        ld bc,23*256+0
        call at
        ld a,(PL_PLAYING)
        or a
        jr nz,df_play
        PRINT "STOP "
        jr df_more
df_play:
        cp 1
        jr nz,df_ppat
        PRINT "SONG "
        jr df_more
df_ppat:
        PRINT "LOOP "
df_more:
        PRINT "OCT"
        ld a,(ED_OCT)
        call phex1
        PRINT " INS"
        ld a,(ED_INS)
        call phex1
        PRINT " MUTE:"
        ld ix,CHAN0
        ld a,'A'
        call df_mute
        ld ix,CHAN1
        ld a,'B'
        call df_mute
        ld ix,CHAN2
        ld a,'C'
        call df_mute
        ld hl,txt_rec
        ld a,(ED_JAM)
        or a
        jr z,df_rj
        ld hl,txt_jam
df_rj:  call pstr
        PRINT " F5 HELP"
        ret
txt_rec:
        db " REC",0
txt_jam:
        db " JAM",0
df_mute:
        ld c,a
        ld a,(ix+C_MUTE)
        or a
        ld a,c
        jr nz,dfm_p
        ld a,'-'
dfm_p:  jp pch

; show a message in the status line until the next key press
; HL = zero terminated string
set_msg:
        ld (MSGPTR),hl
        ld a,1
        ld (DIRTY),a
        ret

; redraw now (used by modal prompts)
refresh:
        call draw_screen
        jp flush

; wait for a key (keeps the screen and playback alive) -> A, uppercased
wait_key:
        ei
        halt
        call CHSNS
        jr z,wait_key
        call CHGET
upcase: cp 'a'
        ret c
        cp 'z'+1
        ret nc
        sub 32
        ret

; A = ASCII hex digit -> A = 0..15, carry set if not hex
hexval: sub '0'
        ret c
        cp 10
        ccf
        ret nc
        sub 'A'-'0'
        ret c
        cp 6
        ccf
        ret c
        add a,10
        ret

; Y/N question in the status line. HL = text. Z = yes
confirm:
        call set_msg
        call refresh
        call wait_key
        push af
        ld hl,0
        ld (MSGPTR),hl
        pop af
        cp 'Y'
        ret
