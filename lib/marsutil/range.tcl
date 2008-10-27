#-----------------------------------------------------------------------
# TITLE:
#	range.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       JNEM: util(n) module: range types
#
#	A range type is a range of numeric values, min to max.
#       A particular value belongs to the type if it is
#       numeric and falls within the bounds.
#
#       Note that a range type object does not store individual values;
#       rather, it defines the set of valid values.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::util:: {
    namespace export range
}

#-----------------------------------------------------------------------
# range ADT

snit::type ::util::range {
    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::util::*
    }

    #-------------------------------------------------------------------
    # Options

    option -min    {}       ;# Minimum numeric value
    option -max    {}       ;# Maximum numeric value
    option -format "%4.2g"  ;# Standard output format for values.


    #-------------------------------------------------------------------
    # Constructor
    
    # Default constructor

    #-------------------------------------------------------------------
    # Public Methods

    # validate input
    #
    # Converts the input into a valid value; if the input is numeric and
    # within the valid range, it is returned unchanged; otherwise
    # an error is thrown.
    method validate {input} {
        # FIRST, is it numeric?  Throw an error or return the value.
        if {![string is double -strict $input] ||
            ![$self inrange $input]} {
            error "Out of range: \"$input\""
        }

        return $input
    }

    # value input
    #
    # Same as validate; included for consistency with quality types.
    method value {input} {
        return [$self validate $input]
    }
    

    # format value
    #
    # Formats arbitrary numeric values to the precision and width
    # which is standard for this range.
    method format {value} {
        assert {[string is double -strict $value]}
        format $options(-format) $value
    }

    # clamp value
    #
    # Clamps value within the min and max range.
    method clamp {value} {
        if {$options(-min) ne "" &&
            $value < $options(-min)} {
            return $options(-min)
        }

        if {$options(-max) ne "" &&
            $value > $options(-max)} {
            return $options(-max)
        }

        return $value
    }

    # inrange value
    #
    # Tests whether the value is within the -min and -max, inclusive.
    method inrange {value} {
        if {$options(-min) ne "" &&
            $value < $options(-min)} {
            return 0
        }

        if {$options(-max) ne "" &&
            $value > $options(-max)} {
            return 0
        }

        return 1
    }
}