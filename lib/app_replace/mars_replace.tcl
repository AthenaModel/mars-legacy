#-----------------------------------------------------------------------
# TITLE:
#	mars_replace.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       JNEM: mars_replace(n) loader
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::mars_replace:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Provide the mars_replace(n) package

package provide app_replace 1.0

#-----------------------------------------------------------------------
# Require infrastructure packages

# Active Tcl
package require snit

# Mars Packages
package require marsutil

namespace import ::marsutil::*

#-----------------------------------------------------------------------
# Load mars_replace(n) submodules

source [file join $::mars_replace::library app.tcl]








