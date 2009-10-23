#-----------------------------------------------------------------------
# TITLE:
#    appwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Main application window.
#
#    This window is implemented as a snit::widget; however, it's set up
#    to be the application's main window, and will exit the program when
#    it's closed, just like ".".  It's expected that "." will be
#    withdrawn at start-up.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# appwin

snit::widget appwin {
    hulltype toplevel
    
    #-------------------------------------------------------------------
    # Type Components
    
    component cli           ;# The cli(n) pane
    component msgline       ;# The messageline(n)
    component content       ;# The content notebook
    component slog          ;# The scrolling log
 
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -main flag
    #
    # If "yes", this is the main application window.  Otherwise,
    # this is just a browser window. This may affect the components, 
    # the menus, and so forth.
    
    option -main      \
        -default  no  \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance variables

    # Dictionary of tabs to be created.
    #
    #    label     The tab text
    #
    #    parent    The tag of the parent tab, or "" if this is a top-level
    #              tab.
    #
    #    script    Widget command (and options) to create the tab.
    #              "%W" is replaced with the name of the widget contained
    #              in the new tab.  For tabs containing notebooks, the
    #              script is "".
    #
    #    tabwin    Once the tab is created, its window.

    variable tabs {
        slog {
            label  "Log"
            parent ""
            script {
                scrollinglog %W \
                    -relief        flat                               \
                    -height        14                                 \
                    -logcmd        [mymethod puts]                    \
                    -loglevel      debug                              \
                    -showloglist   yes                                \
                    -rootdir       [file normalize [file join . log]] \
                    -defaultappdir app_gram                           \
                    -format        {
                        {zulu  12 yes}
                        {v      7 yes}
                        {c      9 yes}
                        {m      0 yes}
                    }
            }
        }
    }


    # Status info
    #
    # ticks   Current sim time as a four-digit tick
    # zulu    Current sim time as a zulu time string

    variable info -array {
        ticks  "0000"
        zulu   ""
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, set the default window title
        wm title $win "GRAM Workbench"

        # NEXT, Exit the app when this window is closed, if it's a 
        # main window.
        if {$options(-main)} {
            wm protocol $win WM_DELETE_WINDOW [list app exit]
        }
        
        # NEXT, Create the major window components
        $self CreateMenuBar
        $self CreateComponents

        # NEXT, Allow the created widget sizes to propagate to
        # $win, so the window gets its default size; then turn off 
        # propagation.  From here on out, the user is in control of the 
        # size of the window.

        update idletasks
        grid propagate $win off

        # NEXT, Prepare to receive notifier events.
        notifier bind ::sim <Reset>         $self [mymethod Reconfigure]
        notifier bind ::sim <Time>          $self [mymethod SimTime]

        # NEXT, Prepare to receive window events
        bind $content <<NotebookTabChanged>> [mymethod Reconfigure]

        # NEXT, Reconfigure self on creation
        $self Reconfigure
    }

    destructor {
        notifier forget $self
    }
    
    #===================================================================
    # Menu Bar
    
    #-------------------------------------------------------------------
    # Menu Bar: Creation

    # CreateMenuBar
    #
    # Creates the main menu bar

    method CreateMenuBar {} {
        # Menu Bar
        set menubar [menu $win.menubar -relief flat]
        $win configure -menu $menubar
        
        # File Menu
        set mnu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $mnu

        $mnu add command                  \
            -label       "New Browser"         \
            -underline   4                     \
            -accelerator "Ctrl+N"              \
            -command     [list appwin new]
        bind $win <Control-n> [list appwin new]
        bind $win <Control-N> [list appwin new]

        $mnu add command \
            -label "Load gramdb(5) File..." \
            -underline 0 \
            -accelerator "Ctrl+L" \
            -command [mymethod FileLoadGramdb]
        bind . <Control-l> [mymethod FileLoadGramdb]

        cond::dbloaded control \
            [menuitem $mnu command "Save RDB File..." \
                -underline 5                          \
                -command   [mymethod FileSaveRDB]]
        
        if {$options(-main)} {
            $mnu add command                               \
                -label     "Save CLI Scrollback Buffer..." \
                -underline 5                               \
                -command   [mymethod FileSaveCLI]
        }

        $mnu add separator

        if {$options(-main)} {
            $mnu add command                       \
                -label       "Exit"                \
                -underline   1                     \
                -accelerator "Ctrl+Q"              \
                -command     [list app exit]
            bind $win <Control-q> [list app exit]
            bind $win <Control-Q> [list app exit]
        } else {
            $mnu add command                       \
                -label       "Close Window"        \
                -underline   6                     \
                -accelerator "Ctrl+W"              \
                -command     [list destroy $win]
            bind $win <Control-w> [list destroy $win]
            bind $win <Control-W> [list destroy $win]
        }

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

        # View menu
        set viewmenu [menu $menubar.view]
        $menubar add cascade -label "View" -underline 0 -menu $viewmenu

        $self AddTabMenuItems $viewmenu
    }

    # AddTabMenuItems mnu
    #
    # mnu     The View menu
    #
    # Adds tabs to pop up the tabs to the View menu

    method AddTabMenuItems {mnu} {
        # FIRST, save the parent menu for toplevel tabs
        set pmenu() $mnu

        # FIRST, add each tab
        foreach tab [dict keys $tabs] {
            dict with tabs $tab {
                # FIRST, if this is a leaf tab just add its item.
                if {$script ne ""} {
                    $pmenu($parent) add command \
                        -label $label           \
                        -command [mymethod tab view $tab]
                    continue
                }

                # NEXT, this tab has subtabs.  Create a new menu
                set pmenu($tab) [menu $pmenu($parent).$tab]

                $pmenu($parent) add cascade \
                    -label $label \
                    -menu  $pmenu($tab)
            }
        }
    }
    
    #-------------------------------------------------------------------
    # Menu Bar: Menu Item Handlers

    # FileLoadGramdb
    #
    # Allows the user to select a gramdb(5) file via an OpenFile dialog;
    # the file is then loaded.
    
    method FileLoadGramdb {} {
        set name [tk_getOpenFile \
                      -defaultextension ".gramdb"                 \
                      -filetypes        {{gramdb(5) {.gramdb}}}   \
                      -parent           .                         \
                      -title            "Load gramdb(5) File..."]
        
        if {$name ne ""} {
            executive evalsafe [list load $name]
        }
    }

    # FileSaveRDB
    #
    # Allows the user to save a snapshot of the RDB to a file.
    #
    # TBD: We just shouldn't do this if there's no database.

    method FileSaveRDB {} {
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
                          -filetypes        {{"Run-time Database" {.rdb}}} \
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
            rdb saveas $filename
        } result]} {
            log warning app "Stack Trace:\n$::errorInfo"
            log warning app "Error saving '$filename': $result"
        } else {
            log normal app "Saved '$filename'"
        }
    }


    # FileSaveCLI
    #
    # Prompts the user to save the CLI scrollback buffer to disk
    # as a text file.
    #
    # TBD: This has become a standard pattern (catch, try/finally,
    # logging errors, etc).  Consider packaging it up as a standard
    # save file mechanism.

    method FileSaveCLI {} {
        # FIRST, query for the file name.  If the file already
        # exists, the dialog will automatically query whether to 
        # overwrite it or not. Returns 1 on success and 0 on failure.

        set filename [tk_getSaveFile                                   \
                          -parent      $win                            \
                          -title       "Save CLI Scrollback Buffer As" \
                          -initialfile "cli.txt"                       \
                          -filetypes   {
                              {{Text File} {.txt} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, Save the CLI using this name
        if {[catch {
            try {
                set f [open $filename w]
                puts $f [$cli get 1.0 end]
            } finally {
                close $f
            }
        } result opts]} {
            log warning app "Could not save CLI buffer: $result"
            log error app [dict get $opts -errorinfo]
            app error {
                |<--
                Could not save the CLI buffer to
                
                    $filename

                $result
            }
            return
        }

        log normal scenario "Saved CLI Buffer to: $filename"

        app puts "Saved CLI Buffer to [file tail $filename]"

        return
    }
    
    #===================================================================
    # Components

    # CreateComponents
    #
    # Creates the main window's components

    method CreateComponents {} {
        # FIRST, prepare the grid.  The scrolling log/shell paner
        # should stretch vertically on resize; the others shouldn't.
        # And everything should stretch horizontally.

        grid rowconfigure $win 0 -weight 0    ;# Separator
        grid rowconfigure $win 1 -weight 0    ;# Tool Bar
        grid rowconfigure $win 2 -weight 0    ;# Separator
        grid rowconfigure $win 3 -weight 1    ;# Content
        grid rowconfigure $win 4 -weight 0    ;# Separator
        grid rowconfigure $win 5 -weight 0    ;# Status line

        grid columnconfigure $win 0 -weight 1

        # NEXT, put in the row widgets

        # ROW 0, add a separator between the menu bar and the rest of the
        # window.
        ttk::separator $win.sep0 -orient horizontal

        # ROW 1, add a simulation toolbar
        ttk::frame $win.toolbar

        ttk::label $win.toolbar.zululabel \
            -text "Time:"
        
        ttk::label $win.toolbar.zulu              \
            -font         codefont                \
            -width        12                      \
            -textvariable [myvar info(zulu)]

        ttk::label $win.toolbar.ticklabel \
            -text "Tick:"
        
        ttk::label $win.toolbar.ticks             \
            -font         codefont                \
            -width        4                       \
            -anchor       e                       \
            -textvariable [myvar info(ticks)]
            
        pack $win.toolbar.ticks     -side right
        pack $win.toolbar.ticklabel -side right -padx {5 0}
        pack $win.toolbar.zulu      -side right
        pack $win.toolbar.zululabel -side right -padx {5 0}

        # ROW 2, add a separator between the tool bar and the content
        # window.
        ttk::separator $win.sep2 -orient horizontal

        # ROW 3, create the content widgets.  If this is a main window,
        # then we have a paner containing the content notebook with 
        # a CLI underneath.  Otherwise, we get just the content
        # notebook.
        if {$options(-main)} {
            paner $win.paner -orient vertical -showhandle 1
            install content using ttk::notebook $win.paner.content \
                -padding 2 

            $win.paner add $content \
                -sticky  nsew       \
                -minsize 120        \
                -stretch always

            set row3 $win.paner
        } else {
            install content using ttk::notebook $win.content \
                -padding 2 

            set row3 $win.content
        }

        # ROW 4, add a separator
        ttk::separator $win.sep4 -orient horizontal

        # ROW 5, Create the Status Line frame.
        ttk::frame $win.status    \
            -relief      flat     \
            -borderwidth 2

        # Message line
        install msgline using messageline $win.status.msgline

        pack $win.status.msgline -fill both -expand yes


        # NEXT, add the content tabs, and save relevant tabs
        # as components.  Also, finish configuring the tabs.
        $self AddTabs

        # Scrolling log
        set slog   [$self tab win slog]
        $slog load [log cget -logfile]
        notifier bind ::app <AppLogNew> $self [list $slog load]

        # NEXT, add the CLI to the paner, if needed.
        if {$options(-main)} {
            install cli using cli $win.paner.cli    \
                -height    8                        \
                -relief    flat                     \
                -promptcmd [mymethod CliPrompt]     \
                -evalcmd   [list ::executive eval]
            
            $win.paner add $win.paner.cli \
                -sticky  nsew             \
                -minsize 60               \
                -stretch never

            # Load the CLI command history
            $self LoadCliHistory
        }

        # NEXT, manage all of the components.
        grid $win.sep0     -sticky ew
        grid $win.toolbar  -sticky ew
        grid $win.sep2     -sticky ew
        grid $row3         -sticky nsew
        grid $win.sep4     -sticky ew
        grid $win.status   -sticky ew
    }

    # AddTabs
    #
    # Adds all of the content tabs and subtabs to the window.

    method AddTabs {} {
        # FIRST, add each tab
        foreach tab [dict keys $tabs] {
            # Add a "tabwin" key to the 
            dict set tabs $tab tabwin ""

            # Create the tab
            dict with tabs $tab {
                # FIRST, get the parent
                if {$parent eq ""} {
                    set p $content
                } else {
                    set p [dict get $tabs $parent tabwin]
                }

                # NEXT, get the new tabwin name
                set tabwin $p.$tab

                # NEXT, create the new tab widget
                if {$script eq ""} {
                    ttk::notebook $tabwin -padding 2
                } else {
                    eval [string map [list %W $tabwin] $script]
                }

                # NEXT, add it to the parent notebook
                $p add $tabwin      \
                    -sticky  nsew   \
                    -padding 2      \
                    -text    $label
            }
        }
    }
    
    #-------------------------------------------------------------------
    # Components: Event Handlers

    # Reconfigure
    #
    # Reconfigure the window given the new scenario

    method Reconfigure {} {
        if {[sim dbfile] ne ""} {
            wm title $win "[file tail [sim dbfile]] - GRAM Workbench"
        } else {
            wm title $win "GRAM Workbench"
        }
        $self SimTime
    }

    # SimTime
    #
    # This routine is called when the simulation time display has changed,
    # either because the start date has changed, or the time has advanced.

    method SimTime {} {
        # Display current sim time.
        set info(ticks) [format "%04d" [simclock now]]
        set info(zulu)  [simclock asZulu]
    }

    # CliPrompt
    #
    # Returns a prompt string for the CLI

    method CliPrompt {} {
        return ">"
    
        # TBD: Need to update executive first
        if {[executive usermode] eq "super"} {
            return "super>"
        } else {
            return ">"
        }
    }
    
    #===================================================================
    # Public Methods

    #-------------------------------------------------------------------
    # Tab Management

    # tab win tab
    #
    # Returns the window name of the specified tab
    
    method {tab win} {tab} {
        dict get $tabs $tab tabwin
    }

    # tab view tab
    #
    # Makes the window display the specified tab

    method {tab view} {tab} {
        dict with tabs $tab {
            if {$parent eq ""} {
                $content select $tabwin
            } else {
                set pwin [dict get $tabs $parent tabwin]

                $content select $pwin
                $pwin select $tabwin
            }
        }
    }
   
    #-------------------------------------------------------------------
    # CLI history

    # savehistory
    #
    # If there's a CLI, saves its command history to 
    # ~/.mars_gram/history.cli.

    method savehistory {} {
        assert {$cli ne ""}

        file mkdir ~/.mars_gram
        
        set f [open ~/.mars_gram/history.cli w]

        puts $f [$cli saveable checkpoint]
        
        close $f
    }

    # LoadCliHistory
    #
    # If there's a CLI, and a history file, read its command history.

    method LoadCliHistory {} {
        if {[file exists ~/.mars_gram/history.cli]} {
            $cli saveable restore [readfile ~/.mars_gram/history.cli]
        }
    }

    # cli clear
    #
    # Clears the contents of the CLI scrollback buffer

    method {cli clear} {} {
        require {$cli ne ""} "No CLI in this window: $win"

        $cli clear
    }

    # new ?option value...?
    #
    # Creates a new app window.

    typemethod new {args} {
        $type create .%AUTO% {*}$args
    }
    
    # error text
    #
    # text       A tsubst'd text string
    #
    # Displays the error in a message box

    method error {text} {
        set text [uplevel 1 [list tsubst $text]]

        messagebox popup   \
            -message $text \
            -icon    error \
            -parent  $win
    }

    # puts text
    #
    # text     A text string
    #
    # Writes the text to the message line

    method puts {text} {
        $msgline puts $text
    }

}
