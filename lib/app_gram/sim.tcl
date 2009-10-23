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

    typecomponent parmdb            ;# TBD
    typecomponent ram               ;# gram(n) 

    typecomponent nbhoods           ;# enum(n): all neighborhoods
    typecomponent pgroups           ;# enum(n): all pgroups
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
        
        # TBD: Delegate parm to GRAM's parmdb

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
        
        set pgroups  [enum %AUTO% [rdb eval {
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

    # sat adjust nbhood pgroup concern mag ?options?
    #
    # nbhood        The targeted neighborhood, or "*"
    # pgroup        The targeted pgroup, or "*"
    # concern       The affected concern, or "*"
    # mag           magnitude (qmag)
    #
    # -driver       Driver ID.  Defaults to next.
    #
    # Adjusts the specified satisfaction by the specified amount.
    # 
    # * pgroup and concern cannot both be *
    #
    # TBD: Improve error messages

    typemethod {sat adjust} {nbhood pgroup concern mag args} {
        require {$gramflag} "simulation uninitialized"

        if {$nbhood ne "*"} {
            set nbhood [$nbhoods validate $nbhood]
        }

        if {$pgroup ne "*"} {
            set pgroup [$pgroups validate $pgroup]
        }

        if {$concern ne "*"} {
            set concern [$concerns validate $concern]
        }

        if {$pgroup eq "*" && $concern eq "*"} {
            error "cannot wildcard both pgroup and concern"
        }

        # NEXT, get the Driver ID
        set driver [sim GetDriver args]

        if {[llength $args] > 0} {
            error "Unknown option: [lshift args]"
        }

        # Acquire the desired gram(n) object
        log normal sim "adjust driver=$driver n=$nbhood g=$pgroup c=$concern M=$mag"

        sim ValidateGC $pgroup $concern

        $ram sat adjust \
            $driver $nbhood $pgroup $concern $mag
    }

    # sat level zulutime nbhood pgroup concern limit days ?options?
    #
    # zulutime      Time the event occurs
    # nbhood        The targeted neighborhood, or "*"
    # pgroup        The targeted pgroup
    # concern       The affected concern
    # limit         Nominal magnitude (qmag)
    # days          Realization time in days (qduration)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 1
    #
    # Schedule a level input the specified time.

    typemethod {sat level} {zulutime nbhood pgroup concern limit days args} {
        require {$gramflag} "simulation uninitialized"

        if {$nbhood ne "*"} {
            set nbhood [$nbhoods validate $nbhood]
        }

        set pgroup  [$pgroups validate $pgroup]
        set concern [$concerns validate $concern]

        # Acquire the desired gram(n) object
        sim ValidateGC $pgroup $concern

        set ts [simclock fromZulu $zulutime]

        set driver [sim GetDriver args]

        eval $ram sat level \
            $driver $ts $nbhood $pgroup $concern $limit $days $args

        return
    }

    # sat slope zulutime pgroup concern slope limit ?options...?
    #
    # zulutime      Time the event occurs
    # nbhood        The targeted neighborhood, or "*"
    # pgroup        The targeted pgroup
    # concern       The affected concern
    # slope         change/day (qmag)
    # limit         maximum change, +/- (qmag)
    #
    # Options: 
    #     -driver driver Driver ID; defaults to next ID
    #     -p factor      "near" indirect effects multiplier, defaults to 0
    #     -q factor      "far" indirect effects multiplier, defaults to 1
    #
    # Schedule a slope input at the specified time.

    typemethod {sat slope} {zulutime nbhood pgroup concern slope limit args} {
        require {$gramflag} "simulation uninitialized"

        if {$nbhood ne "*"} {
            set nbhood [$nbhoods validate $nbhood]
        }

        set pgroup [$pgroups validate $pgroup]
        set concern [$concerns validate $concern]

        # Acquire the desired gram(n) object
        sim ValidateGC $pgroup $concern

        set ts [simclock fromZulu $zulutime]

        set driver [sim GetDriver args]

        eval $ram sat slope \
            $driver $ts $nbhood $pgroup $concern $slope $limit $args

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
        require {$gramflag} "simulation uninitialized"

        if {$n ne "*"} {
            set n [$nbhoods validate $n]
        }

        if {$f ne "*"} {
            set f [$pgroups validate $f]
        }

        if {$g ne "*"} {
            set g [$pgroups validate $g]
        }

        set driver [sim GetDriver args]

        if {[llength $args] > 0} {
            error "Unknown option: [lshift args]"
        }

        # Acquire the desired gram(n) object
        log normal sim "coop adjust driver=$driver n=$n f=$f g=$g M=$mag"

        $ram coop adjust $driver $n $f $g $mag
    }

    # coop level zulutime n f g limit days ?options?
    #
    # zulutime      Time the event occurs
    # n             The targeted neighborhood, or "*"
    # f             The targeted civilian group
    # g             The targeted force group
    # limit         Nominal magnitude (qmag)
    # days          Realization time in days (qduration)
    #
    # Options: 
    #     -driver driver  Driver ID; defaults to next ID
    #     -cause cause    Sets the cause for this input.
    #     -p factor       "near" indirect effects multiplier, defaults to 0
    #     -q factor       "far" indirect effects multiplier, defaults to 1
    #
    # Schedule a level input at the specified time.

    typemethod {coop level} {zulutime n f g limit days args} {
        require {$gramflag} "simulation uninitialized"

        if {$n ne "*"} {
            set n [$nbhoods validate $n]
        }

        set f [$pgroups validate $f]
        set g [$pgroups validate $g]


        set ts [simclock fromZulu $zulutime]

        set driver [sim GetDriver args]

        eval $ram coop level $driver $ts $n $f $g $limit $days $args

        return
    }

    # coop slope zulutime n f g slope limit ?options...?
    #
    # zulutime      Time the event occurs
    # n             The targeted neighborhood, or "*"
    # f             The targeted civilian group
    # g             The targeted force group
    # slope         change/day (qmag)
    # limit         maximum change, +/- (qmag)
    #
    # Options: 
    #     -driver driver Driver ID; defaults to next ID
    #     -p factor      "near" indirect effects multiplier, defaults to 0
    #     -q factor      "far" indirect effects multiplier, defaults to 1
    #
    # Schedule a slope input at the specified time.

    typemethod {coop slope} {zulutime n f g slope limit args} {
        require {$gramflag} "simulation uninitialized"

        if {$n ne "*"} {
            set n [$nbhoods validate $n]
        }

        set f [$pgroups validate $f]
        set g [$pgroups validate $g]

        set ts [simclock fromZulu $zulutime]

        set driver [sim GetDriver args]

        eval $ram coop slope $driver $ts $n $f $g $slope $limit $args

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

    delegate typemethod {parm set}   to parmdb
    delegate typemethod {parm get}   to parmdb
    delegate typemethod {parm list}  to parmdb
    delegate typemethod {parm names} to parmdb
    delegate typemethod {parm save}  to parmdb
    delegate typemethod {parm load}  to parmdb

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

    # ValidateGC g c
    #
    # g       A valid pgroup short name, or *
    # c       A valid concern short name, or *
    #
    # Verifies that g and c have the same type. "*" is allowed for 
    # either type, but not both.

    typemethod ValidateGC {g c} {
        if {$g eq "*"} {
            set c [$concerns name $c]

            set gtype [rdb concern $c type]
        } elseif {$c eq "*"} {
            set g [$pgroups name $g]

            set gtype [rdb pgroup $g type]
        } else {
            set g [$pgroups name $g]
            set c [$concerns name $c]

            set gtype [rdb grouptype $g $c]
        }
    }

    #-------------------------------------------------------------------
    # Utility Methods and Procs

    # GetDriver argvar
    #
    # Plucks -driver from an option/value list (if present).
    # If set, validates it; otherwise, generates a new Driver ID.
    # Returns the Driver ID.

    typemethod GetDriver {argvar} {
        upvar $argvar arglist

        set driver [from arglist -driver ""]

        if {$driver eq ""} {
            set driver [ram driver add]
        } else {
            ram driver validate $driver
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





