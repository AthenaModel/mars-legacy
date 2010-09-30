#-----------------------------------------------------------------------
# FILE: test_keyfield.tcl
#
#   keyfield(n) test script
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
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require marsutil
package require marsgui
package require formlib

namespace import marsutil::*
namespace import marsgui::*
namespace import formlib::*

#-----------------------------------------------------------------------
# Main

proc main {argv} {
    sqldocument db
    db open "./test.db"

    ttk::label .lab -text "Curve:"
    keyfield .key             \
        -db        ::db       \
        -table     sat_ngc   \
        -keys      {n g c}    \
        -widths    {6 6 4}    \
        -changecmd GotChanges

    grid .lab -row 0 -column 0 -sticky w   -pady 4 -padx 4
    grid .key -row 0 -column 1 -sticky ew  -pady 4 -padx 4
    grid columnconfigure . 1 -weight 1

    bind . <Control-F12> {debugger new}
}

proc GotChanges {value} {
    puts "Key changed: <$value>"
}

#-------------------------------------------------------------------
# Invoke the program

main $argv








