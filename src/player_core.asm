; ===========================================================================
; MSXTRACK replay engine core
; Shared by the tracker (player.asm) and the standalone game replayer
; (replayer/mtkplay.asm is generated from this file by tools/gen_replayer.py).
; Needs from the includer: get_pat_addr, the RAM variables, PL_ORDERS and
; PL_INSTR (pointers to the order list and instruments), the SNG_* settings
; and the tables notetab, voltab and sinetab.
; ===========================================================================

; ---- channel structure (IX relative) ----
C_NOTE      equ 0           ; base note 1..96
C_INS       equ 1           ; instrument number
C_INSL      equ 2           ; instrument pointer
C_INSH      equ 3
C_STEP      equ 4           ; instrument sequence step
C_STICK     equ 5           ; tick counter within step
C_ACTIVE    equ 6
C_VOL       equ 7           ; channel volume 0..15
C_SWPL      equ 8           ; instrument pitch sweep accumulator
C_SWPH      equ 9
C_SLDL      equ 10          ; effect pitch slide accumulator
C_SLDH      equ 11
C_FX        equ 12          ; running effect (FF none)
C_FXP       equ 13
C_ARPC      equ 14
C_VIBP      equ 15
C_CUT       equ 16
C_DLY       equ 17
C_DNOTE     equ 18
C_DIV       equ 19
C_DFL       equ 20
C_DET       equ 21
C_NOVR      equ 22
C_MUTE      equ 23
C_OPL       equ 24          ; output: tone period
C_OPH       equ 25
C_OVOL      equ 26          ; output: volume (16 = hardware envelope)
C_OMIX      equ 27          ; output: bit0 tone, bit1 noise
C_ONOI      equ 28          ; output: noise period
C_OENV      equ 29
C_PSPD      equ 30          ; tone portamento speed
C_VIBPAR    equ 31          ; vibrato speed/depth
CHSIZE      equ 32

; ---- instrument structure ----
I_LEN       equ 0
I_LOOP      equ 1           ; FF = no loop (hold last step)
I_SPEED     equ 2
I_SHAPE     equ 3
I_EMODE     equ 4           ; 0 fixed period, 1-4 follow note
I_EPERL     equ 5
I_EPERH     equ 6
I_NAME      equ 8
I_STEPS     equ 16
STEPSZ      equ 5           ; vol, arp, sweep, noise, flags(T=1 N=2 E=4)

; One frame of the sequencer and instruments (no PSG output yet)
player_tick:
        ld a,(PL_PLAYING)
        or a
        jr z,pf_chans
        ld hl,PL_TICK
        dec (hl)
        jr nz,pf_chans
        call process_row
        ld a,(PL_SPEED)
        ld (PL_TICK),a
        ld a,1
        ld (PL_FIRST),a
pf_chans:
        ld ix,CHAN0
        call chan_tick
        ld ix,CHAN1
        call chan_tick
        ld ix,CHAN2
        call chan_tick
        xor a
        ld (PL_FIRST),a
        ret

; ---------------------------------------------------------------------------
; Read one row of the current pattern and move the song position on
; ---------------------------------------------------------------------------
process_row:
        ld a,(PL_ROW)
        ld (PL_DISPROW),a
        ld a,(PL_ORDPOS)
        ld (PL_DISPORD),a
        ld a,0FFh
        ld (PL_JUMP),a
        ld (PL_BREAK),a
        ld a,(PL_ROW)
        call row_offset
        ld de,(PL_PATPTR)
        add hl,de
        ld ix,CHAN0
        call process_cell
        ld ix,CHAN1
        call process_cell
        ld ix,CHAN2
        call process_cell
        ld a,1
        ld (PL_ROWFLAG),a
        ld a,(PL_JUMP)
        cp 0FFh
        jr nz,pr_jump
        ld a,(PL_BREAK)
        cp 0FFh
        jr nz,pr_break
        ld a,(PL_ROW)
        inc a
        ld hl,SNG_PATLEN
        cp (hl)
        jr nc,pr_endpat
        ld (PL_ROW),a
        ret
