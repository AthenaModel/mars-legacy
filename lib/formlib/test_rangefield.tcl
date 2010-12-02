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

    form .form \
        -changecmd ChangeCmd

    form register sat rangefield \
        -type ::simlib::qsat \
        -showsymbols yes \
        -changemode onrelease

    form register coop rangefield \
        -type ::simlib::qcooperation \
        -showsymbols yes \
        -resetvalue 50


    snit::double ::fraction -min 0.0 -max 1.0
    form register fraction rangefield \
        -type ::fraction              \
        -resetvalue 0.0

    form register dummy rangefield


    .form field create s "Satisfaction" sat
    .form field create c "Cooperation"  coop
    .form field create f "Fraction   "  fraction
    .form field create d "Dummy"        dummy
    .form field create t "Text"         text

    .form layout

    ttk::button .clear \
        -text "Clear" \
        -command ClearFields

    grid .form  -row 0 -column 0 -sticky ew  -pady 4 -padx 4
    grid .clear -row 1 -column 0 -sticky ew  -pady 4 -padx 4

    grid columnconfigure . 0 -weight 1
    

    bind . <Control-F12> {debugger new}
}

proc ChangeCmd {fields} {
    foreach field $fields {
        puts "$field is now: <[.form field get $field]>"
    }
}

proc ClearFields {} {
    foreach field [.form field names] {
        .form set $field ""
    }
}

#-------------------------------------------------------------------
# Invoke the program

main $argv








