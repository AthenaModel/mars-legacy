#-----------------------------------------------------------------------
# TITLE:
#    paxutil.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Paxsim: paxutil(n) Tcl Utilities
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Dependencies

package require snit    2.2
package require sqlite3 3.5
package require comm

#-----------------------------------------------------------------------
# Package Definition

package provide paxutil 1.0

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::paxutil:: {
    variable library [file dirname [info script]]
}

#-------------------------------------------------------------------
# Load binary extensions, if present.

set binlib [file join $::paxutil::library libPaxutil.so]

if {[file exists $binlib]} {
    load $binlib
}

#-----------------------------------------------------------------------
# Submodules
#
# Note: modules are listed in order of dependencies; be careful if you
# change the order!

source [file join $::paxutil::library template.tcl     ]
