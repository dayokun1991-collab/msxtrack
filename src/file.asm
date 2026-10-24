; ===========================================================================
; File menu (F4): disk (Disk BASIC BDOS, if a drive is present) and tape
;
; Song file layout ("NAME.MTK" on disk, one block on tape):
;   6  "MSXTRK"
;   1  format version (1)
;   1  number of patterns stored (N)
;   1696 song block: settings(32) order list(128) instruments(16 x 96)
;   N x 768 patterns (64 rows x 3 channels x 4 bytes)
;   tape only: 1 byte checksum (sum of all previous bytes)
; ===========================================================================

FILEVER equ 1

draw_file:
        call draw_title
        PRINTAT 2,0,"FILE NAME  "
        ld hl,FILENAME
        ld b,8
        call pfix
        PRINT ".MTK"
        PRINTAT 4,2,"S  Save song to disk"
        PRINTAT 5,2,"L  Load song from disk"
        PRINTAT 6,2,"D  Disk directory"
        PRINTAT 8,2,"W  Write song to tape"
        PRINTAT 9,2,"R  Read song from tape"
        PRINTAT 11,2,"N  New song (erase all)"
        PRINTAT 12,2,"X  Load the demo song"
        ld a,(HASDISK)
        or a
        jr nz,dfl_dir
        PRINTAT 14,2,"(no disk drive found - tape only)"
        ret
dfl_dir:
        ld a,(DIRCNT)
        or a
        ret z
        PRINTAT 14,0,"Songs on disk:"
        ld hl,DIRBUF
        ld b,15
        ld c,0
        ld a,(DIRCNT)
        ld e,a
dfl_lp: push bc
        push de
        push hl
        call at
        pop hl
        ld b,8
        call pfix
        pop de
        pop bc
        ld a,c
        add a,10
        ld c,a
        cp 40
        jr c,dfl_n
        ld c,0
        inc b
        ld a,b
        cp 23
        ret nc
dfl_n:  dec e
        jr nz,dfl_lp
        ret

file_key:
        cp 'S'
        jp z,disk_save
        cp 'L'
        jp z,disk_load
        cp 'D'
        jp z,disk_dir
        cp 'W'
        jp z,tape_save
        cp 'R'
        jp z,tape_load
        cp 'N'
        jr z,fk_new
        cp 'X'
        ret nz
        ld hl,msg_demo
        call confirm
        ret nz
        call play_stop
        call new_song
        call load_demo
        ld hl,msg_done
        jp set_msg
fk_new: ld hl,msg_new
        call confirm
        ret nz
        call play_stop
        call new_song
        ld hl,msg_done
        jp set_msg

; ---- filename prompt in the status line. Z = accepted ----
input_name:
        ld hl,FILENAME          ; cursor after the last non-blank char
        ld b,8
        ld c,0
inm_len:
        ld a,(hl)
        inc hl
        cp ' '+1
        jr c,inm_sp
        ld a,9
        sub b
        ld c,a
inm_sp: djnz inm_len
inm_loop:
        push bc
        ld hl,txt_name          ; build "NAME: ABC_     " in DMABUF
        ld de,DMABUF
        ld bc,txt_name_len
        ldir
        ld hl,FILENAME
        ld bc,8
        ldir
        ld hl,txt_name_end
        ld bc,txt_name_end_len
        ldir
        pop bc
        push bc
        ld hl,DMABUF+txt_name_len
        ld b,0
        add hl,bc
        ld a,(hl)
        or 80h
        ld (hl),a
        ld hl,DMABUF
        call set_msg
        call refresh
        call wait_key
        pop bc
        cp 13
        jr z,inm_ok
        cp 27
        jr z,inm_cancel
        cp 8
        jr z,inm_bs
        ld e,a                  ; legal file name characters
        call name_char
        jr c,inm_loop
        ld a,c
        cp 8
        jr nc,inm_loop
        ld hl,FILENAME
        ld d,0
        push de
        ld e,c
        add hl,de
        pop de
        ld (hl),e
        inc c
        jr inm_loop
inm_bs: ld a,c
        or a
        jr z,inm_loop
        dec c
        ld hl,FILENAME
        ld b,0
        add hl,bc
        ld (hl),' '
        jr inm_loop
inm_ok: ld hl,0
        ld (MSGPTR),hl
        ld a,c
        or a
        jr z,inm_cancel
        xor a
        ret
inm_cancel:
        ld hl,0
        ld (MSGPTR),hl
        or 1
        ret

; E = char -> carry if not allowed in a file name
name_char:
        ld a,e
        cp '0'
        ret c
        cp '9'+1
        ccf
        ret nc
        cp 'A'
        ret c
        cp 'Z'+1
        ccf
        ret nc
        cp '_'
        ret z
        scf
        ret

