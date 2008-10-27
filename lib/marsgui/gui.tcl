#-------------------------------------------------------------------------
# TITLE:
#       gui.tcl
#
# AUTHOR:
#       William H. Duquette
#
# DESCRIPTION:
#       JNEM gui(n) Package: Generic GUI Code
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Dependencies

package require snit     2.2
package require marsutil
   
package require Tk 8.5
package require BWidget  1.8
package require Img      1.3

#-----------------------------------------------------------------------
# Package Definition

package provide gui 1.0

#-----------------------------------------------------------------------
# Namespace and packages


namespace eval ::gui:: {
    variable library [file dirname [info script]]
}

source [file join $::gui::library global.tcl]
source [file join $::gui::library gradient.tcl]
source [file join $::gui::library cli.tcl]
source [file join $::gui::library cmdbrowser.tcl]
source [file join $::gui::library winbrowser.tcl]
source [file join $::gui::library debugger.tcl]
source [file join $::gui::library texteditor.tcl]
source [file join $::gui::library treenotebook.tcl]
source [file join $::gui::library zuluspinbox.tcl]
source [file join $::gui::library messageline.tcl]
source [file join $::gui::library filter.tcl]
source [file join $::gui::library finder.tcl]
source [file join $::gui::library logdisplay.tcl]
source [file join $::gui::library commandentry.tcl]
source [file join $::gui::library loglist.tcl]
source [file join $::gui::library matrixeditor.tcl]
source [file join $::gui::library subwin.tcl]
source [file join $::gui::library paner.tcl]
source [file join $::gui::library rotext.tcl]
source [file join $::gui::library datagrid.tcl]
source [file join $::gui::library parmseteditor.tcl]
source [file join $::gui::library scrollinglog.tcl]






