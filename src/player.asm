; ===========================================================================
; Tracker side of the replay engine
; Runs once per video frame from the H.TIMI interrupt hook. All PSG writes
; happen here, inside the interrupt, so they never clash with the BIOS
; (which also touches the PSG for joystick/keyboard-LED access).
; ===========================================================================

        include "player_core.asm"

; ---------------------------------------------------------------------------
; Interrupt hook entry (reached via inter-slot call from H.TIMI)
; ---------------------------------------------------------------------------
isr:
        push af
        push ix
        push iy
        call player_frame
        pop iy
        pop ix
        pop af
        jp OLDTIMI

player_frame:
        call player_tick
        jp psg_update

; A = pattern number -> HL = address (preserves BC)
get_pat_addr:
        ld hl,NUMPAT
        cp (hl)
        jr c,gpa_ok
        xor a
gpa_ok: ld l,a
        ld h,0
        add hl,hl
        ld de,PATTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

; A = channel 0..2 -> IX
chan_ix:
        ld ix,CHAN0
        or a
        ret z
        ld de,CHSIZE
cix1:   add ix,de
        dec a
        jr nz,cix1
        ret

; Sound one cell on a channel (preview while editing)
; D note, E ins/vol, B flags, C param, A channel. Cut after JAM_CUT frames.
jam_cell:
        di
        call chan_ix
        ld (ix+C_FX),0FFh
        ld (ix+C_DLY),0
        ld a,(JAM_CUT)
        ld (ix+C_CUT),a
        bit 7,b
        jr nz,jc_vol
        ld (ix+C_VOL),15
jc_vol: ld a,b
        and 0Fh
        cp 9                    ; no delays when previewing
        jr nz,jc_go
        res 6,b
jc_go:  call apply_cell
        ei
        ret
