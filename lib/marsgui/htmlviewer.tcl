#-----------------------------------------------------------------------
# TITLE:
#    htmlviewer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n): HTML Viewer Widget, based on Tkhtml 2.0
#
#    htmlviewer(n) is a Snit wrapper around Tkhtml 2.0.  It adds a
#    few new methods, and also defines some additional bindings from
#    the "tkhtml" page at the Tcler's Wiki.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export htmlviewer
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::htmlviewer {
    #-------------------------------------------------------------------
    # Type Constructor
    #
    # This type constructor defines a number of standard bindings.
    # They will affect all instances of Tkhtml, not just those
    # using this wrapper.

    typeconstructor {
        #-------------------------------------------------------------------
        # FIRST, the missing bindings from the tkhtml page at the Tcler's
        # Wiki, http://wiki.tcl.tk/2336, with my changes.

        #
        # Change cursor to hand if over hyperlink
        # Copied from hv.tcl
        #

        bind HtmlClip <Motion> {
            set parent [winfo parent %W]
            set url [$parent href %x %y]
            if {[string length $url] > 0} {
                $parent configure -cursor hand2
            } else {
                $parent configure -cursor {}
            }

        }

        #
        # Mouse Wheel bindings
        # Cut'n'pasted from Text widget binding
        #

        if {[string equal [tk windowingsystem] "classic"]
            || [string equal [tk windowingsystem] "aqua"]} {
            bind HtmlClip <MouseWheel> {
                %W yview scroll [expr {- (%D)}] units
            }
            bind HtmlClip <Option-MouseWheel> {
                %W yview scroll [expr {-10 * (%D)}] units
            }
            bind HtmlClip <Shift-MouseWheel> {
                %W xview scroll [expr {- (%D)}] units
            }
            bind HtmlClip <Shift-Option-MouseWheel> {
                %W xview scroll [expr {-10 * (%D)}] units
            }
        } else {
            bind HtmlClip <MouseWheel> {
                %W yview scroll [expr {- (%D / 120) * 4}] units
            }
        }

        if {[string equal "x11" [tk windowingsystem]]} {
            # Support for mousewheels on Linux/Unix commonly comes through 
            # mapping the wheel to the extended buttons.  If you have a 
            # mousewheel, find Linux configuration info at:
            #   http://www.inria.fr/koala/colas/mouse-wheel-scroll/
            bind HtmlClip <4> {
                if {!$tk_strictMotif} {
                    %W yview scroll -1 units
                }
            }
            bind HtmlClip <5> {
                if {!$tk_strictMotif} {
                    %W yview scroll 1 units
                }
            }

        }

        #
        # Invoke widget hyperlink command on the hyperlink
        #
        bind HtmlClip <1> {
            set parent [winfo parent %W]
            focus $parent ;# WHD - so that key-scrolling works
            set url [$parent href %x %y]
            if {[string length $url]} {
                {*}[$parent cget -hyperlinkcommand] $url
            }
        }

        # Key-scrolling bindings
        bind Html <Prior>  {%W yview scroll -1 pages}
        bind Html <Next>   {%W yview scroll  1 pages}
        bind Html <Home>   {%W yview moveto 0.0}
        bind Html <End>    {%W yview moveto 1.0}
        bind Html <Up>     {%W yview scroll -1 units}
        bind Html <Down>   {%W yview scroll  1 units}
        bind Html <Left>   {%W xview scroll -1 units}
        bind Html <Right>  {%W xview scroll  1 units}
        
    }

    #-------------------------------------------------------------------
    # Standard Font Sizes

    typevariable pixels -array {
        1    -9
        2    -10
        3    -12
        4    -14
        5    -18
        6    -20
        7    -22
    }

    #-------------------------------------------------------------------
    # Inherit html behavior

    delegate option * to hull
    delegate method * to hull

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the hull
        installhull [html $win                        \
                         -highlightthickness 1        \
                         -background         white    \
                         -foreground         black    \
                         -unvisitedcolor     \#1C1CF0 \
                         -visitedcolor       \#561B8B \
                         -borderwidth        0        \
                         -relief             flat     \
                         -tablerelief        flat     \
                         -width              5i       \
                         -height             4i       \
                         -fontcommand        [mymethod FontCommand]]

        $self configurelist $args
    }

    # FontCommand size font
    #
    # size    Size, 1 to 7; 4 is standard
    # font    0 to 3 of "bold", "italic", "fixed".
    #
    # Returns the Tcl font to use.  Note that the widget does the
    # right thing for roman text; "fixed" is the problem.

    method FontCommand {size font} {
        if {"fixed" in $font} {
            set basefont TkFixedFont
            set font ""
        } else {
            set basefont TkTextFont
        }

        set family   [dict get [font actual $basefont] -family]
        set fontspec [list $family $pixels($size) {*}$font]

        return $fontspec
    }

    #-------------------------------------------------------------------
    # Public Methods

    # set html
    # 
    # html     An HTML-formatted text string
    #
    # Displays the HTML text, replacing any previous contents.

    method set {html} {
        $hull clear
        $hull parse $html
    }
}
