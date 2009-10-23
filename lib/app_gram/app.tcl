#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_gram(1) Main Application Window
#
#    This module defines app, the application ensemble.  app encapsulates 
#    all of the functionality of the mars_gram(1)  main window, 
#    including the application's start-up behavior.  To invoke the 
#    application,
#
#        package require app_gram
#        app init $argv
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app ensemble

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
    
    # info array
    #
    #    ticks      Time now, in ticks
    #    zulu       Time now, in zulu time
    
    typevariable info -array {
        ticks 0000
        zulu  ""
    }

    #===================================================================
    # Application Initialization

    # init argv
    #
    # argv         Command line arguments
    #
    # Initializes the application.

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
        sim init                       ;# Initialize the simulation manager

        # NEXT, Withdraw the default toplevel window, and create 
        # the main GUI window
        wm withdraw .
        appwin .main -main yes

        # NEXT, prepare to receive simulation events
        notifier trace [myproc NotifierTrace]

        # NEXT, load the database, if any.
        if {$gramdbFile ne ""} {
            executive evalsafe [list load $gramdbFile]
        }

        # NEXT, run the initial script, if any.
        if {$initScript ne ""} {
            executive evalsafe [list call $initScript]
        }

        app puts "Welcome to GRAM Workbench!"
    }
    
    # NotifierTrace subject event eargs objects
    #
    # A notifier(n) trace command

    proc NotifierTrace {subject event eargs objects} {
        set objects [join $objects ", "]
        log detail notify "send $subject $event [list $eargs] to $objects"
    }
    
    # usage
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

    # CreateLogger
    #
    # Creates the logger, ::log, for this application

    typemethod CreateLogger {} {
        set logdir [file normalize [file join . log app_gram]]
        
        file mkdir $logdir
        
        logger ::log \
            -simclock ::simclock                              \
            -logdir    $logdir                                \
            -newlogcmd [list notifier send $type <AppLogNew>]

        log normal app "mars_gram(1)"
    }

    # CreateRdb
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
    # Public Typemethods

    # puts text
    #
    # text     A text string
    #
    # Writes the text to the message line of the topmost appwin.

    typemethod puts {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            $topwin puts $text
        }
    }

    # error text
    #
    # text       A tsubst'd text string
    #
    # Displays the error in a message box

    typemethod error {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            uplevel 1 [list [app topwin] error $text]
        } else {
            error $text
        }
    }

    # exit ?text?
    #
    # Optional error message, tsubst'd
    #
    # Exits the program

    typemethod exit {{text ""}} {
        # FIRST, output the text.
        if {$text ne ""} {
            puts [uplevel 1 [list tsubst $text]]
        }

        # NEXT, save the CLI history, if any.
        .main savehistory
    
        # NEXT, exit
        exit
    }

    # topwin ?subcommand...?
    #
    # subcommand    A subcommand of the topwin, as one argument or many
    #
    # If there's no subcommand, returns the name of the topmost appwin.
    # Otherwise, delegates the subcommand to the top win.  If there is
    # no top win, this is a noop.

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
    
    #---------------------------------------------------------------
    # Obsolete code
    #
    # These routines are obsolete, but are left here as a memory
    # jog until I decide what to do with these capabilities.
    
    # CreateMenuBar
    #
    # Creates the application menu bar and its menus.

    typemethod CreateMenuBar {} {
        # Menu Bar
        set menu [menu .menubar -relief flat]
        . configure -menu $menu
        
        # File Menu
        set filemenu [menu $menu.file]
        $menu add cascade -label "File" -underline 0 -menu $filemenu

        $filemenu add command \
            -label "New Script..." \
            -underline 5 \
            -accelerator "Ctrl+N" \
            -command [mytypemethod NewScript]
        bind . <Control-N> [mytypemethod NewScript]

        $filemenu add command \
            -label "Open gramdb(5) File..." \
            -underline 0 \
            -accelerator "Ctrl+O" \
            -command [mytypemethod OpenDatabase]
        bind . <Control-o> [mytypemethod OpenDatabase]

        $filemenu add command \
            -label "Open Script..." \
            -underline 5 \
            -accelerator "Ctrl+Shift+O" \
            -command [mytypemethod OpenScript]
        bind . <Control-O> [mytypemethod OpenScript]

    }

    # NewScript
    #
    # Opens a text editor on a new script; returns the text editor's
    # window.

    typemethod NewScript {} {
        texteditor .%AUTO% \
            -title "GRAM Workbench Script Editor" \
            -initialdir [pwd] \
            -filetypes {
                {{GRAM Script} {.tcl}}
                {{All Files} {*}}
            }
    }

    # OpenDatabase
    #
    # Opens a text editor on a gramdb file.
    # window.
    
    typemethod OpenDatabase {} {
        set win [texteditor .%AUTO% \
                     -title "GRAM Workbench gramdb(5) Editor" \
                     -initialdir [pwd] \
                     -filetypes {
                         {gramdb(5) {.gramdb}}
                         {{All Files} {*}}
                     }]

        $win open
    }

    # OpenScript
    #
    # Opens a text editor and prompts the user to select a script.
    
    typemethod OpenScript {} {
        [app NewScript] open
    }

}

#-------------------------------------------------------------------
# Handle bgerrors

# bgerror message
#
# message         An error message
#
# Logs background error messages

proc bgerror {message} {
    global errorInfo
    global bgErrorInfo

    set bgErrorInfo $errorInfo

    log error app "bgerror: $message"
}








