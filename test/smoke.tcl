# MSXTRACK smoke test - run through run_tests.sh
source [file join [file dirname [info script]] lib.tcl]
source [file join [file dirname [info script]] fakedos.tcl]

proc snap {} {
  set pa [peek16 $::sym(PATTAB)]
  set n [expr {$::sym(SONGDATA_END)-$::sym(SONGDATA)}]
  return [list [debug read_block memory $::sym(SONGDATA) $n] [debug read_block memory $pa 2304]]
}

# boot
at 0 {
  check "title bar" {[string match "*MSXTRACK*F1 PAT*" [row 0]]}
  check "demo loaded" {[string match "*ORD 00/04*" [row 1]]}
  check "pattern shows notes" {[string match "*A-2 3*C-3 6*" [row 12]]}
  install_fakedos
  key 7 0
}
# the demo saved by the tracker must equal replayer/example/demo.mtk
at 0.3 { type "s" }
at 0.3 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { type "demo" }
at 0.5 { type "\r" }
at 1.0 {
  set f [open $::env(MSXT_DEMO) rb]; binary scan [read $f] cu* want; close $f
  check "tracker file == exported demo.mtk" {$::files(DEMO    MTK) eq $want}
  key 6 5
}
at 0.3 { type "\r" }
# play song: channel B plays the bass note A-2 (period 1017; the
# instrument starts one octave up for a click: 508)
at 0.5 {
  check "playing" {[peek $::sym(PL_PLAYING)] == 1}
  set p [expr {[psgreg 2] + 256*[psgreg 3]}]
  check "bass pitch A-2 (got $p)" {$p == 1017 || $p == 508}
  check "mixer keeps port B output, port A input" {([psgreg 7] & 0xC0) == 0x80}
  key 7 2
}
at 0.3 { check "ESC stops" {[peek $::sym(PL_PLAYING)] == 0} }
# note entry + preview on channel A
at 0.2 { type "q" }
at 0.3 {
  check "note entered" {[string match "00?C-5 1*" [row 12]] || [string match "*C-5 1*" [row 11]]}
  set p [expr {[psgreg 0] + 256*[psgreg 1]}]
  check "preview pitch C-5 (got $p)" {$p == 214}
  ctrl z
}
# every screen draws
at 0.3 { key 6 6 }
at 0.3 { check "song screen" {[string match "NAME*DEMO TUNE*" [row 1]]}; key 6 7 }
at 0.3 { check "instrument screen" {[string match "INSTRUMENT 1*SQUARE*" [row 1]]}; key 7 1 }
at 0.3 { check "help screen" {[string match "PATTERN EDITOR*" [row 2]]}; key 7 0 }
# disk round trip with an emulated BDOS
at 0.3 { set ::before [snap]; type "s" }
at 0.3 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { type "smoke" }
at 0.5 { type "\r" }
at 1.0 {
  check "disk save" {[string match "Song saved*" [row 23]]}
  check "file size (got [llength $::files(SMOKE   MTK)])" {[llength $::files(SMOKE   MTK)] == 8+1696+3*768}
  type "n"
}
at 0.3 { type "y" }
at 0.3 { check "new song clears" {[snap] ne $::before}; type "l" }
at 0.3 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { type "smoke" }
at 0.5 { type "\r" }
at 1.0 {
  check "disk load" {[string match "Song loaded*" [row 23]]}
  check "song restored byte for byte" {[snap] eq $::before}
}

# ---- editor features: undo, jam, new/clone position, end of pattern, hints,
#      unsaved-changes warning, overwrite question ----
proc cell {r ch} {
  set pat [peek [expr {$::sym(ORDERS) + [peek $::sym(ED_ORD)]}]]
  set pa [peek16 [expr {$::sym(PATTAB) + 2*$pat}]]
  return [peek [expr {$pa + $r*12 + $ch*4}]]
}
proc tab_to_a {} {
  set n [expr {(3 - [peek $::sym(ED_CH)]) % 3}]
  if {$n == 0 && [peek $::sym(ED_COL)] != 0} { set n 3 }
  for {set j 0} {$j < $n} {incr j} { after time [expr {0.2*$j}] {key 7 3} }
}
at 0.3 { key 6 5 }
at 0.5 { tab_to_a; key 8 1 }
at 1.0 { set ::orig [cell 0 0]; type "z" }
at 0.4 { check "note typed" {[cell 0 0] == 37}; ctrl z }
at 0.4 { check "CTRL+Z undoes it" {[cell 0 0] == $::orig}; ctrl z }
at 0.4 { check "CTRL+Z again redoes it" {[cell 0 0] == 37}; ctrl j }
at 0.4 { check "status shows JAM" {[string match "*JAM*" [row 23]]}; key 8 1 }
at 0.3 { type "x" }
at 0.4 {
  set p [expr {[psgreg 0] + 256*[psgreg 1]}]
  check "jam plays D-4 without writing (period $p)" {$p == 381 && [cell 0 0] == 37}
  check "hint line explains the note column" {[string match "JAM: keys only play*" [row 22]]}
  ctrl j
}
at 0.4 { set ::len [peek $::sym(SNG_LEN)]; set ::ord [peek $::sym(ED_ORD)]; ctrl n }
at 0.5 {
  check "CTRL+N adds a position" {[peek $::sym(SNG_LEN)] == $::len+1 && [peek $::sym(ED_ORD)] == $::ord+1}
  set ::newpat [peek [expr {$::sym(ORDERS) + [peek $::sym(ED_ORD)]}]]
  check "... with an unused pattern ($::newpat)" {$::newpat >= 3}
  check "... that is empty" {[cell 0 0] == 0 && [cell 0 1] == 0 && [cell 0 2] == 0}
  type "q"
}
at 0.4 { ctrl b }
at 0.5 {
  set p2 [peek [expr {$::sym(ORDERS) + [peek $::sym(ED_ORD)]}]]
  check "CTRL+B clones into another pattern ($p2)" {$p2 != $::newpat && [cell 0 0] == 49}
  keymatrixdown 6 1; after time 0.02 {key 8 1}; after time 0.2 {keymatrixup 6 1}
}
at 0.4 { check "SHIFT+HOME goes to the last row" {[peek $::sym(ED_ROW)] == [peek $::sym(SNG_PATLEN)]-1}; key 8 7 }
at 0.1 { key 8 7 }
at 0.1 { key 8 7 }
at 0.3 { check "effect column hint" {[string match "Effect:*" [row 22]]}; key 7 0 }
at 0.4 { type "n" }
at 0.4 { check "unsaved changes warning" {[string match "Song not saved!*" [row 23]]}; type "n" }
at 0.3 { type "s" }
at 0.3 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { type "smoke" }
at 0.5 { type "\r" }
at 0.8 { check "asks before replacing a file" {[string match "File exists*" [row 23]]}; type "y" }
at 1.0 { check "saved after confirming" {[string match "Song saved*" [row 23]]}; type "n" }
at 0.4 { check "no warning once saved" {[string match "Erase the whole song*" [row 23]]}; type "n" }
finish