pr_endpat:
        xor a
pr_break:
        ld b,a
        ld a,(PL_PLAYING)
        cp 2
        jr z,pr_setrow
        ld a,(PL_ORDPOS)
        inc a
        jr pr_setord
pr_jump:
        ld c,a
        ld a,(PL_BREAK)
        cp 0FFh
        jr nz,pr_j1
        xor a
pr_j1:  ld b,a
        ld a,(PL_PLAYING)
        cp 2
        jr z,pr_setrow
        ld a,c
pr_setord:                      ; A = order position, B = row
        ld hl,SNG_LEN
        cp (hl)
        jr c,pr_ordok
        ld a,(SNG_LOOP)
        cp (hl)
        jr c,pr_ordok
        xor a
pr_ordok:
        ld (PL_ORDPOS),a
        call set_patptr
pr_setrow:
        ld a,b
        ld hl,SNG_PATLEN
        cp (hl)
        jr c,pr_rowok
        xor a
pr_rowok:
        ld (PL_ROW),a
        ret

; A = order position -> PL_PATPTR (preserves BC)
set_patptr:
        ld e,a
        ld d,0
        ld hl,(PL_ORDERS)
        add hl,de
        ld a,(hl)
        call get_pat_addr
        ld (PL_PATPTR),hl
        ret

; A = row -> HL = A*12
row_offset:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ret

; HL = cell, IX = channel. Returns HL += 4
process_cell:
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ld (ix+C_CUT),0FFh
        ld (ix+C_DLY),0
        bit 6,b
        jr z,pc_now
        ld a,b
        and 0Fh
        cp 9
        jr nz,pc_now
        ld a,c
        or a
        jr z,pc_now
        inc a                   ; counted down from this same frame on
        jr nz,pc_dly
        dec a
pc_dly: ld (ix+C_DLY),a         ; 9xx: note delay
        ld (ix+C_DNOTE),d
        ld (ix+C_DIV),e
        ld (ix+C_DFL),b
        pop hl
        ret
pc_now: call apply_cell
        pop hl
        ret

; D = note, E = instrument/volume, B = flags, C = fx parameter, IX = channel
apply_cell:
        ld a,e
        and 0F0h
        jr z,ac_noins
        rrca
        rrca
        rrca
        rrca
        call set_instr
ac_noins:
        bit 7,b
        jr z,ac_novol
        ld a,e
        and 0Fh
        ld (ix+C_VOL),a
ac_novol:
        ld a,d                  ; a new note ends the running effect
        or a
        jr z,ac_fx
        cp NOTE_OFF
        jr z,ac_fx
        ld (ix+C_FX),0FFh
ac_fx:  bit 6,b
        call nz,apply_fx
        ld a,d
        or a
        ret z
        cp NOTE_OFF
        jr nz,ac_note
        ld (ix+C_ACTIVE),0
        ret
ac_note:
        ld a,(ix+C_FX)
        cp 3
        jr nz,trigger_note
        ld a,(ix+C_ACTIVE)
        or a
        jr z,trigger_note
        push de                 ; tone portamento: keep pitch, slide to 0
        ld a,(ix+C_NOTE)
        call note_period
        ld e,(ix+C_SLDL)
        ld d,(ix+C_SLDH)
        add hl,de
        pop de
        ld (ix+C_NOTE),d
        push hl
        ld a,d
        call note_period
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (ix+C_SLDL),l
        ld (ix+C_SLDH),h
        ret

