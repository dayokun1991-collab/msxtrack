# Helpers for driving MSXTRACK inside openMSX (sourced by smoke.tcl)
set renderer none
set throttle off
source $::env(MSXT_SYMS)

proc screen_text {} {
  set out {}
  for {set r 0} {$r < 24} {incr r} {
    set line ""
    for {set c 0} {$c < 40} {incr c} {
      set ch [expr {[vpeek [expr {$r*40+$c}]] & 127}]
      if {$ch < 32 || $ch > 126} { set ch 63 }
      append line [format %c $ch]
    }
    lappend out $line
  }
  return $out
}
proc row {n} { return [lindex [screen_text] $n] }
proc psgreg {i} { return [debug read "PSG regs" $i] }
proc key {row bit} { keymatrixdown $row [expr {1<<$bit}]; after time 0.05 "keymatrixup $row [expr {1<<$bit}]" }
proc ctrl {letter} { keymatrixdown 6 2; after time 0.02 "type $letter"; after time 0.15 "keymatrixup 6 2" }

set ::fails 0
proc check {name cond} {
  if {[uplevel 1 [list expr $cond]]} { puts stderr "PASS $name" } else { puts stderr "FAIL $name"; incr ::fails }
}
set ::t 6.0
proc at {dt cmd} { set ::t [expr {$::t+$dt}]; after time $::t $cmd }
proc finish {} { at 0.2 { puts stderr "RESULT fails=$::fails"; exit } }
