#-----------------------------------------------------------------------
# TITLE:
#    rangefield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    formlib(n) package: Range slider field
#
#    A rangefield is a data entry field containing a slider, a label
#    showing the current value, and optionally either a quality pulldown
#    or an editable text entry.  It can also have a reset button.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::formlib:: {
    namespace export rangefield
}

#-------------------------------------------------------------------
# rangefield

snit::widget ::formlib::rangefield {
    #-------------------------------------------------------------------
    # Components

    component resetbtn        ;# ttk::button
    component scale           ;# tk::scale
    component vlabel          ;# Value label
    component qmenu           ;# Quality pulldown menu

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    delegate option -length to scale

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        callwith $resetbtn configure -state $val
        $scale             configure -state $val
        callwith $qmenu    configure -state $val
    }


    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    # -type command
    #
    # Command is a snit::double, snit::integer, range(n), or quality(n)
    # value (or anything with -min and -max options).  It determines
    # the range of values on the scale.

    option -type \
        -readonly yes

    # -resetvalue value
    #
    # The value to which the scale is reset when the field's value
    # is cleared.  If not set, a heuristic is applied to 
    # determine a reasonable value.

    option -resetvalue \
        -default ""    \
        -readonly yes

    # -resolution value
    #
    # If not "", the value is propagated to the scale.  Otherwise,
    # a heuristic is applied to determine a reasonable resolution.
    
    option -resolution \
        -default  ""   \
        -readonly yes

    # -showreset flag
    #
    # If true, the widget will have a "Reset" button that sets the
    # scale to the -resetvalue.

    option -showreset \
        -default no   \
        -readonly yes


    # -showsymbols flag
    #
    # If true, the field contains a menu of symbolic values from
    # the -type, which must be a quality(n) object.

    option -showsymbols \
        -default  no    \
        -readonly yes



    #-------------------------------------------------------------------
    # Instance Variables

    variable current        0    ;# Current value
    variable inScaleChanged 0    ;# Flag

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -highlightthickness 0

        # NEXT, create the scale
        install scale using scale $win.scale   \
            -orient    horizontal              \
            -showvalue no                      \
            -takefocus 1                       \
            -length    150                     \
            -variable  [myvar current]         \
            -command   [mymethod ScaleChanged]

        # NEXT, clicking on the scale should give it the focus.
        bind $scale <1> {focus %W}

        # NEXT, configure the arguments
        $self configure {*}$args

        # NEXT, set the scale's bounds and value.
        if {$options(-resetvalue) eq ""} {
            $self ChooseResetValue
        }

        if {$options(-resolution) eq ""} {
            $self ChooseResolution
        }

        $scale configure \
            -from       [$options(-type) cget -min]  \
            -to         [$options(-type) cget -max]  \
            -resolution $options(-resolution)

        set vlabelWidth [$self GetLabelWidth]

        $self Reset

        $scale configure \
            -command    [mymethod ScaleChanged]

        # NEXT, create the label
        install vlabel using ttk::label $win.vlabel  \
            -width        $vlabelWidth               \
            -textvariable [myvar current]

        # NEXT, create the reset button if needed
        if {$options(-showreset)} {
            install resetbtn using button $win.reset \
                -state     $options(-state)          \
                -font      tinyfont                  \
                -text      "Reset"                   \
                -takefocus 0                         \
                -command   [mymethod Reset]
        } else {
            set resetbtn ""
        }

        # NEXT, create qmenu if needed.
        if {$options(-showsymbols)} {
            set width [lmaxlen [$options(-type) longnames]]

            install qmenu as enumfield $win.qmenu     \
                -enumtype    $options(-type)          \
                -displaylong 1                        \
                -changecmd   [mymethod SymbolChanged] \
                -width       $width
        } else {
            set qmenu ""
        }

        # NEXT, lay out the widgets.
        set c -1
        
        if {$resetbtn ne ""} {
            grid $resetbtn -row 0 -column [incr c] -sticky w -padx {0 4}
        }

        grid $scale -row 0 -column [incr c] -sticky ew -padx {0 4}

        grid $vlabel -row 0 -column [incr c] -sticky w

        grid columnconfigure $win $c -weight 1

        if {$qmenu ne ""} {
            grid $qmenu -row 0 -column [incr c] -sticky ew -padx {4 0}
        }
        
    }

    #-------------------------------------------------------------------
    # Private Methods

    # ChooseResetValue
    #
    # Picks a reasonable resolution for the scale based on the limits.

    method ChooseResetValue {} {
        set min [$options(-type) cget -min]
        set max [$options(-type) cget -max]

        if {$min <= 0 && 0 <= $max} {
            set options(-resetvalue) 0
        } else {
            set options(-resetvalue) $min
        }
    }

    # ChooseResolution
    #
    # Picks a reasonable resolution for the scale based on the limits.

    method ChooseResolution {} {
        set min [$options(-type) cget -min]
        set max [$options(-type) cget -max]

        if {$max - $min >= 50} {
            set options(-resolution) 1
        } elseif {$max - $min < 0.5} {
            set options(-resolution) 0.01
        } else {
            set options(-resolution) 0.05
        }
    }

    # GetLabelWidth
    #
    # Computes and returns the appropriate width for the value label.

    method GetLabelWidth {} {
        $scale set [$scale cget -from]
        set a [string length [$scale get]]

        $scale set [$scale cget -to]
        set b [string length [$scale get]]

        return [expr {max($a,$b)}]
    }

    # ScaleChanged value
    #
    # The value of the scale widget changed.

    method ScaleChanged {value} {
        if {$qmenu ne ""} {
            set inScaleChanged 1
            $qmenu set [$options(-type) name $current]
            set inScaleChanged 0
        }

        callwith $options(-changecmd) $current
    }

    # Reset
    #
    # The Reset button was pressed.

    method Reset {} {
        $self set $options(-resetvalue)
    }

    # SymbolChanged value
    #
    # A new symbol was selected in the qmenu
    
    method SymbolChanged {value} {
        if {$inScaleChanged} {
            return
        }

        $scale set [$options(-type) value $value]
    }


    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Returns the current value.

    method get {} {
        return [$scale get]
    }

    # set value
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        if {$value eq ""} {
            # The scale can't display ""
            set value $options(-resetvalue)
        }

        if {$value != [$scale get]} {
            $scale set $value
        }
    }
}


