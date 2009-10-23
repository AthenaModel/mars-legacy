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

    typecomponent nbhoods           ;# enum(n): all neighborhoods
    typecomponent groups           ;# enum(n): all groups
    typecomponent concerns          ;# enum(n): all concerns

    #-------------------------------------------------------------------
    # Type Variables

    typevariable gramflag 0     ;# 1 if gram is initialized, and
                                 # 0 otherwise.
    typevariable stepsize 5     ;# Simulation step size in ticks
    typevariable filename       ;# Name of loaded database file.

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
    # Simulation Control

    # initialized
    #
    # Returns 1 if GRAM is initialized with a database, and
    # 0 otherwise.
    
    typemethod initialized {} {
        return $gramflag
    }

    # load dbfile
    #
    # Loads the gramdb(5) file and initializes the simulation.

    typemethod load {dbfile} {
        # FIRST, clean up the old simulation data.
        sim CleanUp
        
        # NEXT, open a new log.
        log newlog load

        # NEXT, load the dbfile
        log normal sim "Loading gramdb $dbfile"
        gramdb loadfile $dbfile ::rdb
        set filename $dbfile

        # NEXT, set the simulation clock
        simclock reset
        simclock configure -t0 "100000ZJAN10"

        # NEXT, remember the complete set of enumerations
        # TBD: See if we can get rid of these.
        set nbhoods  [enum %AUTO% [rdb eval {
            SELECT n,n FROM gramdb_n
        }]]
        
        set groups  [enum %AUTO% [rdb eval {
            SELECT g,g FROM gramdb_g
        }]]
        
        set concerns [enum %AUTO% [rdb eval {
            SELECT c,c FROM gramdb_c   
        }]]
       
        # NEXT, create and initialize the GRAM.
        if {[catch {sim InitGram} result]} {
            # Save the stack trace while we clean up
            set errInfo $::errorInfo
            sim CleanUp

            return -code error -errorinfo $errInfo $result
        }

        set gramflag 1
        log normal sim "Loaded gramdb $dbfile"

        notifier send ::sim <Reset>
        return
    }

    # dbfile 
    #
    # Returns the name of the loaded gramdb(5) file, if any.

    typemethod dbfile {} {
        if {$gramflag} {
            return $filename
        } else {
            return ""
        }
    }

    # reset
    #
    # Reinitializes the simulation
    
    typemethod reset {} {
        simclock reset
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
    
    # CleanUp
    #
    # Deletes the simulation objects to make way for new ones.
    typemethod CleanUp {} {
        array unset db
        catch {$ram destroy}

        set ram [myproc NullGram]

        set gramflag 0

        rdb clear
        notifier send ::sim <Reset>
    }

    # stepsize ?ticks?
    #
    # Gets/sets the simulation resolution in ticks

    typemethod stepsize {{ticks ""}} {
        if {$ticks ne ""} {
            if {![string is integer -strict $ticks] || $ticks < 1} {
                error "Invalid stepsize: '$ticks'; must be at least 1."
            }
            
            set stepsize $ticks
        }

        return $stepsize
    }

    # step
    #
    # Runs the simulation forward one timestep

    typemethod step {} {
        simclock step $stepsize
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

    # TBD: Move these to executive!
    
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

    # sat level zulu n g c limit days ?options?
    #
    # zulu      Time the event occurs
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
    #
    # Schedule a level input the specified time.

    typemethod {sat level} {zulu n g c limit days args} {
        set ts [simclock fromZulu $zulu]

        set driver [sim GetDriver args]

        $ram sat level $driver $ts $n $g $c $limit $days {*}$args

        return
    }

    # sat slope zulu n g c slope ?options...?
    #
    # zulu      Time the event occurs
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
    #
    # Schedule a slope input at the specified time.

    typemethod {sat slope} {zulu n g c slope args} {
        set ts [simclock fromZulu $zulu]

        set driver [sim GetDriver args]

        $ram sat slope $driver $ts $n $g $c $slope {*}$args

        return
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

    # coop level zulutime n f g limit days ?options?
    #
    # zulu          Time the event occurs
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
    #
    # Schedule a level input at the specified time.

    typemethod {coop level} {zulu n f g limit days args} {
        set ts [simclock fromZulu $zulu]

        set driver [sim GetDriver args]

        $ram coop level $driver $ts $n $f $g $limit $days {*}$args

        return
    }

    # coop slope zulu n f g slope limit ?options...?
    #
    # zulu          Time the event occurs
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
    #
    # Schedule a slope input at the specified time.

    typemethod {coop slope} {zulu n f g slope args} {
        set ts [simclock fromZulu $zulu]

        set driver [sim GetDriver args]

        $ram coop slope $driver $ts $n $f $g $slope {*}$args

        return
    }

    # cancel driver
    #
    # Cancels the effects of a driver given its ID.

    typemethod cancel {driver} {
        if {![rdb exists {
            SELECT driver FROM gram_driver
            WHERE object=$ram
            AND driver=$driver
        }]} {
            error "Unknown driver: \"$driver\""
        }

        ram cancel $driver
    }

    #-------------------------------------------------------------------
    # parmdb(5) typemethods

    delegate typemethod {parm set}   using {gram parm %m}
    delegate typemethod {parm get}   using {gram parm %m}
    delegate typemethod {parm list}  using {gram parm %m}
    delegate typemethod {parm names} using {gram parm %m}
    delegate typemethod {parm save}  using {gram parm %m}
    delegate typemethod {parm load}  using {gram parm %m}

    #-------------------------------------------------------------------
    # Time Conversion typemethods

    # Delegated typemethods
    delegate typemethod {dump *} to ram  using {%c dump %m}

    # now ?offset?
    #
    # offset    An offset in integer ticks; defaults to 0.
    #
    # Returns the current simulation time (plus the offset) 
    # as a Zulu-time string.  If the
    # simulation hasn't been initialized, returns "".

    typemethod now {{offset 0}} {
        # Are we initialized?
        if {$gramflag} {
            # Convert the simulation time to zulu-time.
            return [simclock asZulu $offset]
        } else {
            return ""
        }
    }


    #-------------------------------------------------------------------
    # Utility Methods and Procs

    # ValidateGC g c
    #
    # g       A valid group short name, or *
    # c       A valid concern short name, or *
    #
    # Verifies that g and c have the same type. "*" is allowed for 
    # either type, but not both.

    typemethod ValidateGC {g c} {
        if {$g eq "*"} {
            set c [$concerns name $c]

            set gtype [rdb concern $c type]
        } elseif {$c eq "*"} {
            set g [$groups name $g]

            set gtype [rdb group $g type]
        } else {
            set g [$groups name $g]
            set c [$concerns name $c]

            set gtype [rdb grouptype $g $c]
        }
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

    # NullGram args....
    #
    # Handles typemethods delegated to a gram(n) object when there isn't one.
    
    proc NullGram {args} {
        error "simulation uninitialized"
    }
}