txt_name:
        db "FILE NAME: "
txt_name_len equ $-txt_name
txt_name_end:
        db ".MTK RET=ok ESC=cancel",0
txt_name_end_len equ $-txt_name_end

; ---- song size: highest pattern in use + 1 ----
count_used:
        ld c,1
        ld hl,ORDERS
        ld a,(SNG_LEN)
        ld b,a
cu_ord: ld a,(hl)
        inc a
        cp c
        jr c,cu_o1
        ld c,a
cu_o1:  inc hl
        djnz cu_ord
        ld a,(NUMPAT)
cu_lp:  cp c
        jr z,cu_done
        jr c,cu_done
        dec a
        push af
        push bc
        call get_pat_addr
        ld bc,PATSIZE
cu_e:   ld a,(hl)
        or a
        jr nz,cu_used
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,cu_e
        pop bc
        pop af
        jr cu_lp
cu_used:
        pop bc
        pop af
        inc a
        ld c,a
cu_done:
        ld a,c
        ld hl,NUMPAT
        cp (hl)
        ret c
        ld a,(hl)
        ret

make_header:
        call count_used
        ld (FILEHDR+7),a
        ld hl,magic
        ld de,FILEHDR
        ld bc,6
        ldir
        ld a,FILEVER
        ld (de),a
        ret

magic:  db "MSXTRK"

; check FILEHDR. Z = ok, else HL = error message
check_header:
        ld hl,FILEHDR
        ld de,magic
        ld b,6
ch_lp:  ld a,(de)
        cp (hl)
        jr nz,ch_bad
        inc hl
        inc de
        djnz ch_lp
        ld a,(hl)
        cp FILEVER
        jr nz,ch_bad
        inc hl
        ld a,(hl)
        or a
        jr z,ch_bad
        ld a,(NUMPAT)
        cp (hl)
        jr c,ch_big
        xor a
        ret
ch_bad: ld hl,msg_notsong
        or 1
        ret
ch_big: ld hl,msg_big
        or 1
        ret

; make a loaded song safe to edit and play, clear unused patterns
after_load:
        ld a,(FILEHDR+7)
        ld b,a
al_clr: ld a,(NUMPAT)
        cp b
        jr z,al_fix
        jr c,al_fix
        ld a,b
        push bc
        call get_pat_addr
        call clear_pat
        pop bc
        inc b
        jr al_clr
al_fix: ld hl,SNG_SPEED
        ld bc,011Fh
        call clamp_hl
        ld hl,SNG_PATLEN
        ld bc,0140h
        call clamp_hl
        ld hl,SNG_LEN
        ld bc,0180h
        call clamp_hl
        ld hl,ORDERS
        ld b,ORDMAX
al_ord: ld a,(NUMPAT)
        dec a
        cp (hl)
        jr nc,al_o1
        ld (hl),0
al_o1:  inc hl
        djnz al_ord
        ld a,1                  ; instruments
al_ins: push af
        call ins_addr
        push hl
        ld bc,0110h
        call clamp_hl
        pop hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr nz,al_i1
        inc (hl)
al_i1:  pop af
        inc a
        cp NINS
        jr c,al_ins
reset_editor:
        xor a
        ld (ED_ORD),a
        ld (ED_ROW),a
        ld (SG_POS),a
        ld (SG_FIELD),a
        ld (IN_COL),a
        ld a,3
        ld (IN_ROW),a
        jp song_fix

; keep (HL) within B..C
clamp_hl:
        ld a,(hl)
        cp b
        jr nc,ch_1
        ld (hl),b
ch_1:   ld a,c
        cp (hl)
        ret nc
        ld (hl),c
        ret

clear_pat:
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,PATSIZE-1
        ldir
        ret

; ---------------------------------------------------------------------------
; Disk
; ---------------------------------------------------------------------------
need_disk:
        ld a,(HASDISK)
        or a
        ret nz
        ld hl,msg_nodisk
        call set_msg
        xor a
        ret

disk_begin:
        call play_stop
        ei
        halt                    ; let the interrupt silence the PSG
        ld hl,(DISKVE)
        ld (OLDDSKVE),hl
        ld hl,(BREAKV)
        ld (OLDBRKV),hl
        ld hl,DSKVEPTR
        ld (DISKVE),hl
        ld hl,BRKVPTR
        ld (BREAKV),hl
        xor a
        ld (DSKERR),a
        call make_fcb
        ld de,DMABUF
        ld c,1Ah                ; set transfer address
        jp bdos

disk_end:
        ld hl,(OLDDSKVE)
        ld (DISKVE),hl
        ld hl,(OLDBRKV)
        ld (BREAKV),hl
        ei
        ret

bdos:   push ix
        push iy
        call BDOS
        pop iy
        pop ix
        ret

