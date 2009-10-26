#-----------------------------------------------------------------------
# TITLE:
#    parmdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_gram(1) model parameter database
#
#    The module delegates most of its function to parmset(n).
#
#-----------------------------------------------------------------------

snit::integer ticks -min 1

#-----------------------------------------------------------------------
# parmdb

snit::type parmdb {
    # Make it a singleton
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Typecomponents

    typecomponent ps ;# The parmset(n) object

    #-------------------------------------------------------------------
    # Type Variables

    # Name of the defaults file; set by init
    typevariable defaultsFile

    #-------------------------------------------------------------------
    # Public typemethods

    delegate typemethod * to ps

    # init
    #
    # Initializes the module

    typemethod init {} {
        # Don't initialize twice.
        if {$ps ne ""} {
            return
        }

        # FIRST, set the defaults file name
        set defaultsFile [file join ~ .mars_gram defaults.parmdb]

        # NEXT, create the parmset.
        set ps [parmset %AUTO%]

        # NEXT, define the "sim" parameters

        $ps subset sim {
            Parameters which affect the behavior of the simulation in
            general.
        }

        $ps define sim.tickSize ::marsutil::ticktype {5 minutes} {
            Defines the size of the simulation time tick, i.e., the 
            resolution of the simulation clock.  The time tick can be 
            (within reason) any positive number of minutes, hours, or days, 
            expressed as "<i>number</i> <i>units</i>", e.g., 
            "1 minute", "2 minutes", 
            "1 hour", "2 hours", "1 day", "2 days"; however, the Athena
            models are designed for a tick size of approximately one
            day.<p>  

            This parameter takes effect when on "load" and "reset".
        }
        
        $ps define sim.stepSize ::ticks 5 {
            Defines the default step size, in ticks.
        }

        # NEXT, define gram parameters
        $ps slave add [list ::simlib::gram parm]

        # NEXT, define rmf parameters
        $ps slave add [list ::simlib::rmf parm]
        
        # NEXT, load default parameters
        $type load
    }

    # save
    #
    # Saves the current parameters as the default for future
    # scenarios, by saving ~/.mars_gram/defaults.parmdb.

    typemethod save {} {
        file mkdir [file join ~ .mars_gram]
        $ps save $defaultsFile
        return
    }

    # reset
    #
    # Clears the saved defaults by deleting ~/.mars_gram/defaults.parmdb.

    typemethod reset {} {
        if {[file exists $defaultsFile]} {
            file delete $defaultsFile
        }
        
        $ps reset
        return "Parameters reset to default values."
    }

    # load
    #
    # Loads the parameters from the defaults file, if any.  Otherwise,
    # the parameters are reset to the normal defaults.

    typemethod load {} {
        if {[file exists $defaultsFile]} {
            $ps load $defaultsFile -safe
        } else {
            $ps reset
        }

        return
    }
}



