#!/bin/sh
# -*-tcl-*-
# The next line restarts using wish \
exec wish8.4 "$0" "$@"

package require marsutil
package require gui
package require simlib
namespace import ::marsutil::* gui::* simlib::*

set a [mat new 6 16 0]

set nc [mat rows $a]
set nf [mat cols $a]

set rownames {INF SEC RLS OFC SVC CAS}
set colnames {
    SHI1 SUN1 KRD1
    SHI2 SUN2 KRD2
    SHI3 SUN3 KRD3
    SHI4 SUN4 KRD4
    
    NGO1 NGO2 NGO3 NGO4
}

for {set c 0} {$c < $nc} {incr c} {
    for {set f 0} {$f < $nf} {incr f} {
        lset a $c $f [expr {$c*$f}]
    }
}

matrixeditor .medit            \
    -height   [expr {$nc + 1}] \
    -width    [expr {$nf + 1}] \
    -rowtitles  $rownames        \
    -coltitles  $colnames        \
    -colwidth 6                \
    -validatecmd [list ::simlib::qsat value] \
    -normalizecmd [list string toupper]

pack .medit

.medit set $a

debugger new