trigger_note:                   ; D = note
        ld (ix+C_NOTE),d
        ld (ix+C_ACTIVE),1
        xor a
        ld (ix+C_STEP),a
        ld (ix+C_STICK),a
        ld (ix+C_SWPL),a
        ld (ix+C_SWPH),a
        ld (ix+C_SLDL),a
        ld (ix+C_SLDH),a
        ld (ix+C_VIBP),a
        ld (ix+C_ARPC),a
        ld l,(ix+C_INSL)
        ld h,(ix+C_INSH)
        push hl
        ld de,I_STEPS+4
        add hl,de
        pop de
        bit 2,(hl)              ; step 0 uses the hardware envelope?
        ret z
        ld hl,I_SHAPE
        add hl,de
        ld a,(hl)
        and 0Fh
        ld (PSGREG+13),a
        ld a,1
        ld (PL_ENVTRIG),a
        ret

; A = note -> HL = tone period (destroys DE)
note_period:
        ld l,a
        ld h,0
        add hl,hl
        ld de,notetab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

; A = instrument 1..15 (preserves BC, DE)
set_instr:
        push de
        ld (ix+C_INS),a
        call ins_addr
        ld (ix+C_INSL),l
        ld (ix+C_INSH),h
        pop de
        ret

; A = instrument -> HL = address (destroys DE)
ins_addr:
        ld l,a
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
        ld de,(PL_INSTR)
        add hl,de
        ret

; ---- effects applied when a row is read (B = flags, C = param) ----
apply_fx:
        ld a,b
        and 0Fh
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,fx_table
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

fx_table:
        dw fx_arp,fx_cont,fx_cont,fx_porta,fx_vib,fx_envhi,fx_envlo,fx_envsh
        dw fx_noise,fx_none,fx_cont,fx_jump,fx_cut,fx_break,fx_detune,fx_speed

fx_arp: ld a,c
        or a
        jr nz,fxa_on
        ld (ix+C_FX),0FFh       ; 000 stops the running effect
        ret
fxa_on: ld (ix+C_FX),0
        ld (ix+C_FXP),c
        ret
fx_cont:                        ; 1xx, 2xx, Axy
        ld a,b
        and 0Fh
        ld (ix+C_FX),a
        ld (ix+C_FXP),c
        ret
fx_porta:
        ld (ix+C_FX),3
        ld a,c
        or a
        ret z
        ld (ix+C_PSPD),a
        ret
fx_vib: ld (ix+C_FX),4
        ld a,c
        or a
        ret z
        ld (ix+C_VIBPAR),a
        ret
fx_envhi:
        ld a,c
        ld (PSGREG+12),a
        jr fx_envset
fx_envlo:
        ld a,c
        ld (PSGREG+11),a
fx_envset:
        ld a,1
        ld (PL_ENVMAN),a
        ret
fx_envsh:
        ld a,c
        and 0Fh
        ld (PSGREG+13),a
        ld a,1
        ld (PL_ENVTRIG),a
        ret
fx_noise:
        ld a,c
        cp 20h
        jr c,fxn_ok
        ld a,0FFh
fxn_ok: ld (ix+C_NOVR),a
fx_none:
        ret
fx_jump:
        ld a,c
        ld (PL_JUMP),a
        ret
fx_cut: ld (ix+C_CUT),c
        ret
fx_break:
        ld a,c
        ld (PL_BREAK),a
        ret
fx_detune:
        ld (ix+C_DET),c
        ret
fx_speed:
        ld a,c
        or a
        ret z
        ld (PL_SPEED),a
        ret

; ---------------------------------------------------------------------------
; Per-frame channel update: instrument sequence + running effects -> outputs
; ---------------------------------------------------------------------------
chan_tick:
        ld a,(ix+C_DLY)
        or a
        jr z,ct_nodly
        dec a
        ld (ix+C_DLY),a
        jr nz,ct_nodly
        ld d,(ix+C_DNOTE)
        ld e,(ix+C_DIV)
        ld b,(ix+C_DFL)
        ld c,0
        call apply_cell
ct_nodly:
        ld a,(ix+C_CUT)
        cp 0FFh
        jr z,ct_nocut
        or a
        jr nz,ct_cutdec
        ld (ix+C_ACTIVE),0
        ld (ix+C_CUT),0FFh
        jr ct_nocut
ct_cutdec:
        dec (ix+C_CUT)
