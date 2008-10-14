#-----------------------------------------------------------------------
# TITLE:
#	app_import.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       JNEM: app_import(n) loader
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::app_import:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Provide the app_import(n) package

package provide app_import 1.0

#-----------------------------------------------------------------------
# Require infrastructure packages

# From Tcllib
package require snit

# Mars Packages
package require marsutil

namespace import ::marsutil::*

#-----------------------------------------------------------------------
# Load app_import(n) submodules

source [file join $::app_import::library app.tcl   ]

