; ===========================================================================
; New song, default instruments and the demo tune
; ===========================================================================

new_song:
        ld hl,SONGDATA
        ld de,SONGDATA+1
        ld bc,SONGDATA_END-SONGDATA-1
        ld (hl),0
        ldir
        ld a,6
        ld (SNG_SPEED),a
        ld a,PATROWS
        ld (SNG_PATLEN),a
        ld a,1
        ld (SNG_LEN),a
        ld hl,txt_untitled
        ld de,SNG_NAME
        ld bc,16
        ldir
        ld hl,txt_untitled      ; default file name "SONG"
        ld de,FILENAME
        ld bc,8
        ldir
        xor a                   ; clear every pattern
ns_pat: ld hl,NUMPAT
        cp (hl)
        jr nc,ns_ins
        push af
        call get_pat_addr
        call clear_pat
        pop af
        inc a
        jr ns_pat
ns_ins: ld a,1                  ; every slot: plain square wave
ns_i1:  push af
        call ins_addr
        ld (hl),1               ; length
        inc hl
        ld (hl),0               ; loop
        inc hl
        ld (hl),1               ; speed
        ld de,I_STEPS-2
        add hl,de
        ld (hl),15
        ld de,4
        add hl,de
        ld (hl),1
        pop af
        inc a
        cp NINS
        jr c,ns_i1
        ld hl,def_instr         ; then the preset sounds
        ld a,1
ns_def: push af
        push hl
        call ins_addr
        ex de,hl                ; DE = instrument
        pop hl                  ; HL = preset
        push de
        ld bc,I_NAME
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,8
        ldir                    ; name
        pop de
        ld a,(hl)               ; step count
        ld bc,7
        ldir                    ; len, loop, speed, shape, mode, period
        push hl
        ld hl,I_STEPS-7
        add hl,de
        ex de,hl
        pop hl
        ld c,a
        add a,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        ldir                    ; steps
        pop af
        inc a
        cp DEF_INSCOUNT+1
        jr c,ns_def
        jp reset_editor

txt_untitled:
        db "SONG            "

load_demo:
        ld hl,demo_hdr
        ld de,SONGDATA
        ld bc,4+16
        ldir
        ld de,ORDERS
        ld bc,DEMO_ORDLEN
        ldir
ld_ev:  ld a,(hl)               ; pattern, row|channel<<6, note, instrument
        cp 0FFh
        jp z,reset_editor
        inc hl
        push hl
        call get_pat_addr
        ex (sp),hl
        ld a,(hl)
        inc hl
        push hl
        ld c,a
        and 3Fh
        call row_offset
        ld a,c
        rlca
        rlca
        and 3
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        pop de                  ; DE = event data
        pop bc                  ; BC = pattern
        add hl,bc
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        ex de,hl
        jr ld_ev

        include "song_data.inc"
