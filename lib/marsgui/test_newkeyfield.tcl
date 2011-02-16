#-----------------------------------------------------------------------
# FILE: test_newkeyfield.tcl
#
#   newkeyfield(n) test script
#
# PACKAGE:
#   marsgui(n) -- Mars Forms Library
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

package require marsgui

namespace import marsutil::*
namespace import marsgui::*

#-----------------------------------------------------------------------
# Main

proc main {argv} {
    sqldocument db
    db open "./test.db"

    db eval {
        CREATE TEMPORARY VIEW nbgroups_universe AS
        SELECT n, g FROM nbhoods JOIN groups WHERE gtype = 'CIV';
    }

    ttk::label .lab -text "New NbGroup:"
    newkeyfield .key                 \
        -db        ::db              \
        -universe  nbgroups_universe \
        -table     nbgroups          \
        -keys      {n g}             \
        -widths    {8 8}             \
        -labels    {"In" "Grp"}      \
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









