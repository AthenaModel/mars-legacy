#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_hbarchart.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for hbarchart
#
#-----------------------------------------------------------------------

package require Tk
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*

#-----------------------------------------------------------------------
# Main-line Code

proc main {argv} {
    set countries {
        Afghanistan
        Australia
        Belgium
        Burma
        China
        Egypt
        England
        Ethiopia
        France
        Germany
        India
        Iran
        Iraq
        Italy
        Japan
        Nepal
        Pakistan
        Somalia
        Spain
        Sweden
        "United States"
    }

    set numSeries 1

    if {[llength $argv] > 0} {
        set numSeries [lindex $argv 0]
    }

    set xmin -100
    set xmax  100
    
    hbarchart .chart \
        -width  400  \
        -height 300  \
        -title  "My Sample Chart" \
        -titlepos n               \
        -xtext  "Satisfaction"    \
        -ytext  "Countries"       \
        -xmin   $xmin             \
        -xmax   $xmax             \
        -xformat %.1f             \
        -yscrollcommand [list .yscroll set] \
        -ylabels  $countries

    ttk::scrollbar .yscroll \
        -orient   vertical \
        -command [list .chart yview]
    
    pack .yscroll -side right -fill y

    pack .chart -fill both -expand yes

    for {set s 0} {$s < $numSeries} {incr s} {
        set data($s) [list]

        foreach c $countries {
            let x [expr {rand()*($xmax-$xmin) + $xmin}]

            lappend data($s) $x
        }

        .chart plot series$s -label "Series $s" -data $data($s)
    }

    bind .chart <3> {puts "Right-click!"}
    bind . <Control-F12> {debugger new}
}



#-----------------------------------------------------------------------
# Invoke application

main $argv




