#-----------------------------------------------------------------------
# TITLE:
#	app_log.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Mars: app_log(n) loader
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::app_log:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Provide the app_log(n) package

package provide app_log 1.0

#-----------------------------------------------------------------------
# Require infrastructure packages

# Active Tcl
package require snit

# Mars Packages
package require marsutil
package require marsgui

namespace import ::marsutil::*
namespace import ::marsgui::*

#-----------------------------------------------------------------------
# Load app_log(n) submodules

source [file join $::app_log::library app.tcl]










