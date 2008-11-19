#-----------------------------------------------------------------------
# TITLE:
#   filter.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Filter widget.
# 
#   This widget provides a text filter control for doing exact, wildcard,
#   regular expression filtering, both inclusive and exclusive, of
#   arbitrary text.  Filtering is triggered when <Return> is pressed in
#   the entry field, when the filter's contents is cleared, and an item
#   is selected on the Sieve Icon menu.
# 
#   filter type:    exact        exact string filter
#                   wildcard     wildcard filter (? and *)
#                   regexp       full regexp filter
# 
#   inclusive:      yes, no
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export filter
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::filter {
    #-------------------------------------------------------------------
    # Components

    component entry       ;# The command entry in which they enter the
                           # search string.
    
    #-------------------------------------------------------------------
    # Options

    # -msgcmd cmd
    # 
    # Specifies a log command for reporting messages.    
    option -msgcmd -default ""
    
    # -filtercmd  cmd
    # 
    # A command to be executed when filtration is triggered.
    option -filtercmd -default ""

    # Delegate all other options to the hull
    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Variables

    variable filterType   "exact"    ;# exact, wildcard, regexp
    variable inclusive    yes        ;# Include or exclude matches
    variable targetRegexp ""         ;# Used by "check".

    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, configure the hull to look like a sunken entry.
        $hull configure                 \
            -relief             sunken  \
            -borderwidth        1       \
            -highlightcolor     black   \
            -highlightthickness 1       \
            -pady               2
            
        # NEXT, Create the -type menu.
        menubutton $win.type                            \
            -relief           flat                      \
            -borderwidth      0                         \
            -activebackground $::marsgui::defaultBackground \
            -image            ::marsgui::filter_icon        \
            -menu             $win.type.menu
        
        menu $win.type.menu  \
            -tearoff      0  \
            -borderwidth  1
        
        $win.type.menu add radio           \
            -label    "Exact"              \
            -variable [myvar filterType]   \
            -value    "exact"              \
            -command  [mymethod FilterNow]
            
        $win.type.menu add radio           \
            -label    "Wildcard"           \
            -variable [myvar filterType]   \
            -value    "wildcard"           \
            -command  [mymethod FilterNow]


        $win.type.menu add radio           \
            -label    "Regexp"             \
            -variable [myvar filterType]   \
            -value    "regexp"             \
            -command  [mymethod FilterNow]
            
        $win.type.menu add separator
        
        $win.type.menu add radio           \
            -label    "Include Matches"    \
            -variable [myvar inclusive]    \
            -value    yes                  \
            -command  [mymethod FilterNow]
            
        $win.type.menu add radio           \
            -label    "Exclude Matches"    \
            -variable [myvar inclusive]    \
            -value    no                   \
            -command  [mymethod FilterNow]
            
        # Install the filter field.
        install entry using ::marsgui::commandentry $win.entry  \
            -background         $::marsgui::defaultBackground   \
            -highlightthickness 0                           \
            -borderwidth        0                           \
            -clearbtn           1                           \
            -changecmd          [mymethod EntryChange]      \
            -returncmd          [mymethod EntryReturn]                    
                                  
        grid $win.type $entry -sticky nsew -padx 2

        grid columnconfigure $win 1 -weight 1
            
        # Save the constructor options.
        $self configurelist $args
    }
    
    # Destructor: default destructor is adequate


    #-------------------------------------------------------------------
    # Private Methods

    # EntryChange string
    #
    # Triggers filtration if the field is now empty
    method EntryChange {string} {
        if {$string eq ""} {
            $self FilterNow
        }
    }
    

    # EntryReturn string
    #
    # Triggers filtration
    method EntryReturn {string} {
        $self FilterNow
    }

    # FilterNow
    #
    # Set up to check strings against the filter conditions, and 
    # execute the -filtercmd
    method FilterNow {} {
        set target [string trim [$entry get]]
        
        if {$target eq ""} {
            set targetRegexp ""
        } else {
            # Process the new target according to the type.
            switch -exact -- $filterType {
                "exact" {
                    # JLS: This syntax no longer works with 8.5!
                    # See bug1647
                    set targetRegexp  "***=$target"
                }        
                "wildcard" {
                    set targetRegexp [::marsutil::wildToRegexp $target]
                } 
                "regexp" {
                    set targetRegexp $target
                }
            }

            # Check the regexp for errors.  On error, write a message
            # using the -msgcmd.
            if {[catch {regexp -- $targetRegexp dummy} result]} {
                $self Message "invalid $filterType: \"[$entry get]\""
                bell
                return
            }
        }
    
        # Call the -filtercmd.
        if {$options(-filtercmd) ne ""} {
            uplevel \#0 $options(-filtercmd)
        }
    }

    # Message msg
    #
    # msg   A message string
    #
    # Logs a message using the -msgcmd.
    method Message {msg} {
        if {$options(-msgcmd) ne ""} {
            set cmd $options(-msgcmd)
            lappend cmd $msg
            uplevel \#0  $cmd
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # check string
    #
    # string    A string to filter
    #
    # Checks the string against the filter settings.  Returns 1 if the
    # string is included, and 0 otherwise.
    method check {string} {
        # If there's no target, all strings are included.
        if {$targetRegexp eq ""} {
            return 1
        }

        set flag [regexp -- $targetRegexp $string]

        if {!$inclusive} {
            set flag [expr {!$flag}]
        }
        
        return $flag
        # return 1
    }
}



