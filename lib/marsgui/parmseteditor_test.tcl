#!/bin/sh
# -*-tcl-*-
# The next line restarts using wish \
exec wish "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    parmseteditor_test.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Exercises the parmseteditor(n) widget.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

package require marsutil
package require gui
package require tile
package require treectrl

source parmseteditor.tcl

namespace import ::marsutil::* gui::*

#-------------------------------------------------------------------
# Data Types

snit::integer  spawnTime -min -1
snit::enum     absitName -values {BADFOOD BADWATER DISEASE SEWAGE}
snit::listtype absitList -type absitName
snit::integer  minutes   -min 0

#-------------------------------------------------------------------
# Main Routine

# main argv
#
# argv     The program's argument list
#
# Creates the GUI and initializes the application.

proc main {argv} {
    # FIRST, create a parmset and add some parameters.
    parmset ps

    ps subset absit {
        Abstract situation parameters, by absit type.
    }

    ps define absit.deleteAfterMinutes minutes 10 {
        How long SITUATION.ABSTRACT objects persist in the federation
        after the situation is resolved or cancelled.
    }

    foreach name {BADFOOD BADWATER SEWAGE} {
        ps subset absit.$name "
            Parameters for abstract situation type $name.
        "
        ps define absit.$name.spawnTime spawnTime -1 {
            How long until the absit spawns other absits, in minutes.  If
            -1, the absit never spawns.
        }

        ps define absit.$name.spawns absitList {} {
            List of absit types spawned by this absit type.
        }

        ps subset absit.$name.mitigatedby {
            Factors which can mitigate the effects of this abstract
            situation type.
        }

        ps define absit.$name.mitigatedby.MEDICAL ::snit::boolean no {
            Whether or not the absit can be mitigated by ORG service of
            type MEDICAL.
        }

        ps define absit.$name.mitigatedby.SUPPORT ::snit::boolean no {
            Whether or not the absit can be mitigated by ORG service of
            type SUPPORT.
        }

        ps define absit.$name.mitigatedby.ENGINEER ::snit::boolean no {
            Whether or not the absit can be mitigated by ORG service of
            type ENGINEER.
        }
    }   

    ps subset jin {
        Parameters used by JIN, and particularly by JIN
        rule sets.
    }

    ps subset jin.CA {
        Parameters for the CA rule set
    }

    ps define jin.CA.dist ::marsutil::distance 3 {
        Distance from the CA unit, in kilometers.
    }

    ps define jin.CA.size1 ::marsutil::count 6 {
        Cutoff between small and medium-sized CA units, in personnel.
    }

    ps define jin.CA.size2 ::marsutil::count 21 {
        Cutoff between medium and large CA units, in personnel.
    }

    ps subset jin.CIVCAS {
        Parameters for the CIVCAS rule set
    }

    ps define jin.CIVCAS.limit1 ::marsutil::count 6 {
        A small number of non-hostile civilian casualties.
    }

    ps define jin.CIVCAS.limit2 ::marsutil::count 20 {
        A large number of non-hostile civilian casualties.
    }

    ps define jin.CIVCAS.limit3 ::marsutil::count 10 {
        A number of hostile civilian casualties.
    }

    # NEXT, change some default values.
    ps set absit.BADFOOD.mitigatedby.ENGINEER  yes
    ps set absit.BADFOOD.mitigatedby.SUPPORT   yes
    ps set absit.BADFOOD.spawns                DISEASE
    ps set absit.BADFOOD.spawnTime             1440
    ps set absit.BADWATER.mitigatedby.ENGINEER yes
    ps set absit.BADWATER.mitigatedby.SUPPORT  yes
    ps set absit.BADWATER.spawns               DISEASE
    ps set absit.BADWATER.spawnTime            720
 
    # NEXT, pick the Tile theme.
    style theme use alt

    # NEXT, create a treectrl containing a tree defined by the
    # implicit parmset hierarchy.
    parmseteditor .editor -parmset ::ps -msgcmd puts

    pack .editor -fill both -expand yes

    bind . <F9> [list debugger new]

    raise .editor
}



#-----------------------------------------------------------------------
# Main line code

main $argv