ct_nocut:
        ld (ix+C_OENV),0
        ld a,(ix+C_ACTIVE)
        or a
        jr nz,ct_active
        ld (ix+C_OVOL),0
        ld (ix+C_OMIX),0
        ret
ct_active:
        ld l,(ix+C_INSL)
        ld h,(ix+C_INSH)
        push hl
        pop iy                  ; IY = instrument
        ld a,(ix+C_STEP)
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,I_STEPS
        ld e,a
        ld d,0
        add hl,de               ; HL = current step
        ld a,(hl)               ; volume
        and 0Fh
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+C_VOL)
        push hl
        ld e,a
        ld d,0
        ld hl,voltab
        add hl,de
        ld a,(hl)
        pop hl
        ld (ix+C_OVOL),a
        inc hl
        ld b,(hl)               ; B = arpeggio (semitones, signed)
        inc hl
        ld e,(hl)               ; pitch sweep, added every tick
        ld a,e
        rla
        sbc a,a
        ld d,a
        push hl
        ld l,(ix+C_SWPL)
        ld h,(ix+C_SWPH)
        add hl,de
        call clamp_pitch
        ld (ix+C_SWPL),l
        ld (ix+C_SWPH),h
        pop hl
        inc hl
        ld a,(hl)               ; noise period
        and 1Fh
        ld c,a
        ld a,(ix+C_NOVR)
        cp 0FFh
        jr z,ct_noi
        ld c,a
ct_noi: ld (ix+C_ONOI),c
        inc hl
        ld a,(hl)               ; flags
        and 3
        ld (ix+C_OMIX),a
        bit 2,(hl)
        jr z,ct_noenv
        ld (ix+C_OVOL),16
        ld (ix+C_OENV),1
ct_noenv:
        ; ---- running effects ----
        ld a,(ix+C_FX)
        cp 0FFh
        jp z,ct_fxdone
        or a
        jr nz,ct_fx1
        ld c,(ix+C_ARPC)        ; 0xy arpeggio
        ld a,c
        inc a
        cp 3
        jr c,ct_arp1
        xor a
ct_arp1:
        ld (ix+C_ARPC),a
        ld a,c
        or a
        jp z,ct_fxdone
        ld a,(ix+C_FXP)
        dec c
        jr nz,ct_arpy
        rrca
        rrca
        rrca
        rrca
ct_arpy:
        and 0Fh
        add a,b
        ld b,a
        jp ct_fxdone
ct_fx1: ld c,a
        ld a,(PL_FIRST)
        or a
        jp nz,ct_fxdone
        ld a,c
        cp 1
        jr nz,ct_fx2
        ld e,(ix+C_FXP)         ; 1xx slide up
        ld d,0
        ld l,(ix+C_SLDL)
        ld h,(ix+C_SLDH)
        or a
        sbc hl,de
        jr ct_sldst
ct_fx2: cp 2
        jr nz,ct_fx3
        ld e,(ix+C_FXP)         ; 2xx slide down
        ld d,0
        ld l,(ix+C_SLDL)
        ld h,(ix+C_SLDH)
        add hl,de
ct_sldst:
        call clamp_pitch
ct_sldst2:
        ld (ix+C_SLDL),l
        ld (ix+C_SLDH),h
        jr ct_fxdone
ct_fx3: cp 3
        jr nz,ct_fx4
        ld l,(ix+C_SLDL)        ; 3xx tone portamento
        ld h,(ix+C_SLDH)
        ld e,(ix+C_PSPD)
        ld d,0
        bit 7,h
        jr nz,ct_pneg
        or a
        sbc hl,de
        jr nc,ct_sldst2
        ld hl,0
        jr ct_sldst2
ct_pneg:
        add hl,de
        jr nc,ct_sldst2
        ld hl,0
        jr ct_sldst2
ct_fx4: cp 4
        jr nz,ct_fxa
        ld a,(ix+C_VIBPAR)      ; 4xy vibrato
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        add a,(ix+C_VIBP)
        ld (ix+C_VIBP),a
        jr ct_fxdone
