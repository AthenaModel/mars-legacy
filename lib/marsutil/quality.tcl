#-----------------------------------------------------------------------
# TITLE:
#	quality.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Mars: marsutil(n) module: quality objects
#
#	A quality is a rating scale that relates names to specific 
#	numeric values.  Each value in fact has two names: a long name
#       and a short name, e.g., "Very Good" and "VG".  The quality
# 	object can convert names to numeric values; it can also convert
#       arbitrary numeric values back to long or short names.
#
#       Note that a quality object does not store individual values;
#       rather, it defines the set of values for the quality.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::marsutil:: {
    namespace export quality
}

#-----------------------------------------------------------------------
# quality ADT

snit::type ::marsutil::quality {
    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Options
    
    option -bounds no       ;# If yes, bounds are specified for each
                             # quality level.
    option -min    {}       ;# Minimum numeric value
    option -max    {}       ;# Maximum numeric value
    option -format "%4.2g"  ;# Standard output format for values.

    #-------------------------------------------------------------------
    # Instance variables:

    # The elements in these lists correspond.
    variable shortnames {}  ;# List of short names
    variable longnames  {}  ;# List of long names
    variable mins       {}  ;# List of minimum bounds, -bounds yes
    variable values     {}  ;# List of numeric values
    variable maxs       {}  ;# List of maximum bounds, -bounds yes

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {deflist args} {
        $self configurelist $args

        if {$options(-bounds)} {
            # The "deflist" is a list of 5-tuples:
            # short long min value max
            foreach {short long min value max} $deflist {
                lappend shortnames $short
                lappend longnames $long
                lappend mins $min
                lappend values $value
                lappend maxs $max
            }

            # Compute -min and -max explicitly
            set options(-min) [lindex $mins 0]
            set options(-max) [lindex $maxs 0]

            set len [llength $values]

            for {set i 1} {$i < $len} {incr i} {
                if {[lindex $mins $i] < $options(-min)} {
                    set options(-min) [lindex $mins $i]
                }

                if {[lindex $maxs $i] > $options(-max)} {
                    set options(-max) [lindex $maxs $i]
                }
            }
        } else {
            # The "deflist" is a list of triples: short long value
            foreach {short long value} $deflist {
                lappend shortnames $short
                lappend longnames $long
                lappend values $value
            }
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Deprecated method names
    delegate method shortname  using {%s name}
    delegate method shortnames using {%s names}

    # size
    #
    # Returns the number of categories.
    method size {} {
        return [llength $shortnames]
    }

    # value input
    #
    # Converts the input into a valid value; if the input is numeric and
    # within the valid range, it is returned unchanged.  Otherwise, 
    # the specific value associated with a given long or short name
    # is returned.  Throws an error if there's no match.
    method value {input} {
        set ndx [$self index $input]

        # FIRST, is it numeric?  Throw an error or return the value.
        if {[string is double -strict $input]} {
            if {$ndx == -1} {
                error "Out of range: \"$input\""
            }

            return $input
        }

        # NEXT, it's symbolic.  Throw an error or return the value
        # the corresponds exactly to the symbol.
        if {$ndx == -1} {
            error "Unknown name: \"$input\""
        }

        return [lindex $values $ndx]
    }

    # strictvalue input
    #
    # Retrieve specific value given long or short name, or arbitrary value.
    # Throws an error if there's no match.
    method strictvalue {input} {
        set ndx [$self index $input]

        if {$ndx == -1} {
            if {[string is double -strict $input]} {
                error "Out of range: \"$input\""
            } else {
                error "Unknown name: \"$input\""
            }
        } else {
            return [lindex $values $ndx]
        }
    }

    # validate input
    #
    # Validates that the input is a valid quality value.  If it is, it is
    # returned unchanged; otherwise an error is thrown.
    
    method validate {input} {
        set ndx  [$self index $input]

        if {$ndx == -1} {
            error "invalid value, \"$input\""
        }

        return $input
    }


    # name input
    #
    # Retrieve the short name corresponding to the long name or value,
    # or "" if there's no match.
    method name {input} {
        set ndx [$self index $input]

        if {$ndx == -1} {
            return ""
        } else {
            return [lindex $shortnames $ndx]
        }
    }
    
    # longname input
    #
    # Retrieve the long name corresponding to the short name or value, or
    # "" if there's no match.
    method longname {input} {
        set ndx [$self index $input]

        if {$ndx == -1} {
            return ""
        } else {
            return [lindex $longnames $ndx]
        }
    }

    # index input
    # 
    # Returns the index corresponding to the name, long name, or value.
    # Returns -1 if there's no match.
    method index {input} {
        # FIRST, is it a short name?
        set ndx [lsearchi $shortnames $input]

        if {$ndx != -1} {
            return $ndx
        }

        # NEXT, is it a long name?
        set ndx [lsearchi $longnames $input]

        if {$ndx != -1} {
            return $ndx
        }

        # NEXT, is it a number?
        if {[string is double -strict $input] &&
            [$self inrange $input]} {
            return [$self Value2index $input]
        }

        # NEXT, it's an error
        return -1
    }


    # format value
    #
    # Formats arbitrary numeric values to the precision and width
    # which is standard for this quality.
    method format {value} {
        assert {[string is double -strict $value]}
        format $options(-format) $value
    }

    # names
    #
    # Returns a list of the short names.
    method names {} {
        return $shortnames
    }

    # longnames
    #
    # Returns a list of the long names.
    method longnames {} {
        return $longnames
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

    #-------------------------------------------------------------------
    # Documentation

    # html
    #
    # Returns a snippet of HTML suitable for inclusion in a man page.

    method html {} {
        append out "<table>\n"

        append out "<tr>\n"
        append out "<th align=\"left\">Name</th>\n"
        append out "<th align=\"left\">Long Name</th>\n"
        append out "<th align=\"right\">Value</th>\n"

        if {$options(-bounds)} {
            append out "<th align=\"right\">Bounds</th>\n"
        }
        append out "</tr>\n"

        set len [llength $values]

        for {set i 0} {$i < $len} {incr i} {
            append out "<tr>\n"
            append out \
                "<td align=\"left\"><tt>[lindex $shortnames $i]</tt></td>\n"
            append out "<td align=\"left\">[lindex $longnames $i]</td>\n"
            append out "<td align=\"right\">[lindex $values $i]</td>\n"

            if {$options(-bounds)} {
                append out "<td align=\"right\">"
                append out [lindex $mins $i]
                append out " &lt; <i>value</i> &le; "
                append out [lindex $maxs $i]
                append out "</td>\n"
            }

            append out "</tr>\n"
        }

        append out "</table>\n"

        return $out
    } 

    #-------------------------------------------------------------------
    # Private Methods 


    # Value2index value
    #
    # If -bounds no, compares value to each entry in the values list, 
    # and returns the index of the closest match.  If -bounds yes,
    # then returns the index of the first range which contains the
    # value.
    method Value2index {value} {
        set len [llength $values]

        if {$options(-bounds)} {
            for {set i 0} {$i < $len} {incr i} {
                if {$value >= [lindex $mins $i] &&
                    $value <= [lindex $maxs $i]} {
                    return $i
                }
            }

            # Error, no match
            return -1
        } else {
            # Find the closest match, and return its index.
            set minIndex 0
            set minDiff [expr {abs($value - [lindex $values 0])}]

            for {set i 1} {$i < $len} {incr i} {
                set diff [expr {abs($value - [lindex $values $i])}]

                if {$diff < $minDiff} {
                    set minDiff $diff
                    set minIndex $i
                }
            }

            return $minIndex
        }
   }
}



