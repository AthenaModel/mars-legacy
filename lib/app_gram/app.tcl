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
    # Application Initializer

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

        # NEXT, set the window title.
        wm title . "GRAM Workbench"

        # NEXT, when the main window is destroyed, exit.
        wm protocol . WM_DELETE_WINDOW [list app exit]

        # NEXT, allow the developer to pop up the debugger window.
        bind . <Control-F12> [list debugger new]

        # NEXT, initialize the application.
        app CreateLogger               ;# Creates ::log, allowing logging
        app CreateRdb                  ;# Creates ::rdb.
        # TBD: Just make these singleton types.
        executiveType ::ex             ;# Create the command executive
        sim init                       ;# Create the simulation manager
        app CreateMenuBar              ;# Create the application menus.
        app CreateGUI                  ;# Fill in the rest of the main window.

        # NEXT, Allow the widget sizes to propagate to the toplevel, so
        # the window gets its default size; then turn off propagation.
        # From here on out, the user is in control of the size of the
        # window.
        update idletasks
        grid propagate . off

        # NEXT, load the database, if any.
        if {$gramdbFile ne ""} {
            ex evalsafe [list load $gramdbFile]
            $cli clear
        }

        # NEXT, run the initial script, if any.
        if {$initScript ne ""} {
            ex evalsafe [list call $initScript]
            $cli clear
        }

        # NEXT, Ask the scrolling log to load the current log file.
        .paner.simlog load [log cget -logfile]

        app puts "Welcome to GRAM Workbench!"
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
        # TBD: For now, create a subdirectory of the cwd
        set logdir [file normalize [file join . log app_gram]]
        
        file mkdir $logdir
        
        logger ::log \
            -simclock ::simclock \
            -logdir   $logdir

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

        $filemenu add command \
            -label "Load gramdb(5) File..." \
            -underline 0 \
            -accelerator "Ctrl+L" \
            -command [mytypemethod LoadDatabase]
        bind . <Control-l> [mytypemethod LoadDatabase]

        $filemenu add command \
            -label "Save RDB File..." \
            -underline 5 \
            -command [mytypemethod SaveDatabase]

        $filemenu add separator
        
        $filemenu add command \
            -label "Exit" \
            -underline 1 \
            -accelerator "Ctrl+Q" \
            -command [mytypemethod exit]
        bind . <Control-q> [mytypemethod exit]

        # NEXT, create the Edit menu
        set editmenu [menu $menu.edit]
        .menubar add cascade -label "Edit" -underline 0 -menu $editmenu
        
        $editmenu add command \
            -label "Cut" \
            -underline 2 \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $editmenu add command \
            -label "Copy" \
            -underline 0 \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}
        
        $editmenu add command \
            -label "Paste" \
            -underline 0 \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $editmenu add separator
        
        $editmenu add command \
            -label "Select All" \
            -underline 7 \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}
    }

    # CreateGUI
    #
    # Create the rest of the application's main window GUI

    typemethod CreateGUI {} {
        # FIRST, prepare the grid.  The scrolling log/shell paner
        # should stretch vertically on resize; the others shouldn't.
        # And everything should stretch horizontally.

        grid rowconfigure . 0 -weight 0
        grid rowconfigure . 1 -weight 1
        grid rowconfigure . 2 -weight 0
        grid rowconfigure . 3 -weight 0

        grid columnconfigure . 0 -weight 1

        # ROW 0, add a separator
        frame .sep0 -height 2 -relief sunken -borderwidth 2

        # ROW 1, add the log/cli paner
        paner .paner -orient vertical -showhandle 1
        
        # NEXT, Create the Scrolling Log
        scrollinglog .paner.simlog                            \
            -height        14                                 \
            -logcmd        [list app puts]                    \
            -loglevel      "debug"                            \
            -relief        flat                               \
            -showloglist   yes                                \
            -rootdir       [file normalize [file join . log]] \
            -defaultappdir app_gram
        .paner add .paner.simlog -sticky nsew -minsize 60

        log configure -overflowcmd {.paner.simlog load}

        # NEXT, Create the Executive shell
        set cli [cli .paner.shell \
                     -height 14                          \
                     -relief flat                        \
                     -evalcmd {ex eval}                  \
                     -promptcmd [mytypemethod CliPrompt] \
                     -commandlist [ex commands]]
        .paner add $cli -sticky nsew -minsize 60

        # ROW 2, add a separator
        frame .sep2 -height 2 -relief sunken -borderwidth 2

        # ROW 3, Create the Message line.
        set msgline [messageline .msgline]

        # NEXT, manage all of the components.
        grid .sep0     -sticky ew
        grid .paner    -sticky nsew
        grid .sep2     -sticky ew
        grid .msgline  -sticky ew
    }

    #-------------------------------------------------------------------
    # Callbacks: Menu Items

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

    # LoadDatabase
    #
    # Allows the user to select a gramdb(5) file via an OpenFile dialog;
    # the file is then loaded.
    
    typemethod LoadDatabase {} {
        set name [tk_getOpenFile \
                      -defaultextension ".gramdb"                 \
                      -filetypes        {{gramdb(5) {.gramdb}}}   \
                      -parent           .                         \
                      -title            "Load gramdb(5) File..."]
        
        if {$name ne ""} {
            ex evalsafe [list load $name]
        }
    }

    # SaveDatabase
    #
    # Allows the user to save a snapshot of the RDB to a file.

    typemethod SaveDatabase {} {
        # FIRST, if there's no database loaded there's nothing to save.
        if {![sim initialized]} {
            app puts "No database to save."
            bell
            return
        }
        
        set dbfile [sim dbfile]
        set initialDir [file dirname $dbfile]
        
        set defaultName [file rootname [file tail $dbfile]].rdb
        
        set filename [tk_getSaveFile \
                          -filetypes        {{Run-time Database {.rdb}}} \
                          -initialfile      $defaultName     \
                          -initialdir       $initialDir      \
                          -defaultextension .rdb             \
                          -title            "Save RDB As..." \
                          -parent           .]

        if {$filename eq ""} {
            app puts "Cancelled."
            return
        }

        if {[catch {
            $rdb saveas $filename
        } result]} {
            log warning app "Stack Trace:\n$::errorInfo"
            log warning app "Error saving '$filename': $result"
        } else {
            log normal app "Saved '$filename'"
        }
    }

    #-------------------------------------------------------------------
    # Other GUI Callbacks

    # CliPrompt
    #
    # cli -promptcmd procedure.  Gets the simulation time and puts it
    # in the prompt.

    typemethod CliPrompt {} {
        if {[sim initialized]} {
            return "[simclock asZulu]>"
        } else {
            return "gram>"
        }
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # Delegated typemethods
    delegate typemethod puts to msgline

    # fatal args
    #
    # args     One or more fatal error messages.  The messages are logged
    #          and written to standard output.  Halts with exit code 1.

    typemethod fatal {args} {
        # Write to stdout first, in case we can't write to the log.
        foreach msg $args {
            puts $msg
        }
        
        foreach msg $args {
            log fatal app $msg
        }
        
        app exit 1
    }

    # exit ?num?
    #
    # Exit the application cleanly

    typemethod exit {{num 0}} {
        catch {rdb close}
        exit $num
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








