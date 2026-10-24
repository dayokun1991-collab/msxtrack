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
  type "\r"
}
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
at 0.3 { install_fakedos; set ::before [snap]; type "s" }
at 0.3 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { key 7 5 }
at 0.1 { type "smoke" }
at 0.5 { type "\r" }
at 1.0 {
  check "disk save" {[string match "Song saved*" [row 23]]}
  check "file size" {[llength $::files(SMOKE   MTK)] == 8+1696+3*768}
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
finish
