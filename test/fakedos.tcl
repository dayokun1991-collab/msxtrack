# Minimal fake of the Disk BASIC BDOS (F37D) for testing MSXTRACK's file code
array set ::files {}
set ::dma 0x80
set ::srch {}
proc fcbname {de} { set n ""; for {set i 1} {$i < 12} {incr i} { append n [format %c [peek [expr {$de+$i}]]] }; return $n }
proc getrr {de} { return [expr {[peek16 [expr {$de+33}]] + ([peek16 [expr {$de+35}]] << 16)}] }
proc setrr {de v} { poke16 [expr {$de+33}] [expr {$v & 0xFFFF}]; poke16 [expr {$de+35}] [expr {$v >> 16}] }
proc bdos {} {

  set c [reg c]; set de [reg de]; set hl [reg hl]
  switch -- $c {
    26 { set ::dma $de; reg a 0 }
    22 { set ::files([fcbname $de]) {}; set ::cur [fcbname $de]; reg a 0 }
    15 { set n [fcbname $de]; if {[info exists ::files($n)]} { reg a 0 } else { reg a 255 } }
    16 { reg a 0 }
    38 { set n [fcbname $de]; set rr [getrr $de]; set data $::files($n)
         while {[llength $data] < $rr} { lappend data 0 }
         for {set i 0} {$i < $hl} {incr i} { set b [peek [expr {$::dma+$i}]]; set p [expr {$rr+$i}]
           if {$p < [llength $data]} { lset data $p $b } else { lappend data $b } }
         set ::files($n) $data; setrr $de [expr {$rr+$hl}]; reg a 0 }
    39 { set n [fcbname $de]; set rr [getrr $de]; set data $::files($n); set got 0
         for {set i 0} {$i < $hl} {incr i} { set p [expr {$rr+$i}]; if {$p >= [llength $data]} break
           poke [expr {$::dma+$i}] [lindex $data $p]; incr got }
         setrr $de [expr {$rr+$got}]; reg hl $got; if {$got == $hl} { reg a 0 } else { reg a 1 } }
    17 { set ::srch [lsort [array names ::files]]; bdos_next }
    18 { bdos_next }
    default { puts stderr "BDOS fn $c unsupported"; reg a 255 }
  }
}
proc bdos_next {} {
  if {[llength $::srch] == 0} { reg a 255; return }
  set n [lindex $::srch 0]; set ::srch [lrange $::srch 1 end]
  poke $::dma 0; for {set i 0} {$i < 11} {incr i} { scan [string index $n $i] %c ch; poke [expr {$::dma+1+$i}] $ch }
  reg a 0
}
proc install_fakedos {} { poke 0xF37D 0xC9; poke $::sym(HASDISK) 1; debug set_bp 0xF37D {} { if {[catch bdos e]} { puts stderr "BDOSERR $e" } } }