ct_fxa: cp 0Ah
        jr nz,ct_fxdone
        ld a,(ix+C_FXP)         ; Axy volume slide
        ld c,a
        and 0F0h
        jr z,ct_vdown
        rrca
        rrca
        rrca
        rrca
        add a,(ix+C_VOL)
        cp 16
        jr c,ct_vset
        ld a,15
        jr ct_vset
ct_vdown:
        ld a,(ix+C_VOL)
        sub c
        jr nc,ct_vset
        xor a
ct_vset:
        ld (ix+C_VOL),a
ct_fxdone:
        ; ---- pitch: note + arpeggio, clamped to 1..96 ----
        ld e,b
        ld a,b
        rla
        sbc a,a
        ld d,a
        ld l,(ix+C_NOTE)
        ld h,0
        add hl,de
        bit 7,h
        jr nz,ct_nlow
        ld a,h
        or a
        jr nz,ct_nhigh
        ld a,l
        or a
        jr z,ct_nlow
        cp 97
        jr c,ct_nok
ct_nhigh:
        ld a,96
        jr ct_nok
ct_nlow:
        ld a,1
ct_nok: call note_period
        ld e,(ix+C_SWPL)
        ld d,(ix+C_SWPH)
        add hl,de
        ld e,(ix+C_SLDL)
        ld d,(ix+C_SLDH)
        add hl,de
        ld a,(ix+C_DET)
        ld e,a
        rla
        sbc a,a
        ld d,a
        add hl,de
        ld a,(ix+C_FX)
        cp 4
        jr nz,ct_novib
        call vib_offset
        add hl,de
ct_novib:
        bit 7,h
        jr nz,ct_plow
        ld a,h
        cp 10h
        jr nc,ct_phigh
        or l
        jr nz,ct_pok
ct_plow:
        ld hl,1
        jr ct_pok
ct_phigh:
        ld hl,0FFFh
ct_pok: ld (ix+C_OPL),l
        ld (ix+C_OPH),h
        ; ---- hardware envelope period ----
        ld a,(ix+C_OENV)
        or a
        jr z,ct_adv
        ld a,(iy+I_EMODE)
        or a
        jr nz,ct_eauto
        ld a,(PL_ENVMAN)
        or a
        jr nz,ct_adv
        ld a,(iy+I_EPERL)
        ld (PSGREG+11),a
        ld a,(iy+I_EPERH)
        ld (PSGREG+12),a
        jr ct_adv
ct_eauto:
        and 7
        add a,2
        ld b,a
ct_esh: srl h
        rr l
        djnz ct_esh
        ld a,h
        or l
        jr nz,ct_eok
        inc l
ct_eok: ld (PSGREG+11),hl
ct_adv:
        ; ---- advance the instrument sequence ----
        ld a,(ix+C_STICK)
        inc a
        cp (iy+I_SPEED)
        jr c,ct_stick
        ld a,(ix+C_STEP)
        inc a
        cp (iy+I_LEN)
        jr c,ct_step
        ld a,(iy+I_LOOP)
        cp (iy+I_LEN)
        jr c,ct_step
        ld a,(iy+I_LEN)
        or a
        jr z,ct_step
        dec a
ct_step:
        ld (ix+C_STEP),a
        xor a
ct_stick:
        ld (ix+C_STICK),a
        ret

; clamp signed HL to -4095..4095
clamp_pitch:
        bit 7,h
        jr nz,cp_neg
        ld a,h
        cp 10h
        ret c
        ld hl,0FFFh
        ret
cp_neg: ld a,h
        cp 0F0h
        ret nc
        ld hl,0F001h
        ret

; vibrato offset for channel IX -> DE (destroys A, BC)
vib_offset:
        push hl
        ld a,(ix+C_VIBP)
        ld c,a
        and 1Fh
        ld e,a
        ld d,0
        ld hl,sinetab
        add hl,de
        ld e,(hl)
        ld hl,0
        ld a,(ix+C_VIBPAR)
        and 0Fh
        jr z,vo_done
        ld b,a
