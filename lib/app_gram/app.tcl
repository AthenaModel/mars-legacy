#-----------------------------------------------------------------------
# FILE: app.tcl
#
# Main Application Module
#
# PACKAGE:
#   app_gram(n) -- mars_gram(1) implementation library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: app
#
# This module defines app, the application ensemble.  app encapsulates 
# all of the functionality of the mars_gram(1)  main window, 
# including the application's start-up behavior.  To invoke the 
# application,
#
# > package require app_gram
# > app init $argv

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Components

    typecomponent cli               ;# The executive shell
    typecomponent msgline           ;# The application message line.
    typecomponent rdb               ;# The runtime database, for nsat(n)
                                     # inputs.
                                     
    #-------------------------------------------------------------------
    # Type Variables
    
    # Typevariable: info
    #
    # Information array; the keys are as follows.
    #
    #   ticks - Time now, in ticks
    #   zulu  - Time now, in zulu time
    
    typevariable info -array {
        ticks 0000
        zulu  ""
    }

    #===================================================================
    # Group: Application Initialization

    # Typemethod: init
    #
    # Initializes the application.
    #
    # Parameters:
    # argv - Command line arguments

    typemethod init {argv} {
        # FIRST, handle the command line.
        set gramdbFile  ""
        set initScript ""

        while {[string match "-*" [lindex $argv 0]]} {
            set opt [lshift argv]

            switch -exact -- $opt {
                -help {
                    app usage
                    exit 0
                }
                -script {
                    set initScript [lshift argv]
                }
                default {
                    puts "Unknown option: $opt"
                    app usage
                    exit 1
                }
            }
        }

        if {[llength $argv] == 1} {
            set gramdbFile [lindex $argv 0]
        } elseif {[llength $argv] != 0} {
            app usage
            exit 1
        }
        
        # NEXT, allow the developer to pop up the debugger window
        # no matter what window they are in.
        bind all <Control-F12> [list debugger new]

        # NEXT, initialize the application.
        app CreateLogger               ;# Creates ::log, allowing logging
        app CreateRdb                  ;# Creates ::rdb.
        executive init                 ;# Initialize the command executive
        parmdb init                    ;# Initialize the parameter database
        sim init                       ;# Initialize the simulation manager

        # NEXT, define global conditions
        namespace eval ::cond {
            statecontroller dbloaded -events {
                ::app <Init>
                ::sim <Reset>
            } -condition {
                [::sim dbloaded]
            }
        }
        
        # NEXT, Withdraw the default toplevel window, and create 
        # the main GUI window
        wm withdraw .
        appwin .main -main yes

        # NEXT, prepare to receive simulation events
        notifier trace [myproc NotifierTrace]

        # NEXT, load the database, if any.
        if {$gramdbFile ne ""} {
            executive evalsafe [list load $gramdbFile]
        } else {
            notifier send ::app <Init>
        }

        # NEXT, run the initial script, if any.
        if {$initScript ne ""} {
            executive evalsafe [list call $initScript]
        }

        app puts "Welcome to GRAM Workbench!"
    }

    # Typemethod: CreateLogger
    #
    # Creates the logger, ::log, for this application

    typemethod CreateLogger {} {
        set logdir [file normalize [file join . log mars_gram]]
        
        file mkdir $logdir
        
        logger ::log \
            -simclock ::simclock                              \
            -logdir    $logdir                                \
            -newlogcmd [list notifier send $type <AppLogNew>]

        log normal app "mars_gram(1)"
    }

    # Typemethod: CreateRdb
    #
    # Creates and initializes the rdb as an in-memory database.

    typemethod CreateRdb {} {
        set rdb [sqldocument ::rdb -clock ::simclock]
        rdb register ::simlib::gramdb
        rdb register ::simlib::gram
        rdb open :memory:
        rdb clear
    }

    #-------------------------------------------------------------------
    # Group: Event Handlers
    
    # Proc: NotifierTrace
    #
    # A notifier(n) trace command; it simply logs all notifier events.

    proc NotifierTrace {subject event eargs objects} {
        set objects [join $objects ", "]
        log detail notify "send $subject $event [list $eargs] to $objects"
    }
    
    #-------------------------------------------------------------------
    # Group: Public Type Methods
    
    # Typemethod: usage
    #
    # Display command line syntax.

    typemethod usage {} {
        puts {Usage: mars gram [options...] [file.gramdb]}
        puts ""
        puts "    -script script.tcl     Execute the named script file."
        puts "    -help                  Display this text."
        puts ""
        puts "See mars_gram(1) for more information."
    }

    # Typemethod: puts
    #
    # Writes the text to the message line of the topmost appwin.
    #
    # Parameters:
    #   text - A text string

    typemethod puts {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            $topwin puts $text
        }
    }

    # Typemethod: error
    #
    # Displays the error in a message box
    #
    # Parameters:
    #   text - A tsubst'd text string

    typemethod error {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            uplevel 1 [list [app topwin] error $text]
        } else {
            error $text
        }
    }

    # Typemethod: exit 
    #
    # Exits the program
    #
    # Parameters:
    #   ?text? - Optional error message, tsubst'd

    typemethod exit {{text ""}} {
        # FIRST, output the text.
        if {$text ne ""} {
            puts [uplevel 1 [list tsubst $text]]
        }

        # NEXT, save preferences and parameters.
        .main savehistory
        parmdb save
    
        # NEXT, exit
        exit
    }

    # Typemethod: topwin
    #
    # Provides access to the topmost <appwin>.
    #
    # If there's no subcommand, returns the name of the topmost appwin.
    # Otherwise, delegates the subcommand to the top win.  If there is
    # no top win, this is a noop.
    #
    # Parameters:
    #   ?subcommand...? - A subcommand of the topwin, as one argument
    #                     or many

    typemethod topwin {args} {
        # FIRST, determine the topwin
        set topwin ""

        foreach w [lreverse [wm stackorder .]] {
            if {[winfo class $w] eq "Appwin"} {
                set topwin $w
                break
            }
        }

        if {[llength $args] == 0} {
            return $topwin
        } elseif {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        return [$topwin {*}$args]
    }
}

#-------------------------------------------------------------------
# Section: Miscellaneous Commands

# proc: bgerror 
#
# Customized bgerror handler; Logs background error messages.
#
# Parameters:
# message - An error message

proc bgerror {message} {
    global errorInfo
    global bgErrorInfo

    set bgErrorInfo $errorInfo

    log error app "bgerror: $message"
}








