#-----------------------------------------------------------------------
# TITLE:
#    gradient.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    gui(n) Module: Color Gradient Computer
#
#    This module defines the "gradient" type, which is used to compute
#    color gradients, linear interpolations between two colors.  
#    A gradient is defined by its endpoints and by a min and max
#    input level.  Then, given an input level a gradient object computes
#    an output color in which R, G, and B are each interpolated
#    separately.
#
#-----------------------------------------------------------------------

namespace eval ::gui:: {
    namespace export gradient
}

#-----------------------------------------------------------------------
# gradient

snit::type ::gui::gradient {
    #-------------------------------------------------------------------
    # Options

    # -mincolor
    #
    # A hexadecimal color string, e.g., "#FFFFFF"
    
    option -mincolor -default "#FFFFFF" -configuremethod ConfigMinColor

    method ConfigMinColor {opt val} {
        set options($opt) $val

        scan $val "#%2x%2x%2x" min(r) min(g) min(b)
    }

    # -maxcolor
    #
    # A hexadecimal color string, e.g., "#000000"

    option -maxcolor -default "#000000" -configuremethod ConfigMaxColor

    method ConfigMaxColor {opt val} {
        set options($opt) $val

        scan $val "#%2x%2x%2x" max(r) max(g) max(b)
    }

    # -minlevel
    #
    # The minimum input level

    option -minlevel -default 0.0

    # -maxlevel
    #
    # The maximum input level
    
    option -maxlevel -default 0.0

    #-------------------------------------------------------------------
    # Instance variables

    # Array of hex components of -mincolor
    variable min -array {
        r    0xFF
        g    0xFF
        b    0xFF
    }

    # Array of hex components of -maxcolor
    variable max -array {
        r    0x00
        g    0x00
        b    0x00
    }

    #-------------------------------------------------------------------
    # Public Methods

    # color level
    #
    # level    An input level
    #
    # Given an input level between -minlevel and -maxlevel, produces
    # an output color between -mincolor and -maxcolor

    method color {level} {
        # FIRST, compute the level fraction
        set frac \
            [expr {double($level - $options(-minlevel))/ \
                   double($options(-maxlevel) - $options(-minlevel))}]     

        # NEXT, interpolate the three color channels separately.
        foreach c [list r g b] {
            if {$min($c) == $max($c)} {
                set out($c) $min($c)
            } else {
                set out($c) \
                    [expr {int($min($c) + $frac*($max($c) - $min($c)))}]
            }
        }

        set hexrgb [expr {($out(r) << 16) + ($out(g) << 8) + $out(b)}]

        return [format "#%06X" $hexrgb]
    }
}



