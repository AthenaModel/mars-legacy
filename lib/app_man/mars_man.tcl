#-----------------------------------------------------------------------
# TITLE:
#	mars_man.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       JNEM: mars_man(n) loader
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::mars_man:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Provide the mars_man(n) package

package provide app_man 1.0

#-----------------------------------------------------------------------
# Require infrastructure packages

# From Tcllib
package require textutil::expander
package require snit

# Mars Packages
package require marsutil

namespace import ::marsutil::*

#-----------------------------------------------------------------------
# Load mars_man(n) submodules

source [file join $::mars_man::library app.tcl  ]








