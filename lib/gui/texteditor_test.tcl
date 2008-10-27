#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.4 "$0" "$@"

package require Tk 8.4
package require gui

wm title . "Test"

label .lab \
    -font {Helvetica 40} \
    -text "texteditor test"

pack .lab

if {[llength $argv] == 0} {
    ::gui::texteditor .%AUTO% -title "Test Editor"
} else {
    set win [::gui::texteditor .%AUTO% -title "Test Editor"]

    $win open [lindex $argv 0]
}



