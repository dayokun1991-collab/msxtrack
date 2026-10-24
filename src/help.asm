; ===========================================================================
; Help (F5) - three pages
; ===========================================================================

draw_help:
        call draw_title
        ld hl,help_text
        ld a,(HELPPG)
        or a
        jr z,dh_go
        ld b,a
dh_skip:
        ld a,(hl)
        inc hl
        cp 0FFh
        jr nz,dh_skip
        djnz dh_skip
dh_go:  ld b,2
dh_line:
        ld a,(hl)
        cp 0FFh
        jr z,dh_end
        ld c,0
        push bc
        call at_pstr
        pop bc
        inc b
        jr dh_line
dh_end: PRINTAT 22,0,"PAGE "
        ld a,(HELPPG)
        inc a
        call phex1
        PRINT "/3  SPACE = next page"
        ret

help_key:
        cp 29
        jr z,hk_prev
        cp 30
        jr z,hk_prev
        cp 28
        jr z,hk_next
        cp 31
        jr z,hk_next
        cp 32
        ret nz
hk_next:
        ld a,(HELPPG)
        inc a
        cp 3
        jr c,hk_set
        xor a
        jr hk_set
hk_prev:
        ld a,(HELPPG)
        dec a
        jp p,hk_set
        ld a,2
hk_set: ld (HELPPG),a
        ret

help_text:
        db "PATTERN EDITOR (F1)",0
        db "Arrows move   SHIFT+UP/DOWN 16 rows",0
        db "SHIFT+LEFT/RIGHT prev/next position",0
        db "TAB next channel     HOME first row",0
        db "Piano: Z S X D C V G B H N J M",0
        db "       Q 2 W 3 E R 5 T 6 Y 7 U I 9 O 0 P",0
        db "1      note off (===)",0
        db "0-9A-F instrument, volume, effect",0
        db "DEL clear  BS delete row  INS insert",0
        db "[ ]  octave         , .  instrument",0
        db "< >  pattern number at this position",0
        db "- =  edit step (rows to move)",0
        db "SPACE play pattern  RETURN play song",0
        db "ESC  stop (any screen)",0
        db "CTRL+C/V  copy/paste track",0
        db "CTRL+A/P  copy/paste pattern",0
        db "CTRL+U/D  transpose  CTRL+E clear",0
        db "SHIFT+F1/F2/F3 mute A/B/C",0
        db "SHIFT+F4 follow   SHIFT+F5 unmute all",0
        db 0FFh
        db "EFFECTS (hex, after the volume)",0
        db "0xy arpeggio +x,+y semitones",0
        db "1xx slide up        2xx slide down",0
        db "3xx portamento to the note, speed xx",0
        db "4xy vibrato, speed x depth y",0
        db "5xx envelope period high  6xx low",0
        db "7xy envelope shape y (restarts it)",0
        db "8xx noise period (20+ = instrument)",0
        db "9xx delay the note by xx ticks",0
        db "Axy volume slide: up x or down y",0
        db "Bxx jump to song position xx",0
        db "Cxx cut the note after xx ticks",0
        db "Dxx next position, start at row xx",0
        db "Exx detune (signed period offset)",0
        db "Fxx speed: xx ticks per row",0
        db "0-4 and A keep running on the next",0
        db "rows until 000 or a new note.",0
        db "Cell: NOTE INSTRUMENT VOLUME EFFECT",0
        db "      C-4  1          F      A03",0
        db 0FFh
        db "INSTRUMENTS / SOUND EFFECTS (F3)",0
        db "Up to 16 steps, each with:",0
        db " V   volume 0-F",0
        db " ARP semitones added to the note",0
        db " SWP pitch sweep, added every tick",0
        db " NOI noise period 00-1F",0
        db " T N E  tone, noise, hw envelope",0
        db "LENGTH steps, LOOP restart step",0
        db "(DEL = hold last step), SPEED ticks",0
        db "ENVELOPE MODE 0 uses PERIOD, 1-4",0
        db "follow the note (2 = same pitch)",0
        db "SPACE test sound  RETURN retrigger",0
        db "CTRL+C/V copy/paste  , . instrument",0
        db " ",0
        db "SONG (F2): name, speed, rows, order",0
        db "list (INS/DEL/RETURN). FILE (F4):",0
        db "disk + tape save/load, new, demo.",0
        db 0FFh
