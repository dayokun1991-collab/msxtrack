; ---------------------------------------------------------------------------
; RAM used by the replayer (MTK_RAM must be defined before including)
; ---------------------------------------------------------------------------
mtk_CHAN0       equ MTK_RAM
mtk_CHAN1       equ MTK_RAM+32
mtk_CHAN2       equ MTK_RAM+64
mtk_SFXCH       equ MTK_RAM+96
mtk_PSGREG      equ MTK_RAM+128         ; 14 bytes
mtk_PL_PLAYING  equ MTK_RAM+142
mtk_PL_TICK     equ MTK_RAM+143
mtk_PL_SPEED    equ MTK_RAM+144
mtk_PL_ORDPOS   equ MTK_RAM+145
mtk_PL_ROW      equ MTK_RAM+146
mtk_PL_PATPTR   equ MTK_RAM+147         ; 2 bytes
mtk_PL_JUMP     equ MTK_RAM+149
mtk_PL_BREAK    equ MTK_RAM+150
mtk_PL_FIRST    equ MTK_RAM+151
mtk_PL_ENVTRIG  equ MTK_RAM+152
mtk_PL_ENVMAN   equ MTK_RAM+153
mtk_PL_ROWFLAG  equ MTK_RAM+154
mtk_PL_DISPROW  equ MTK_RAM+155
mtk_PL_DISPORD  equ MTK_RAM+156
mtk_PU_BIT      equ MTK_RAM+157
mtk_SNG_SPEED   equ MTK_RAM+158         ; these four stay in file order
mtk_SNG_PATLEN  equ MTK_RAM+159
mtk_SNG_LEN     equ MTK_RAM+160
mtk_SNG_LOOP    equ MTK_RAM+161
mtk_PL_ORDERS   equ MTK_RAM+162         ; 2 bytes
mtk_PL_INSTR    equ MTK_RAM+164         ; 2 bytes
mtk_PATBASE     equ MTK_RAM+166         ; 2 bytes
mtk_NUMPAT      equ MTK_RAM+168
mtk_SFX_ON      equ MTK_RAM+169
mtk_SFX_CHAN    equ MTK_RAM+170
mtk_SFX_TIME    equ MTK_RAM+171         ; 2 bytes, 0 = until stopped
mtk_SFX_INSTR   equ MTK_RAM+173         ; 2 bytes
MTK_RAMSIZE     equ 175

mtk_NOTE_OFF    equ 97
mtk_PSG_ADR     equ 0A0h
mtk_PSG_WR      equ 0A1h

; ---------------------------------------------------------------------------
; Public API
; ---------------------------------------------------------------------------

; mtk_init - prepare a song. HL = start of the .MTK file in memory (ROM or
; RAM). Returns Z if it is a valid song, NZ if not. Music is stopped.
; Sound effects use this song's instruments until mtk_sfx_bank is called.
mtk_init:
        push hl
        ld de,mtk_magic
        ld b,6
mtk_in_cmp:
        ld a,(de)
        cp (hl)
        jr nz,mtk_in_bad
        inc hl
        inc de
        djnz mtk_in_cmp
        ld a,(hl)               ; format version
        cp 1
        jr nz,mtk_in_bad
        inc hl
        ld a,(hl)               ; pattern count
        or a
        jr z,mtk_in_bad
        cp 65
        jr nc,mtk_in_bad
        di
        push hl                 ; clear all replayer RAM
        ld hl,MTK_RAM
        ld b,MTK_RAMSIZE
mtk_in_clr:
        ld (hl),0
        inc hl
        djnz mtk_in_clr
        pop hl
        ld (mtk_NUMPAT),a
        inc hl
        ld de,mtk_SNG_SPEED     ; speed, rows, length, restart
        ld bc,4
        ldir
        pop hl
        ld de,8+32
        add hl,de
        ld (mtk_PL_ORDERS),hl
        ld de,128
        add hl,de
        ld (mtk_PL_INSTR),hl
        ld (mtk_SFX_INSTR),hl
        ld de,16*96
        add hl,de
        ld (mtk_PATBASE),hl
        call mtk_reset_chans
        ei
        xor a
        ret
mtk_in_bad:
        pop hl
        or 1
        ret