make_fcb:
        ld hl,FCB
        ld de,FCB+1
        ld bc,36
        ld (hl),0
        ldir
        ld hl,FILENAME
        ld de,FCB+1
        ld bc,8
        ldir
        ld hl,mtk_ext
        ld bc,3
        ldir
        ret
mtk_ext:
        db "MTK"

fcb_setup:
        ld hl,1                 ; record size 1 byte
        ld (FCB+14),hl
        ld hl,0
        ld (FCB+33),hl
        ld (FCB+35),hl
        ret

; the disk ROM gave up (no disk, write protected, ...)
disk_aborted:
        call disk_end
        ld hl,msg_diskerr
        call set_msg
        ret                     ; SP was reset to the caller of the command

; HL = address, DE = length. Writes through DMABUF in 128 byte pieces.
; NZ on error.
dwrite: ld a,d
        or e
        ret z
        ld bc,128
        ex de,hl
        or a
        sbc hl,bc
        jr nc,dw_full
        add hl,bc
        ld c,l
        ld hl,0
dw_full:
        ex de,hl                ; HL = address, DE = remaining, BC = piece
        push de
        push bc
        ld de,DMABUF
        ldir
        pop bc
        push hl
        ld h,b
        ld l,c
        ld de,FCB
        ld c,26h                ; random block write
        call bdos
        pop hl
        pop de
        or a
        ret nz
        jr dwrite

; HL = address, DE = length. NZ on error / short file.
dread:  ld a,d
        or e
        ret z
        ld bc,128
        ex de,hl
        or a
        sbc hl,bc
        jr nc,dr_full
        add hl,bc
        ld c,l
        ld hl,0
dr_full:
        ex de,hl
        push de
        push hl
        push bc
        ld h,b
        ld l,c
        ld de,FCB
        ld c,27h                ; random block read
        call bdos
        pop bc
        or a
        jr nz,dr_err
        pop de                  ; DE = destination
        ld hl,DMABUF
        ldir
        ex de,hl
        pop de
        jr dread
dr_err: pop hl
        pop de
        or 1
        ret

disk_save:
        ld (SAVESP),sp
        call need_disk
        ret z
        call input_name
        ret nz
        call make_header
        call disk_begin
        ld de,FCB
        ld c,16h                ; create
        call bdos
        or a
        jr nz,dsv_fail
        call fcb_setup
        ld hl,FILEHDR
        ld de,8
        call dwrite
        jr nz,dsv_fail
        ld hl,SONGDATA
        ld de,SONGDATA_END-SONGDATA
        call dwrite
        jr nz,dsv_fail
        xor a
dsv_pat:
        ld hl,FILEHDR+7
        cp (hl)
        jr nc,dsv_done
        push af
        call get_pat_addr
        ld de,PATSIZE
        call dwrite
        pop bc
        jr nz,dsv_fail
        ld a,b
        inc a
        jr dsv_pat
dsv_done:
        ld de,FCB
        ld c,10h                ; close
        call bdos
        or a
        jr nz,dsv_fail
        call disk_end
        ld hl,msg_saved
        jp set_msg
dsv_fail:
        call disk_end
        ld hl,msg_diskerr
        jp set_msg

disk_load:
        ld (SAVESP),sp
        call need_disk
        ret z
        call input_name
        ret nz
        call disk_begin
        ld de,FCB
        ld c,0Fh                ; open
        call bdos
        or a
        jr nz,dld_nf
        call fcb_setup
        ld hl,FILEHDR
        ld de,8
        call dread
        jr nz,dld_fail
        call check_header
        jr nz,dld_msg
        ld hl,SONGDATA
        ld de,SONGDATA_END-SONGDATA
        call dread
        jr nz,dld_fail
        xor a
dld_pat:
        ld hl,FILEHDR+7
        cp (hl)
        jr nc,dld_done
        push af
        call get_pat_addr
        ld de,PATSIZE
        call dread
        pop bc
        jr nz,dld_fail
        ld a,b
        inc a
        jr dld_pat
dld_done:
        ld de,FCB
        ld c,10h
        call bdos
        call disk_end
        call after_load
        ld hl,msg_loaded
        jp set_msg
dld_nf: ld hl,msg_notfound
        jr dld_msg
dld_fail:
        call after_load
        ld hl,msg_diskerr
dld_msg:
        push hl
        call disk_end
        pop hl
        jp set_msg

disk_dir:
        ld (SAVESP),sp
        call need_disk
        ret z
        xor a
        ld (DIRCNT),a
        call disk_begin
        ld hl,qmarks            ; search ????????.MTK
        ld de,FCB+1
        ld bc,8
        ldir
        ld de,FCB
        ld c,11h                ; search first