vo_mul: add hl,de
        djnz vo_mul
        add hl,hl
        add hl,hl
        ld l,h
        ld h,0
vo_done:
        ex de,hl
        bit 5,c
        jr z,vo_pos
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
vo_pos: pop hl
        ret

; ---------------------------------------------------------------------------
; Build the PSG register image from the three channels and write it out
; ---------------------------------------------------------------------------
psg_update:
        ld ix,CHAN0
        ld hl,PSGREG
        ld de,PSGREG+8
        ld c,0                  ; enable bits: tone 0-2, noise 3-5
        ld a,1
        ld (PU_BIT),a
        ld b,3
pu_loop:
        ld a,(ix+C_OPL)
        ld (hl),a
        inc hl
        ld a,(ix+C_OPH)
        ld (hl),a
        inc hl
        ld a,(ix+C_MUTE)
        or a
        jr z,pu_on
        xor a
        ld (de),a
        jr pu_next
pu_on:  ld a,(ix+C_OVOL)
        ld (de),a
        bit 0,(ix+C_OMIX)
        jr z,pu_nt
        ld a,(PU_BIT)
        or c
        ld c,a
pu_nt:  bit 1,(ix+C_OMIX)
        jr z,pu_next
        ld a,(PU_BIT)
        add a,a
        add a,a
        add a,a
        or c
        ld c,a
        ld a,(ix+C_ONOI)
        ld (PSGREG+6),a
pu_next:
        inc de
        ld a,(PU_BIT)
        add a,a
        ld (PU_BIT),a
        push de
        ld de,CHSIZE
        add ix,de
        pop de
        djnz pu_loop
        ld a,c
        cpl
        and 3Fh
        or 80h                  ; MSX rule: port A input, port B output
        ld (PSGREG+7),a
        ld hl,PSGREG
        xor a
pu_out: out (PSG_ADR),a
        ld c,a
        ld a,(hl)
        out (PSG_WR),a
        inc hl
        ld a,c
        inc a
        cp 13
        jr c,pu_out
        ld a,(PL_ENVTRIG)
        or a
        ret z
        xor a
        ld (PL_ENVTRIG),a
        ld a,13
        out (PSG_ADR),a
        ld a,(PSGREG+13)
        out (PSG_WR),a
        ret

; ---------------------------------------------------------------------------
; Calls used by the editor (main program, interrupts enabled)
; ---------------------------------------------------------------------------

; A = mode (1 song, 2 pattern loop), B = order position, C = row
play_start:
        di
        push af
        push bc
        call reset_chans
        ld a,(SNG_SPEED)
        ld (PL_SPEED),a
        ld a,1
        ld (PL_TICK),a
        pop bc
        ld a,b
        ld (PL_ORDPOS),a
        call set_patptr
        ld a,c
        ld (PL_ROW),a
        xor a
        ld (PL_ENVMAN),a
        ld (PL_ROWFLAG),a
        pop af
        ld (PL_PLAYING),a
        ei
        ret

play_stop:
        di
        xor a
        ld (PL_PLAYING),a
        call reset_chans
        ei
        ret

reset_chans:
        ld ix,CHAN0
        ld b,3
rc_loop:
        push bc
        ld c,(ix+C_MUTE)
        push ix
        pop hl
        ld b,CHSIZE
        xor a
rc_clr: ld (hl),a
        inc hl
        djnz rc_clr
        ld (ix+C_MUTE),c
        ld (ix+C_VOL),15
        ld (ix+C_FX),0FFh
        ld (ix+C_CUT),0FFh
        ld (ix+C_NOVR),0FFh
        ld (ix+C_OPL),1
        ld a,1
        call set_instr
        ld de,CHSIZE
        add ix,de
        pop bc
        djnz rc_loop
        ret

