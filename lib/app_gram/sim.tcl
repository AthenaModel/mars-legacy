#-----------------------------------------------------------------------
# TITLE:
#    sim.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_gram(1) Simulation Manager object
#
#    The Simulation object loads the data from the gramdb(5) file, and
#    owns and manages the NSAT objects.
#
#-----------------------------------------------------------------------

snit::type sim {
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Type Components

    typecomponent ram               ;# gram(n) 

    #-------------------------------------------------------------------
    # Type Variables
    
    # Info Array
    #
    #    dbloaded      1 if a gramdb(5) has been loaded, and 0 otherwise
    #    dbfile        Name of the loaded gramdb(5), or ""
    
    typevariable info -array {
        dbloaded   0
        dbfile     ""
    }

    #-------------------------------------------------------------------
    # Initialization

    typemethod init {} {
        log normal sim "Initializing..."
        
        # Initialize the GRAM component to NullGram, so that
        # commands delegated to it are handled before it is
        # created.
        
        set ram [myproc NullGram]
    }

    #-------------------------------------------------------------------
    # Scenario Management

    # load dbfile
    #
    # Loads the gramdb(5) file and initializes the simulation.

    typemethod load {dbfile} {
        # FIRST, clean up the old simulation data.
        sim unload
        
        # NEXT, open a new log.
        log newlog load

        # NEXT, load the dbfile
        log normal sim "Loading gramdb $dbfile"
        gramdb loadfile $dbfile ::rdb
        set info(dbfile) $dbfile

        # NEXT, set the simulation clock
        simclock reset
        simclock configure \
            -t0   "100000ZJAN10"            \
            -tick [parmdb get sim.tickSize]

        # NEXT, create and initialize the GRAM.
        if {[catch {sim InitGram} result]} {
            # Save the stack trace while we clean up
            set errInfo $::errorInfo
            sim unload

            return -code error -errorinfo $errInfo $result
        }

        set info(dbloaded) 1
        log normal sim "Loaded gramdb $dbfile"

        notifier send ::sim <Reset>
        notifier send ::sim <Load>
        return
    }

    # reset
    #
    # Reinitializes the simulation
    
    typemethod reset {} {
        simclock reset
        simclock configure \
            -t0   "100000ZJAN10"            \
            -tick [parmdb get sim.tickSize]

        log newlog reset
        $ram init

        notifier send ::sim <Reset>
        return 
    }

    # InitGram
    #
    # Initializes the gram(n) objects.
    
    typemethod InitGram {} {
        set ram [gram ::ram \
                     -clock        ::simclock                       \
                     -rdb          ::rdb                            \
                     -logger       ::log                            \
                     -logcomponent gram                             \
                     -loadcmd      {::simlib::gramdb loader ::rdb}]
        $ram init
    }
    
    # unload
    #
    # Deletes the simulation objects to make way for new ones.
    typemethod unload {} {
        catch {$ram destroy}

        set ram [myproc NullGram]

        set info(dbloaded) 0
        set info(dbfile)   ""

        rdb clear
        rdb eval [readfile [file join $::app_gram::library gui_views.sql]]

        notifier send ::sim <Reset>
        notifier send ::sim <Unload>
    }
    
    #-------------------------------------------------------------------
    # Simulation Control

    # step ?ticks?
    #
    # Runs the simulation forward one timestep

    typemethod step {{ticks ""}} {
        if {$ticks eq ""} {
            set ticks [parmdb get sim.stepsize]
        }
        
        simclock step $ticks
        $ram advance

        notifier send ::sim <Time>
        return
    }

    # run zulutime
    #
    # Lets the simulation run until the specified zulu-time
    
    typemethod run {zulutime} {
        set endTime [simclock fromZulu $zulutime]
    
        if {$endTime <= [simclock now]} {
            error "Not in future: '$zulutime'"
        }

        while {[simclock now] <= $endTime} {
            simclock step $stepsize

            $ram advance
            notifier send ::sim <Time>
        }

        return
    }
    
    #-------------------------------------------------------------------
    # Queries
    
    # dbfile 
    #
    # Returns the name of the loaded gramdb(5) file, if any.

    typemethod dbfile {} {
        if {$info(dbloaded)} {
            return $info(dbfile)
        } else {
            return ""
        }
    }

    # dbloaded
    #
    # Returns 1 if GRAM is initialized with a database, and
    # 0 otherwise.
    
    typemethod dbloaded {} {
        return $info(dbloaded)
    }

    #-------------------------------------------------------------------
    # Time Conversion typemethods

    # now ?offset?
    #
    # offset    An offset in integer ticks; defaults to 0.
    #
    # Returns the current simulation time (plus the offset) 
    # as a Zulu-time string.  If the
    # simulation hasn't been initialized, returns "".

    typemethod now {{offset 0}} {
        # Do we have a scenario?
        if {$info(dbloaded)} {
            # Convert the simulation time to zulu-time.
            return [simclock asZulu $offset]
        } else {
            return ""
        }
    }

    #-------------------------------------------------------------------
    # GRAM Type Methods
    #
    # These are in this module, rather than executive, because they
    # depend on the "ram" component.
    
    # Delegated typemethods
    delegate typemethod {dump *} to ram  using {%c dump %m}

    # cancel driver
    #
    # Cancels the effects of a driver given its ID.

    typemethod cancel {driver {option ""}} {
        if {![$ram driver exists $driver]} {
            error "Unknown driver: \"$driver\""
        }
        
        if {$option ni {"" "-delete"}} {
            error "Unknown option: $option"
        }

        $ram cancel $driver $option
    }

    
    # coop adjust n f g mag ?options?
    #
    # n             The targeted neighborhood, or "*"
    # f             The targeted civ group, or "*"
    # g             The targeted frc group, or "*"
    # mag           magnitude (qmag)
    #
    # -driver       Driver ID.  Defaults to next ID.
    #
    # Adjusts the specified cooperation by the specified amount.

    typemethod {coop adjust} {n f g mag args} {
        set driver [sim GetDriver args]

        if {[llength $args] > 0} {
            error "Unknown option: [lshift args]"
        }

        $ram coop adjust $driver $n $f $g $mag
    }

    # coop level n f g limit days ?options?
    #
    # n             The targeted neighborhood, or "*"
    # f             The targeted civilian group
    # g             The targeted force group
    # limit         Nominal magnitude (qmag)
    # days          Realization time in days (qduration)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -cause cause    Sets the cause for this input.
    #     -s factor       "here" multiplier, defaults to 1
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 0
    #     -zulu zulu      Start time, as a zulu-time
    #     -tick ticks     Start time, in ticks
    #
    # Schedule a level input at the specified time, which defaults to now.

    typemethod {coop level} {n f g limit days args} {
        set driver [sim GetDriver args]
        set ts     [sim GetStartTime args]

        $ram coop level $driver $ts $n $f $g $limit $days {*}$args

        return
    }

    # coop slope n f g slope limit ?options...?
    #
    # n             The targeted neighborhood, or "*"
    # f             The targeted civilian group
    # g             The targeted force group
    # slope         change/day (qmag)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -s factor       "here" multiplier, defaults to 1
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 1
    #     -zulu zulu      Start time, as a zulu-time
    #     -tick ticks     Start time, in ticks
    #
    # Schedule a slope input at the specified time.

    typemethod {coop slope} {n f g slope args} {
        set driver [sim GetDriver args]
        set ts     [sim GetStartTime args]

        $ram coop slope $driver $ts $n $f $g $slope {*}$args

        return
    }

    # sat adjust n g c mag ?options?
    #
    # n        The targeted neighborhood, or "*"
    # g        The targeted group, or "*"
    # c        The affected concern, or "*"
    # mag      magnitude (qmag)
    #
    # -driver       Driver ID.  Defaults to next.
    #
    # Adjusts the specified satisfaction by the specified amount.

    typemethod {sat adjust} {n g c mag args} {
        # FIRST, get the Driver ID
        set driver [sim GetDriver args]

        if {[llength $args] > 0} {
            error "Unknown option: [lshift args]"
        }

        $ram sat adjust $driver $n $g $c $mag
    }

    # sat level n g c limit days ?options?
    #
    # g         The targeted group
    # c         The affected concern
    # limit     Nominal magnitude (qmag)
    # days      Realization time in days (qduration)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -s factor       "here" multiplier, defaults to 1
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 0
    #     -zulu zulu      Start time, as a zulu-time
    #     -tick ticks     Start time, in ticks
    #
    # Schedule a level input the specified time.

    typemethod {sat level} {n g c limit days args} {
        set driver [sim GetDriver args]
        set ts     [sim GetStartTime args]

        $ram sat level $driver $ts $n $g $c $limit $days {*}$args

        return
    }

    # sat slope n g c slope ?options...?
    #
    # n         The targeted neighborhood, or "*"
    # g         The targeted group
    # c         The affected concern
    # slope     change/day (qmag)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -s factor       "here" multiplier, defaults to 1
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 0
    #     -zulu zulu      Start time, as a zulu-time
    #     -tick ticks     Start time, in ticks
    #
    # Schedule a slope input at the specified time.

    typemethod {sat slope} {n g c slope args} {
        set driver [sim GetDriver args]
        set ts     [sim GetStartTime args]

        $ram sat slope $driver $ts $n $g $c $slope {*}$args

        return
    }

    # GetDriver argvar
    #
    # Plucks -driver from an option/value list (if present).
    # If set, validates it; otherwise, generates a new Driver ID.
    # Returns the Driver ID.

    typemethod GetDriver {argvar} {
        upvar $argvar arglist

        set driver [from arglist -driver ""]

        if {$driver eq ""} {
            set driver [$ram driver add]
        } else {
            $ram driver validate $driver
        }

        return $driver
    }
    
    # GetStartTime argvar
    #
    # argvar     Name of a variable containing an argument list
    #
    # Plucks the named options and their values from
    # the argument variable and validates them.
    #
    #   -zulu     A valid zulu-time
    #   -tick     A time in ticks
    #
    # If either option is given, returns the number of ticks.
    # Otherwise, returns [simclock now].

    typemethod GetStartTime {argvar} {
        upvar $argvar arglist

        set zulu [from arglist -zulu ""]

        if {$zulu ne ""} {
            set ts [simclock fromZulu $zulu]
        } else {
            set ts [from arglist -tick [simclock now]]
        }

        return $ts
    }


    # NullGram args....
    #
    # Handles typemethods delegated to a gram(n) object when there isn't one.
    
    proc NullGram {args} {
        error "simulation uninitialized"
    }


    #-------------------------------------------------------------------
    # Utility Methods and Procs

    # TBD
}