dd_lp:  call bdos
        or a
        jr nz,dd_end
        ld a,(DIRCNT)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,DIRBUF
        add hl,de
        ex de,hl
        ld hl,DMABUF+1
        ld bc,8
        ldir
        ld hl,DIRCNT
        inc (hl)
        ld a,(hl)
        cp DIRMAX
        jr nc,dd_end
        ld de,FCB
        ld c,12h                ; search next
        jr dd_lp
dd_end: call disk_end
        ld a,(DIRCNT)
        or a
        ret nz
        ld hl,msg_nofiles
        jp set_msg

qmarks: db "????????"

; ---------------------------------------------------------------------------
; Tape (BIOS cassette routines, 1200/2400 baud as set in BASIC)
; ---------------------------------------------------------------------------
tape_save:
        ld hl,msg_rec
        call tape_prompt
        ret nz
        call make_header
        xor a
        ld (CHKSUM),a
        ld a,1                  ; long header
        call TAPOON
        jr c,ts_err
        ld hl,FILEHDR
        ld de,8
        call twrite
        jr c,ts_err
        ld hl,SONGDATA
        ld de,SONGDATA_END-SONGDATA
        call twrite
        jr c,ts_err
        xor a
ts_pat: ld hl,FILEHDR+7
        cp (hl)
        jr nc,ts_end
        push af
        call get_pat_addr
        ld de,PATSIZE
        call twrite
        pop bc
        jr c,ts_err
        ld a,b
        inc a
        jr ts_pat
ts_end: ld a,(CHKSUM)
        call TAPOUT
        jr c,ts_err
        call TAPOOF
        ei
        ld hl,msg_saved
        jp set_msg
ts_err: call TAPOOF
        ei
        ld hl,msg_tapeerr
        jp set_msg

twrite: ld a,d
        or e
        ret z
        ld a,(hl)
        ld b,a
        ld a,(CHKSUM)
        add a,b
        ld (CHKSUM),a
        ld a,b
        push hl
        push de
        call TAPOUT
        pop de
        pop hl
        ret c
        inc hl
        dec de
        jr twrite

tape_load:
        ld hl,msg_play
        call tape_prompt
        ret nz
        xor a
        ld (CHKSUM),a
        call TAPION
        jr c,tl_err
        ld hl,FILEHDR
        ld de,8
        call tread
        jr c,tl_err
        call check_header
        jr nz,tl_msg
        ld hl,SONGDATA
        ld de,SONGDATA_END-SONGDATA
        call tread
        jr c,tl_bad
        xor a
tl_pat: ld hl,FILEHDR+7
        cp (hl)
        jr nc,tl_end
        push af
        call get_pat_addr
        ld de,PATSIZE
        call tread
        pop bc
        jr c,tl_bad
        ld a,b
        inc a
        jr tl_pat
tl_end: ld a,(CHKSUM)
        ld b,a
        push bc
        call TAPIN
        pop bc
        jr c,tl_bad
        cp b
        jr nz,tl_bad
        call TAPIOF
        ei
        call after_load
        ld hl,msg_loaded
        jp set_msg
tl_bad: call after_load
tl_err: ld hl,msg_tapeerr
tl_msg: push hl
        call TAPIOF
        ei
        pop hl
        jp set_msg

tread:  ld a,d
        or e
        ret z
        push hl
        push de
        call TAPIN
        pop de
        pop hl
        ret c
        ld (hl),a
        ld b,a
        ld a,(CHKSUM)
        add a,b
        ld (CHKSUM),a
        inc hl
        dec de
        jr tread

; HL = message. Waits for RETURN (Z) or ESC (NZ)
tape_prompt:
        push hl
        call play_stop
        pop hl
        call set_msg
        call refresh
tp_wait:
        call wait_key
        cp 13
        jr z,tp_ok
        cp 27
        jr nz,tp_wait
        or a
tp_ok:  push af
        ld hl,0
        ld (MSGPTR),hl
        ld hl,msg_wait
        call set_msg
        call refresh
        pop af
        ret

msg_new:        db "Erase the whole song? (Y/N)",0
msg_demo:       db "Replace song with the demo? (Y/N)",0
msg_done:       db "Done",0
msg_saved:      db "Song saved",0
msg_loaded:     db "Song loaded",0
msg_diskerr:    db "Disk error",0
msg_notfound:   db "File not found",0
msg_notsong:    db "Not a MSXTRACK song",0
msg_big:        db "Song too big for this MSX's RAM",0
msg_nodisk:     db "No disk drive",0
msg_nofiles:    db "No .MTK files on this disk",0
msg_rec:        db "Press REC+PLAY, then RETURN (ESC=cancel)",0
msg_play:       db "Press PLAY, then RETURN (ESC=cancel)",0
msg_wait:       db "Working... (STOP aborts)",0
msg_tapeerr:    db "Tape error / aborted",0
