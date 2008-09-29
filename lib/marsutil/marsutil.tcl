#-----------------------------------------------------------------------
# TITLE:
#    marsutil.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars: marsutil(n) Tcl Utilities
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Dependencies

package require snit    2.2
package require sqlite3 3.5
package require comm

#-----------------------------------------------------------------------
# Package Definition

package provide marsutil 1.0

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::marsutil:: {
    variable library [file dirname [info script]]
}

#-------------------------------------------------------------------
# Load binary extensions, if present.

set binlib [file join $::marsutil::library libPaxutil.so]

if {[file exists $binlib]} {
    load $binlib
}

#-----------------------------------------------------------------------
# Submodules
#
# Note: modules are listed in order of dependencies; be careful if you
# change the order!

source [file join $::marsutil::library template.tcl     ]


