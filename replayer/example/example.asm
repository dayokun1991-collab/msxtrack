; ===========================================================================
; MTKPLAY example: a 16KB cartridge that plays a song and fires sound effects
;   SPACE = music on/off   1-7 = sound effects   0 = stop the effect
; Build: pasmo --bin example.asm example.rom  (from this directory)
; ===========================================================================

CHSNS   equ 009Ch
CHGET   equ 009Fh
CHPUT   equ 00A2h
INITXT  equ 006Ch
LINL40  equ 0F3AEh
CLIKSW  equ 0F3DBh
SCNCNT  equ 0F3F6h
H_TIMI  equ 0FD9Fh

MTK_RAM equ 0E000h              ; 175 bytes for the replayer

        org 4000h
        db "AB"
        dw start
        dw 0,0,0
        ds 6,0

start:  xor a
        ld (CLIKSW),a
        inc a
        ld (SCNCNT),a
        ld a,40
        ld (LINL40),a
        call INITXT
        ld hl,text
        call print
        ld hl,song
        call mtk_init
        jr nz,bad_song
        xor a
        call mtk_start
        ; our ROM stays in page 1, so the hook can jump straight to us
        di
        ld a,0C3h
        ld (H_TIMI),a
        ld hl,hook
        ld (H_TIMI+1),hl
        ei

mainloop:
        halt
        call CHSNS
        jr z,mainloop
        call CHGET
        cp ' '
        jr z,toggle
        cp '0'
        jr z,sfx_off
        sub '1'
        jr c,mainloop
        cp 7
        jr nc,mainloop
        add a,a                 ; table: instrument, note
        ld e,a
        ld d,0
        ld hl,sfx_table
        add hl,de
        ld a,(hl)
        inc hl
        ld b,(hl)
        ld c,2                  ; effects on channel C
        call mtk_sfx
        jr mainloop
sfx_off:
        call mtk_sfx_stop
        jr mainloop
toggle: ld a,(mtk_PL_PLAYING)
        or a
        jr z,toggle_on
        call mtk_stop
        jr mainloop
toggle_on:
        xor a
        call mtk_start
        jr mainloop

bad_song:
        ld hl,bad_text
        call print
        di
        halt

hook:   push af
        call mtk_frame
        pop af
        ret

print:  ld a,(hl)
        inc hl
        or a
        ret z
        call CHPUT
        jr print

sfx_table:                      ; instrument, note (49 = C-5)
        db 6,25                 ; 1 kick
        db 7,37                 ; 2 snare
        db 10,61                ; 3 laser
        db 11,37                ; 4 explosion
        db 12,60                ; 5 coin
        db 13,49                ; 6 jump
        db 15,49                ; 7 siren (loops until 0)

text:   db "MTKPLAY replayer example",13,10,13,10
        db "SPACE  music on/off",13,10
        db "1-7    sound effects",13,10
        db "0      stop the effect",13,10,0
bad_text:
        db "Not a MSXTRACK song",0

        include "../mtkplay.asm"

song:   incbin "demo.mtk"

        ds 8000h-$,0FFh
