# Test of the standalone replayer example cartridge - run through run_tests.sh
source [file join [file dirname [info script]] lib.tcl]
set ::sfxframes 0
proc vol {} { expr {[psgreg 8] + [psgreg 9] + [psgreg 10]} }
at 0 {
  check "example screen" {[string match "MTKPLAY replayer example*" [row 0]]}
  check "music playing" {[peek $::sym(mtk_PL_PLAYING)] == 1}
  check "music audible" {[vol] > 0}
  check "mixer keeps MSX I/O bits" {([psgreg 7] & 0xC0) == 0x80}
  debug set_bp $::sym(hook) {} { if {[peek $::sym(mtk_SFX_ON)]} { incr ::sfxframes } }
  type "3"
}
at 0.5 { check "laser effect lasts its 10 steps (got $::sfxframes)" {$::sfxframes == 10}; type "7" }
at 0.5 { check "looping effect keeps going" {[peek $::sym(mtk_SFX_ON)] == 1}; type "0" }
at 0.2 { check "effect stops" {[peek $::sym(mtk_SFX_ON)] == 0}; type " " }
at 0.3 { check "music stops and goes silent" {[peek $::sym(mtk_PL_PLAYING)] == 0 && [vol] == 0} }
finish
