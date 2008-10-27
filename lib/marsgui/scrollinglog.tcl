#-----------------------------------------------------------------------
# TITLE:
#    scrollinglog.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Scrolling Log Browser widget.
#
#    This widget displays an application's current log file;
#    it allows scrolling, filtering, and searching.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export scrollinglog
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::scrollinglog {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Add defaults to the option database
        option add *Scrollinglog.borderWidth        1
        option add *Scrollinglog.relief             flat
        option add *Scrollinglog.background         white
        option add *Scrollinglog.Foreground         black
        option add *Scrollinglog.font               codefont
        option add *Scrollinglog.width              80
        option add *Scrollinglog.height             24
        option add *Scrollinglog.insertWidth        0
        option add *Scrollinglog.hullbackground     $::marsgui::defaultBackground

        namespace import ::marsutil::logger  ;# need log levels
    }

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option -borderwidth    to hull
    delegate option -relief         to hull
    delegate option -hullbackground to hull as -background
    delegate option *               to hull

    # Options delegated to the logdisplay widget
    delegate option -format             to log
    delegate option -parsecmd           to log
    delegate option -tags               to log
    delegate option -updateinterval     to log
    delegate option -autoupdate         to log
    delegate option -font               to log
    delegate option -height             to log
    delegate option -width              to log
    delegate option -foreground         to log
    delegate option -background         to log
    delegate option {-insertbackground insertBackground Foreground} to log
    delegate option {-insertwidth insertWidth InsertWidth}          to log

    # -title
    #
    # Title label for toolbar

    option -title -default "Log"

    # -logcmd
    #
    # Specifies a command that the scrolling log can use to output
    # messages, typically to the messageline.  It should take one
    # argument, a message string.

    option -logcmd

    # -loglevel
    #
    # Maximum log level (verbosity) to show.

    option -loglevel -default "normal" -configuremethod SetLogLevel

    #-------------------------------------------------------------------
    # Components

    component bar            ;# The title/tool bar
    component log            ;# The scrolling text widget

    #-------------------------------------------------------------------
    # Instance variables

    variable scrollbackFlag 1      ;# Var for $bar.scrollback
    variable verbosities -array {} ;# Controls which levels to display

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the components
        
        $hull configure \
            -borderwidth 1 \
            -relief raised

        # Title Bar
        install bar using frame $win.bar \
            -relief flat

        # Get the -parsecmd, -format, and -tags values, specifying
        # the scrollinglog(n) default.
        set parseCmd [from args -parsecmd [myproc LogParser]]
        set format   [from args -format {
            {zulu  12 yes}
            {v      7 yes}
            {c      7 yes}
            {m      0 yes}
        }]
        set tags     [from args -tags {
            {fatal   -background red}
            {error   -background orange}
            {warning -background yellow}
        }]
            
        # log
        install log using logdisplay $win.dlog          \
            -foreground     black                       \
            -background     white                       \
            -height         24                          \
            -width          80                          \
            -msgcmd         [mymethod LogCmd]           \
            -autoupdate     1                           \
            -autoscroll     $scrollbackFlag             \
            -filtercmd      [mymethod LogFilter]        \
            -foundcmd       [list $bar.finder found]    \
            -parsecmd       $parseCmd                   \
            -format         $format                     \
            -tags           $tags

        # Title bar contents
        label $bar.title \
            -textvariable [myvar options(-title)]

        ComboBox    $bar.loglevel \
            -modifycmd    [mymethod HandleLogLevel]      \
            -textvariable [myvar options(-loglevel)]     \
            -values       [lrange [logger levels] 1 end] \
            -font         codefont  \
            -width        7         \
            -editable     0           

        checkbutton $bar.scrollback \
            -bitmap @$::marsgui::library/autoscroll_on.xbm \
            -indicatoron 0 \
            -offrelief flat \
            -variable [myvar scrollbackFlag] \
            -offvalue 1 \
            -onvalue  0 \
            -highlightthickness 0 \
            -command [mymethod SetScrollback]

        finder $bar.finder             \
            -findcmd [list $log find]  \
            -msgcmd  [mymethod LogCmd] \
            -width   20

        filter $bar.filter \
            -filtercmd [mymethod FilterHandler] \
            -msgcmd    [mymethod LogCmd]        \
            -width     20

        pack $bar.scrollback -side right -padx 1
        pack $bar.finder     -side right -padx 1
        pack $bar.filter     -side right -padx 1
        pack $bar.loglevel   -side right -padx 1
        pack $bar.title      -side left  -padx 1

        # Pack it up
        pack $bar -side top -fill x
        pack $log -side top -fill both -expand 1

        # NEXT, process the arguments
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Private Methods

    # SetLogLevel 
    #
    # Sets the log level.

    method SetLogLevel {option value} {
        set options(-loglevel) $value

        $self HandleLogLevel
    }

    # HandleLogLevel 
    #
    # Adjusts the verbosities array according to -loglevel and calls redisplay.

    method HandleLogLevel {} {
        set levels [logger levels]
        set lognum [lsearch $levels $options(-loglevel)]
        foreach level $levels {
            set verbosities($level) 1
            if {[lsearch $levels $level] > $lognum} {
                set verbosities($level) 0
            }
        }

        $log redisplay
    }

    # SetScrollback
    #
    # Sets the logdisplay's -autoupdate based on the scrollback flag

    method SetScrollback {} {
    
        $log configure -autoscroll $scrollbackFlag
        
        # Set the scrollback button's bitmap to match.
        if {$scrollbackFlag} {
    
            $bar.scrollback configure \
                                -bitmap @$::marsgui::library/autoscroll_on.xbm
            
        } else {
    
            $bar.scrollback configure \
                                -bitmap @$::marsgui::library/autoscroll_off.xbm
        }
    }

    # FilterHandler
    #
    # Trigger refiltration

    method FilterHandler {} {
        $log redisplay
    }

    # LogFilter entryStr
    #
    # entryStr   The string to filter on.
    #
    # Returns 1 if the entryStr passes the filter, and 0 otherwise.

    method LogFilter {entryStr} {
        #  Filter by verbosity.
        if {!$verbosities([lindex $entryStr 1])} {
            return 0
        }

        return [$bar.filter check $entryStr]
    }

    # LogCmd args
    #
    # Passes the finger and logdisplay's logcmd onward.

    method LogCmd {msg} {
        if {$options(-logcmd) ne ""} {
            set cmd $options(-logcmd)
            lappend cmd $msg
            uplevel \#0 $cmd
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
    # Public Methods

    delegate method field to log
    delegate method load  to log
}