mtk_magic:
        db "MSXTRK"

; mtk_start - play the song from order position A (0 = beginning).
; It loops to the song's restart position at the end.
mtk_start:
        ld hl,mtk_SNG_LEN
        cp (hl)
        jr c,mtk_st_ok
        xor a
mtk_st_ok:
        ld b,a
        ld c,0
        ld a,1
        jp mtk_play_start

; mtk_stop - stop the music (sound effects keep playing).
mtk_stop:
        jp mtk_play_stop

; mtk_frame - call once per video frame, from the interrupt (H.TIMI).
; Advances music and sound effects and writes the PSG.
mtk_frame:
        call mtk_player_tick
        ld a,(mtk_SFX_ON)
        or a
        jp z,mtk_psg_update
        ld ix,mtk_SFXCH
        call mtk_chan_tick
        ld a,(mtk_SFX_CHAN)     ; the effect replaces the music on its channel
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,mtk_CHAN0+mtk_C_OPL
        add hl,de
        ex de,hl
        ld hl,mtk_SFXCH+mtk_C_OPL
        ld bc,5                 ; period, volume, mixer, noise
        ldir
        ld hl,(mtk_SFX_TIME)
        ld a,h
        or l
        jp z,mtk_psg_update
        dec hl
        ld (mtk_SFX_TIME),hl
        ld a,h
        or l
        jp nz,mtk_psg_update
        ld (mtk_SFX_ON),a
        jp mtk_psg_update

; mtk_sfx - play instrument A (1-15) as a sound effect at note B (1-96,
; 49 = C-5) on channel C (0-2), over the music on that channel. A new
; effect replaces the previous one. A non-looping instrument ends after its
; last step; a looping one plays until mtk_sfx_stop.
mtk_sfx:
        di
        push bc
        ld l,a                  ; HL = instrument
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,(mtk_SFX_INSTR)
        add hl,de
        push hl
        ld hl,mtk_SFXCH         ; fresh channel state
        ld b,32
mtk_sx_clr:
        ld (hl),0
        inc hl
        djnz mtk_sx_clr
        ld ix,mtk_SFXCH
        ld (ix+mtk_C_VOL),15
        ld (ix+mtk_C_FX),0FFh
        ld (ix+mtk_C_CUT),0FFh
        ld (ix+mtk_C_NOVR),0FFh
        pop hl
        ld (ix+mtk_C_INSL),l
        ld (ix+mtk_C_INSH),h
        ld e,(hl)               ; length in frames = steps * speed
        inc hl
        ld a,(hl)               ; loop step
        inc hl
        cp e
        ld bc,0
        jr c,mtk_sx_time        ; loops: no end
        ld a,(hl)
        or a
        jr nz,mtk_sx_spd
        inc a
mtk_sx_spd:
        ld b,a
        xor a
        ld d,a
mtk_sx_mul:
        add a,e
        jr nc,mtk_sx_nc
        inc d
mtk_sx_nc:
        djnz mtk_sx_mul
        ld c,a
        ld b,d
mtk_sx_time:
        ld (mtk_SFX_TIME),bc
        pop bc
        ld a,c
        ld (mtk_SFX_CHAN),a
        ld d,b
        call mtk_trigger_note
        ld a,1
        ld (mtk_SFX_ON),a
        ei
        ret

; mtk_sfx_stop - end the current sound effect.
mtk_sfx_stop:
        xor a
        ld (mtk_SFX_ON),a
        ret

; mtk_sfx_bank - take sound effect instruments from another .MTK file
; (HL = start of that file), e.g. a song that only holds effects.
mtk_sfx_bank:
        ld de,8+32+128
        add hl,de
        ld (mtk_SFX_INSTR),hl
        ret

; ---------------------------------------------------------------------------
; Internals
; ---------------------------------------------------------------------------

; A = pattern -> HL = address (preserves BC)
mtk_get_pat_addr:
        ld hl,mtk_NUMPAT
        cp (hl)
        jr c,mtk_gp_ok
        xor a
mtk_gp_ok:
        ld e,a                  ; DE = A * 768
        add a,a
        add a,e
        ld d,a
        ld e,0
        ld hl,(mtk_PATBASE)
        add hl,de
        ret
