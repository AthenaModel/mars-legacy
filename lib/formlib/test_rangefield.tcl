#-----------------------------------------------------------------------
# FILE: test_rangefield.tcl
#
#   rangefield(n) test script
#
# PACKAGE:
#   formlib(n) -- Mars Forms Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
# Problems with ttk::scale
#
# * No blue halo
# * Appearance doesn't change when disabled. (Though setting the
#   label color will help with this.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require marsutil
package require simlib
package require marsgui
package require formlib

source rangefield.tcl

namespace import marsutil::*
namespace import simlib::*
namespace import marsgui::*
namespace import formlib::*


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    ttk::label .lab -text "Satisfaction:"

    form .form

    form register sat rangefield \
        -type ::simlib::qsat \
        -showsymbols yes

    form register coop rangefield \
        -type ::simlib::qcooperation \
        -showsymbols yes \
        -resetvalue 50

    .form field create s "Satisfaction" sat
    .form field create c "Cooperation"  coop
    .form field create t "Text" text

    .form layout

    grid .form  -row 0 -column 0 -sticky ew  -pady 4 -padx 4

    grid columnconfigure . 0 -weight 1
    

    bind . <Control-F12> {debugger new}
}

set inChangeCmd 0

proc ChangeCmd {args} {
    puts "Value = <[.form get]>"
}

#-------------------------------------------------------------------
# Invoke the program

main $argv








