#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_log(1) Main Application Window
#
#    This module defines app, the application ensemble.  app encapsulates 
#    all of the functionality of the mars_log(1) main window, 
#    including the application's start-up behavior.  To invoke the 
#    application,
#
#        package require app_log
#        app init $argv
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

# All needed packages are required in app_log.tcl.

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hasinstances 0
    
    #-------------------------------------------------------------------
    # Type Components
    
    typecomponent log      ;# The scrollinglog(n)
    typecomponent msgline  ;# The messageline(n)
    
    #-------------------------------------------------------------------
    # Type Variables

    # Options
    typevariable opts -array {
        -appname       "mars log"
        -defaultappdir ""
        -manpage       "mars_log(1)"
        -project       "Mars"
    }
    
    # fieldFlag array: show/hide the named field.
    
    typevariable fieldFlags -array {
        t      0
        zulu   1
        v      1
        c      1
    }

    # scrollLockFlag -- do we auto-update and scroll, or not.
    typevariable scrollLockFlag 0
    
    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv  Command line arguments (if any)
    #
    # Initializes the application.
    typemethod init {argv} {
        # FIRST, get the log directory.
        if {[llength $argv] == 0} {
            set logdir log
        } elseif {[llength $argv] == 1} {
            set logdir [lshift argv]
        } else {
            app usage
            exit 1
        }


        # NEXT, is this a directory of log files, or a directory of
        # application log directories?  If the latter, set parentFlag
        # to true.
        
        if {[llength [glob -nocomplain [file join $logdir *.log]]] > 0} {
            set parentFlag 0
        } elseif {[llength [glob -nocomplain [file join $logdir * *.log]]] > 0} {
            set parentFlag 1
        } else {
            set parentFlag 0
        }
        
        # NEXT, set the default window title
        wm title . "$opts(-project) Log: [file normalize $logdir]"

        # NEXT, Exit the app when this window is closed, if it's a 
        # main window.
        wm protocol . WM_DELETE_WINDOW [list app exit]
        
        # NEXT, create the menus
        
        # Menu Bar
        set menubar [menu .menubar -relief flat]
        . configure -menu $menubar
        
        # File Menu
        set mnu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $mnu

        $mnu add command                       \
            -label       "Exit"                \
            -underline   1                     \
            -accelerator "Ctrl+Q"              \
            -command     [list app exit]
        bind . <Control-q> [list app exit]
        bind . <Control-Q> [list app exit]

        # Edit menu
        set mnu [menu $menubar.edit]
        $menubar add cascade -label "Edit" -underline 0 -menu $mnu

        $mnu add command \
            -label "Cut" \
            -underline 2 \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $mnu add command \
            -label "Copy" \
            -underline 0 \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}
        
        $mnu add command \
            -label "Paste" \
            -underline 0 \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $mnu add separator
        
        $mnu add command \
            -label "Select All" \
            -underline 7 \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}
        
        # View Menu
        set mnu [menu $menubar.view]
        $menubar add cascade -label "View" -underline 2 -menu $mnu
        
        $mnu add checkbutton \
            -label    "Set Scroll Lock"                 \
            -variable [mytypevar scrollLockFlag]        \
            -command  [mytypemethod SetScrollLock]
        
        $mnu add separator

        $mnu add checkbutton \
            -label    "Show Wall Clock Time"            \
            -variable [mytypevar fieldFlags(t)]         \
            -command  [mytypemethod ShowHideField t]

        $mnu add checkbutton \
            -label    "Show Zulu Time"                  \
            -variable [mytypevar fieldFlags(zulu)]      \
            -command  [mytypemethod ShowHideField zulu]

        $mnu add checkbutton \
            -label    "Show Verbosity"                  \
            -variable [mytypevar fieldFlags(v)]         \
            -command  [mytypemethod ShowHideField v]

        $mnu add checkbutton \
            -label    "Show Component"                  \
            -variable [mytypevar fieldFlags(c)]         \
            -command  [mytypemethod ShowHideField c]

        # NEXT, create the components
        
        # ROW 0 -- separator
        ttk::separator .sep0 -orient horizontal
        
        # ROW 1 -- Scrolling log
        set log .log
        scrollinglog .log                           \
            -relief        flat                     \
            -height        24                       \
            -logcmd        [mytypemethod puts]      \
            -loglevel      normal                   \
            -showloglist   yes                      \
            -showapplist   $parentFlag              \
            -defaultappdir $opts(-defaultappdir)    \
            -rootdir       [file normalize $logdir] \
            -parsecmd      [myproc LogParser]       \
            -format        {
                {t     20 no}
                {zulu  12 yes}
                {v      7 yes}
                {c      9 yes}
                {m      0 yes}
             }
             
        # ROW 2 -- separator
        ttk::separator .sep2 -orient horizontal
        
        # ROW 3 -- message line
        set msgline [messageline .msgline]

        # NEXT, grid the components in
        grid .sep0    -row 0 -column 0 -sticky ew
        grid .log     -row 1 -column 0 -sticky nsew -pady 2
        grid .sep2    -row 2 -column 0 -sticky ew
        grid .msgline -row 3 -column 0 -sticky ew
        
        grid rowconfigure    . 1 -weight 1 ;# Content
        grid columnconfigure . 0 -weight 1
        
        # NEXT, addition behavior
        bind all <Control-F12> [list debugger new]
    }
    
    #-------------------------------------------------------------------
    # Event Handlers
    
    # SetScrollLock
    #
    # Locks/Unlocks the scrolling log's scroll lock
    
    typemethod SetScrollLock {} {
        $log lock $scrollLockFlag
    }

    # ShowHideField name
    #
    # Shows/Hides the named field
    
    typemethod ShowHideField {name} {
        if {$fieldFlags($name)} {
            $log field show $name
        } else {
            $log field hide $name
        }
    }
    
    #-------------------------------------------------------------------
    # Utility Procs

    # LogParser text
    #
    # text    A block of log lines
    #
    # Parses the lines and returns a list of lists.
    
    proc LogParser {text} {
        set lines [split [string trimright $text] "\n"]
    
        set lineList {}

        foreach line $lines {
            set fields [list \
                            [lindex $line 0] \
                            [lindex $line 4] \
                            [lindex $line 1] \
                            [lindex $line 2] \
                            [lindex $line 3] \
                            [lindex $line 1]]
            
            lappend lineList $fields
        }
        
        return $lineList
    }
    
    #-------------------------------------------------------------------
    # Application Framework Type Methods
    
    # configure option ?value? ?option value...?
    #
    # option    A configuration option
    # value     A new value for the option
    #
    # Sets/gets application framework options.
    
    typemethod configure {args} {
        if {[llength $args] == 1} {
            return $opts([lindex $args 0])
        }
        
        # NEXT, get the options
        while {[llength $args] > 0} {
            set opt [lshift args]
            
            switch -exact -- $opt {
                -appname       -
                -defaultappdir -
                -manpage       -
                -project       {
                    set opts($opt) [lshift args]
                }
                
                default {
                    error "Unrecognized option: $opt"
                }
            }
        }
    }
    
    
    #-------------------------------------------------------------------
    # Utility Type Methods
    
    # exit ?code?
    #
    # Exits the program.
    
    typemethod exit {{code 0}} {
        # TBD: Put any special exit handling here.
        exit $code
    }
    
    # puts msg
    #
    # msg     A text string
    #
    # Display the text string in the message line
    
    typemethod puts {msg} {
        $msgline puts $msg        
    }

    # usage
    #
    # Displays the application's command-line syntax
    
    typemethod usage {} {
        puts "Usage: $opts(-appname) \[logdir\]"
        puts ""
        puts "See $opts(-manpage) information."
    }
}



