#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_messagebox.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for messagebox(n).
#
# TBD:
#    Tests "messagebox gets" and "messagebox pick"
#
#-----------------------------------------------------------------------

package require Tk
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*


#-----------------------------------------------------------------------
# Main-line Code

set theString ""

snit::stringtype nonempty -minlen 1

proc ShowMessage {} {
    set ::theString [messagebox popup \
                         -buttons {cancel "Cancel" ok "OK"} \
                         -title   "messagebox popup" \
                         -message "For score and seven years ago..."]

}

proc GetString {} {
    set ::theString [messagebox gets \
                         -oktext "Go for it!" \
                         -parent .            \
                         -title "Enter a String" \
                         -initvalue $::theString \
                         -message [normalize {
                             Enter some string of your choice, and
                             press one of the buttons, so that you
                             can see what happens when you do.
                         }] \
                         -validatecmd Validate]
}

proc Validate {string} {
    if {![string length $string] > 0} {
        return -code error -errorcode INVALID \
            "Expected a string at least 1 character in length."
    }

    return [string toupper $string]
}


proc Pick {} {
    set ::theString [messagebox pick \
                         -oktext "Go ahead, pick one!" \
                         -parent . \
                         -title  "Pick one!" \
                         -initvalue "That One" \
                         -message [normalize {
                             Please select one of the many fine
                             choices from the list, below, and 
                             enjoy it.
                         }] -values {
                             "This One"
                             "That One"
                             "The Other One"
                         }]
}

proc main {argv} {
    # FIRST, pop up a debugger
    debugger new

    ttk::button .show \
        -text     "Show Message" \
        -command  ShowMessage

    ttk::button .gets \
        -text     "Get String"  \
        -command  GetString

    ttk::button .pick \
        -text     "Pick Item"  \
        -command  Pick

    ttk::label .lab \
        -width 40 \
        -textvariable theString

    pack .show -side top -fill x
    pack .gets -side top -fill x
    pack .pick -side top -fill x
    pack .lab  -side top -fill x
}



#-----------------------------------------------------------------------
# Invoke application

main $argv




