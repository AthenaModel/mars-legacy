#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_pwinman.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for pwinman(n), pwin(n)
#
#-----------------------------------------------------------------------

package require Tk
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*


#-----------------------------------------------------------------------
# Main-line Code

set chartCount 0

proc CreateChart {w args} {
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
    set xmin -100
    set xmax  100
    
    hbarchart $w     \
        -width    500 \
        -height   250 \
        -titlepos n               \
        -title  "Chart #[incr ::chartCount]" \
        -xtext  "Satisfaction"    \
        -ytext  "Countries"       \
        -xmin   $xmin             \
        -xmax   $xmax             \
        -xformat %.1f             \
        -ylabels  $countries      \
        {*}$args

    for {set s 0} {$s < $numSeries} {incr s} {
        set data($s) [list]

        foreach c $countries {
            let x [expr {rand()*($xmax-$xmin) + $xmin}]

            lappend data($s) $x
        }

        $w plot series$s -label "Series $s" -data $data($s)
    }
}

proc echo {args} {
    puts $args
}

proc CreatePwin {w} {
    set chart [$w frame].chart
    set ybar  [$w frame].ybar

    ttk::scrollbar $ybar \
        -command [list [$w frame].chart yview]

    CreateChart $chart \
        -yscrollcommand [list $ybar set]
        
    pack $ybar -side right -fill y
    pack $chart -fill both -expand yes
}

proc main {argv} {
    # FIRST, pop up a debugger
    debugger new

    ttk::button .new \
        -text     "New Chart"  \
        -command  {CreatePwin [.man add]}

    pwinman .man \
        -width 600 \
        -height 600

    pack .new -side top -fill x
    pack .man -fill both -expand yes
}



#-----------------------------------------------------------------------
# Invoke application

main $argv




