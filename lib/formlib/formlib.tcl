#-------------------------------------------------------------------------
# TITLE:
#       formlib.tcl
#
# AUTHOR:
#       William H. Duquette
#
# DESCRIPTION:
#       Mars formlib(n) Package: Data entry forms
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Dependencies

package require snit     2.2
package require marsutil
package require marsgui

#-----------------------------------------------------------------------
# Package Definition

package provide formlib 1.0

#-----------------------------------------------------------------------
# Namespace and packages


namespace eval ::formlib:: {
    variable library [file dirname [info script]]
    
    # Make marsutil calls visible in formlib
    namespace import ::marsutil::*
}

source [file join $::formlib::library dispfield.tcl         ]
source [file join $::formlib::library enumfield.tcl         ]
source [file join $::formlib::library keyfield.tcl          ]
source [file join $::formlib::library newkeyfield.tcl       ]
source [file join $::formlib::library textfield.tcl         ]
source [file join $::formlib::library form.tcl              ]


