#-----------------------------------------------------------------------
# TITLE:
#    executive.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_gram(1): Executive Command Processor
#
#    The Executive is the program's command processor.  It's a singleton, 
#    implemented as an instance of the executiveType so that it can have
#    options if need be.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# executive

snit::type executive {
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Type Components

    typecomponent interp    ;# Interpreter used for processing commands.

    #-------------------------------------------------------------------
    # Type Variables

    typevariable stackTrace {}   ;# Traceback for last error.

    #-------------------------------------------------------------------
    # Initialization
    
    typemethod init {} {
        log normal exec "Initializing..."

        # FIRST, create the interpreter.  It's a safe interpreter but
        # most Tcl commands are retained, to allow scripting.  Allow
        # the "source" command.
        set interp [smartinterp ${type}::interp -cli yes]
        $interp expose source
        $interp expose file

        # NEXT, add commands that need to be defined in the slave itself.
        $interp proc call {script} {
            if {[file extension $script] eq ""} {
                append script ".tcl"
            }
            uplevel 1 [list source $script]
        }
        
        $interp proc select {args} {
            set query "SELECT $args"
            
            return [rdb query $query]
        }



        # NEXT, install the executive commands

        # =
        $interp smartalias = 1 - {expression...} \
            ::expr


        # bgerrtrace
        $interp smartalias bgerrtrace 0 0 {} \
            [mytypemethod bgerrtrace]

        # cancel
        $interp smartalias cancel 1 1 {driver} \
            [list ::sim cancel]

        # coop
        $interp ensemble coop

        # coop adjust
        $interp smartalias {coop adjust} 4 - \
            {n f g mag ?options...?} \
            [list ::sim coop adjust]

        # coop level
        $interp smartalias {coop level} 6 - \
            {zulutime n f g limit days ?option value...?} \
            [list ::sim coop level]

        # coop slope
        $interp smartalias {coop slope} 6 - \
            {zulutime n f g slope limit ?option value...?} \
            [list ::sim coop slope]

        # debug
        $interp smartalias debug 0 0 {} \
            [list ::marsgui::debugger new]

        # dump
        $interp ensemble dump

        # dump coop.nfg
        $interp smartalias {dump coop.nfg} 0 - {?options...?} \
            [list ::sim dump coop.nfg]

        # dump coop
        $interp ensemble {dump coop}

        # dump coop levels
        $interp smartalias {dump coop levels} 0 1 {?driver?} \
            [list ::sim dump coop levels]

        # dump coop level
        # TBD: need to uppercase n,f,g
        $interp smartalias {dump coop level} 3 3 {n f g} \
            [list ::sim dump coop level]

        # dump coop slopes
        $interp smartalias {dump coop slopes} 0 1 {?inputId?} \
            [list ::sim dump coop slopes]

        # dump coop slope
        # TBD: need to uppercase n,f,g
        $interp smartalias {dump coop slope} 3 3 {n f g} \
            [list ::sim dump coop slope]

        # dump sat
        $interp ensemble {dump sat}

        # dump sat levels
        $interp smartalias {dump sat levels} 0 1 {?driver?} \
            [list ::sim dump sat levels]

        # dump sat level
        # TBD: need to uppercase n,g,c
        $interp smartalias {dump sat level} 3 3 {n g c} \
            [list ::sim dump sat level]

        # dump sat slopes
        $interp smartalias {dump sat slopes} 0 1 {?inputId?} \
            [list ::sim dump sat slopes]

        # dump sat slope
        # TBD: need to uppercase n,g,c
        $interp smartalias {dump sat slope} 3 3 {n g c} \
            [list ::sim dump sat slope]

        # dump sat.ngc
        $interp smartalias {dump sat.ngc} 0 - {?options...?} \
            [list ::sim dump sat.ngc]

        # errtrace
        $interp smartalias errtrace 0 0 {} \
            [mytypemethod errtrace]

        # help
        $interp smartalias help 1 - {?-info? command...} \
            [mytypemethod help]

        # load
        $interp smartalias load 1 1 {dbfile} \
            [list ::sim load]

        # log
        $interp smartalias log 1 1 {text} \
            [list ::log normal user]

        # now
        $interp smartalias now 0 1 {?offset?} \
            [list ::sim now]

        # parm
        $interp ensemble parm

        # parm get
        $interp smartalias {parm get} 1 1 {parm} \
            [list ::sim parm get]

        # parm set
        $interp smartalias {parm set} 2 2 {parm value} \
            [list ::sim parm set]

        # parm names
        $interp smartalias {parm names} 0 1 {?pattern?} \
            [list ::sim parm names]

        # parm list
        $interp smartalias {parm list} 0 1 {?pattern?} \
            [list ::sim parm list]

        # parm save
        $interp smartalias {parm save} 1 1 {filename} \
            [list ::sim parm save]

        # parm load
        $interp smartalias {parm load} 1 1 {filename} \
            [list ::sim parm load]

        # rdb
        $interp ensemble rdb

        # rdb eval
        $interp smartalias {rdb eval}  1 1 {sql} \
            [list ::rdb eval]

        # rdb query
        $interp smartalias {rdb query} 1 1 {sql} \
            [list ::rdb query]

        # rdb schema
        $interp smartalias {rdb schema} 0 1 {?table?} \
            [list ::rdb schema]

        # rdb tables
        $interp smartalias {rdb tables} 0 0 {} \
            [list ::rdb tables]

        # reset
        $interp smartalias reset 0 0 {} \
            [list ::sim reset]
        
        # run
        $interp smartalias run 1 1 {zulutime} \
            [list ::sim run]

        # sat
        $interp ensemble sat

        # sat adjust
        $interp smartalias {sat adjust} 4 - \
            {nbhood pgroup concern mag ?options...?} \
            [list ::sim sat adjust]

        # sat level
        $interp smartalias {sat level} 6 - \
            {zulutime nbhood pgroup concern limit days ?option value...?} \
            [list ::sim sat level]

        # sat slope
        $interp smartalias {sat slope} 6 - \
            {zulutime nbhood pgroup concern slope limit ?option value...?} \
            [list ::sim sat slope]

        # step
        $interp smartalias step 0 0 {} \
            [list ::sim step]

        # stepsize
        $interp smartalias stepsize 0 1 {?ticks?} \
            [list ::sim stepsize]
    }

    #-------------------------------------------------------------------
    # Public type methods

    # help ?-info? command...
    #
    # Outputs the help for the command 

    typemethod help {args} {
        set getInfo 0

        if {[lindex $args 0] eq "-info"} {
            set getInfo 1
            set args [lrange $args 1 end]
        }

        set out [$interp help $args]

        if {$getInfo} {
            append out "\n\n[$interp cmdinfo $args]"
        }

        return $out
    }

    # eval script
    #
    # Evaluate the script; throw an error or return the script's value.
    # Either way, log what happens. Ignore empty scripts.

    typemethod eval {script} {
        if {[string trim $script] eq ""} {
            return
        }

        log normal exec "Command: $script"

        # Make sure the command displays in the log before it
        # executes.
        update idletasks

        if {[catch {$interp eval $script} result]} {
            set stackTrace $::errorInfo
            log warning exec "Command error: $result"
            return -code error $result
        }

        return $result
    }

    # evalsafe script
    #
    # Like eval, but swallows the return value or error (since
    # it's logged anyway).

    typemethod evalsafe {script} {
        catch {$type eval $script}
    }

    # commands
    #
    # Returns a list of the commands defined in the Executive's 
    # interpreter

    typemethod commands {} {
        $interp eval {info commands}
    }

    # errtrace
    #
    # returns the stack trace from the most recent evaluation error.

    typemethod errtrace {} {
        return $stackTrace
    }

    # bgerrtrace
    #
    # Returns the stack trace from the most recent bgerror

    typemethod bgerrtrace {} {
        global bgErrorInfo

        return $bgErrorInfo
    }
}




