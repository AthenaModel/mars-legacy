#-----------------------------------------------------------------------
# TITLE:
#    marsmisc.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Jaffe
#    Jon Stinzel
#
# DESCRIPTION:
#    Mars: marsutil(n) Tcl Utilities
#
#    Miscellaneous commands
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export    \
        assert          \
        bgcatch         \
        callwith        \
        count           \
        discrete        \
        distance        \
        fstringmap      \
        getcode         \
        gettimeofday    \
        hexquote        \
        identifier      \
        ipaddress       \
        ladd            \
        ldelete         \
        let             \
        lformat         \
        lmaxlen         \
        lmerge          \
        lmove           \
        lsearchi        \
        lshift          \
        max             \
        min             \
        optval          \
	outdent         \
        percent         \
        pickfrom        \
        poisson         \
        readfile        \
        require         \
        stringToRegexp  \
        try             \
        wildToRegexp

    variable pi      [expr {acos(-1.0)}]
    variable radians [expr {$pi/180.0}]

}

#-----------------------------------------------------------------------
# Control Structures

# assert expression
#
# If the expression is not true, an assertion failure error is thrown.
proc ::marsutil::assert {expression} {
    if {[uplevel [list expr $expression]]} {
        return
    }

    return -code error -errorcode ASSERT "Assertion failed: $expression"
}

# bgcatch script
#
# script    An arbitrary Tcl script
#
# Evaluates script in the caller's context.  If the script throws
# an error, bgcatch passes the error to bgerror, and returns normally.
# bgcatch returns nothing.

proc ::marsutil::bgcatch {script} {
    set code [catch [list uplevel 1 $script] result]

    if {$code} {
        bgerror $result
    }

    return
}

# callwith prefix args...
#
# prefix     A command prefix
# args       Addition arguments
#
# Concatenates the prefix and the arguments and calls the result in
# the global scope.  The prefix is assumed to be a proper list.
#
# If the prefix is the empty list, callwith does nothing.

proc ::marsutil::callwith {prefix args} {
    if {[llength $prefix] > 0} {
        return [uplevel \#0 $prefix $args]
    }
}

# require expression message
#
# If the expression is not true, an assertion failure error is thrown
# with the specified message.
proc ::marsutil::require {expression message} {
    if {[uplevel [list expr $expression]]} {
        return
    }

    return -code error -errorcode ASSERT $message
}


# try script1 ?"finally" script2
#
# script1  A script to evaluate
# script2  A script that executes even if there are errors in the 
#          first script.
#
# Implements a try/finally construct.  Code is by Donal K Fellows; found at
# the Tcler's Wiki at http://wiki.tcl.tk/990.

proc ::marsutil::try {script1 args} {
    upvar 1 try___msg msg try___opts opts
    if {[llength $args]!=0 && [llength $args]!=2} {
        return -code error "wrong \# args: should be \"try script1 ?finally script2?\""
    }
    if {[llength $args] == 2} {
        if {[lindex $args 0] ne "finally"} {
            return -code error "mis-spelt \"finally\" keyword"
        }
    }
    set code [uplevel 1 [list catch $script1 try___msg try___opts]]
    if {[llength $args] == 2} {
        uplevel 1 [lindex $args 1]
    }
    if {$code} {
        dict incr opts -level 1
        return -options $opts $msg
    }
    return $msg
}


#-----------------------------------------------------------------------
# List functions

# lmaxlen list 
#
# Return the length of the longest string in list.

proc ::marsutil::lmaxlen {list} {
    set maxlen 0

    foreach val $list {
        set maxlen [max $maxlen [string length $val]]
    }

    return $maxlen
}

# lshift listvar
#
# Removes the first element from the list held in listvar, updates
# listvar, and returns the element.

proc ::marsutil::lshift {listvar} {
    upvar $listvar list

    set value [lindex $list 0]
    set list [lrange $list 1 end]
    return $value
}

# lsearchi list string
#
# Searches for the string in the list, using case-insensitive matching.

proc ::marsutil::lsearchi {list string} {
    for {set i 0} {$i < [llength $list]} {incr i} {
        if {[string equal -nocase [lindex $list $i] $string]} {
            return $i
        }
    }
    
    return -1
}

# lformat list fmt
#
# fmt      A [format] format string
# list     A list
#
# Applies the format string to each element in the list, returning the
# updated list.

proc ::marsutil::lformat {fmt list} {
    set result {}

    foreach item $list {
        lappend result [format $fmt $item]
    }

    return $result
}

# ladd listvar value
#
# listvar    A list variable
# value      A value
#
# If the value does not exist in listvar, it is appended.
# The new list is returned.

proc ::marsutil::ladd {listvar value} {
    upvar $listvar list1

    if {[info exists list1]} {
        set ndx [lsearch -exact $list1 $value]
        if {$ndx == -1} {
            lappend list1 $value
        }
    } else {
        set list1 [list $value]
    }

    return $list1
}

# ldelete listvar value
#
# listvar    A list variable
# value      A value
#
# If value exists in listvar, it is removed.  The new list is returned.
# If the list doesn't exist, that's OK.

proc ::marsutil::ldelete {listvar value} {
    upvar $listvar list1

    # Remove the value from the list.
    if {[info exists list1]} {
        set ndx [lsearch -exact $list1 $value]

        if {$ndx >= 0} {
            set list1 [lreplace $list1 $ndx $ndx]
        }

        return $list1
    }

    return
}

# lmerge listvar list
#
# listvar    A list variable
# list       A list
#
# Appends the elements of the list into the listvar, only if they
# aren't already present.

proc ::marsutil::lmerge {listvar list} {
    upvar $listvar dest

    if {![info exists dest]} {
        set dest [list]
    }

    foreach item [concat $dest $list] {
        set items($item) 1
    }

    set dest [array names items]

    return $dest
}


#-----------------------------------------------------------------------
# Math functions

# let varname expression
#
# varname       A variable name
# expression    An [expr] expression
#
# Evaluates the expression and assigns the value to the variable.
# 
# NOTE: libMarsutil defines this as a binary command.  Define it here
# only if the binary command doesn't exist.

if {[llength [info commands ::marsutil::let]] == 0} {

    proc ::marsutil::let {varname expression} {
        upvar $varname result
        set result [uplevel 1 [list expr $expression]]
    }

}

# min x y
#
# Compute and returns the minimum of the two numbers

proc ::marsutil::min {x y} {
    expr {($x < $y) ? $x : $y}
}

# max x y
#
# Compute and return the maximum of the two numbers.

proc ::marsutil::max {x y} {
    expr {($x > $y) ? $x : $y}
}

# gettimeofday
#
# Returns the current wallclock seconds as a decimal value;
# however, the decimal will always be ".0".
#
# NOTE: shark(1) defines this as a binary command which
# returns fractional using gettimeofday(2).  Define it
# here only if the binary command doesn't exist.

if {[llength [info commands ::marsutil::gettimeofday]] == 0} {

    proc ::marsutil::gettimeofday {} {
        expr {double([clock seconds])}
    }

}

# percent frac
#
# frac       A fractional number, 0.0 to 1.0
#
# Displays the fraction as a percentage.  If the fraction
# is at least 0.005, displays it as an integer percentage, e.g.,
# 1%, 10%, 25%.  If the fraction is <= 0.005 but greater than
# 0.0, displays it as "~0%".

proc ::marsutil::percent {frac} {
    if {$frac == 0.0} {
        return "  0%"
    } elseif {$frac <= 0.005} {
        return " ~0%"
    } else {
        return [format "%3.0f%%" [expr {100.0 * $frac}]]
    }
}

# pickfrom list
#
# list    A list
#
# Pick a random item from the list, and returns it.

proc ::marsutil::pickfrom {list} {
    lindex $list [expr {int(rand()*[llength $list])}]
}

# discrete vec
#
# vec       A vector of probabilities summing to 1.0
#
# Does a random draw for the vector of probabilities, returning an
# integer number n where 0 <= n < [llength $vec].

proc ::marsutil::discrete {vec} {
    # FIRST, get a uniform(0,1) value
    let u {rand()}

    # NEXT, find the matching value, using the CDF.
    set sum 0.0

    set len [llength $vec]

    for {set i 0} {$i < $len} {incr i} {
        let sum {$sum + [lindex $vec $i]}

        if {$u <= $sum} {
            return $i
        }
    }

    # NEXT, we shouldn't get here...but if we do, we want the
    # last bin anyway.
    return [expr {$len - 1}]
}

# poisson rate
#
# rate    The Poisson rate, events per unit of time
#
# Does a random draw, returning the number of events in one unit of time.

proc ::marsutil::poisson {rate} {
    # FIRST, generate a Uniform(0,1) value
    let T {rand()}

    # NEXT, prepare for the loop:
    set N 0
    let P {exp(-$rate)}
    set Sum $P

    while {$Sum < $T} {
        incr N
        let P {$P * $rate/$N}
        let Sum {$Sum + $P}
    }
    
    return $N
}

#-----------------------------------------------------------------------
# String functions

namespace eval ::marsutil:: {
    variable hexquoteMap \
        [list \
             \x00 {\x00} \x01 {\x01} \x02 {\x02} \x03 {\x03} \
             \x04 {\x04} \x05 {\x05} \x06 {\x06} \x07 {\x07} \
             \x08 {\x08} \x09 {\x09} \x0A {\x0A} \x0B {\x0B} \
             \x0C {\x0C} \x0D {\x0D} \x0E {\x0E} \x0F {\x0F} \
             \x10 {\x10} \x11 {\x11} \x12 {\x12} \x13 {\x13} \
             \x14 {\x14} \x15 {\x15} \x16 {\x16} \x17 {\x17} \
             \x18 {\x18} \x19 {\x19} \x1A {\x1A} \x1B {\x1B} \
             \x1C {\x1C} \x1D {\x1D} \x1E {\x1E} \x1F {\x1F} \
             \x20 {\x20} \x21 {\x21} \x22 {\x22} \x23 {\x23} \
             \x24 {\x24} \x25 {\x25} \x26 {\x26} \x27 {\x27} \
             \x28 {\x28} \x29 {\x29} \x2A {\x2A} \x2B {\x2B} \
             \x2C {\x2C} \x2D {\x2D} \x2E {\x2E} \x2F {\x2F} \
             \x30 {\x30} \x31 {\x31} \x32 {\x32} \x33 {\x33} \
             \x34 {\x34} \x35 {\x35} \x36 {\x36} \x37 {\x37} \
             \x38 {\x38} \x39 {\x39} \x3A {\x3A} \x3B {\x3B} \
             \x3C {\x3C} \x3D {\x3D} \x3E {\x3E} \x3F {\x3F} \
             \x40 {\x40} \x41 {\x41} \x42 {\x42} \x43 {\x43} \
             \x44 {\x44} \x45 {\x45} \x46 {\x46} \x47 {\x47} \
             \x48 {\x48} \x49 {\x49} \x4A {\x4A} \x4B {\x4B} \
             \x4C {\x4C} \x4D {\x4D} \x4E {\x4E} \x4F {\x4F} \
             \x50 {\x50} \x51 {\x51} \x52 {\x52} \x53 {\x53} \
             \x54 {\x54} \x55 {\x55} \x56 {\x56} \x57 {\x57} \
             \x58 {\x58} \x59 {\x59} \x5A {\x5A} \x5B {\x5B} \
             \x5C {\x5C} \x5D {\x5D} \x5E {\x5E} \x5F {\x5F} \
             \x60 {\x60} \x61 {\x61} \x62 {\x62} \x63 {\x63} \
             \x64 {\x64} \x65 {\x65} \x66 {\x66} \x67 {\x67} \
             \x68 {\x68} \x69 {\x69} \x6A {\x6A} \x6B {\x6B} \
             \x6C {\x6C} \x6D {\x6D} \x6E {\x6E} \x6F {\x6F} \
             \x70 {\x70} \x71 {\x71} \x72 {\x72} \x73 {\x73} \
             \x74 {\x74} \x75 {\x75} \x76 {\x76} \x77 {\x77} \
             \x78 {\x78} \x79 {\x79} \x7A {\x7A} \x7B {\x7B} \
             \x7C {\x7C} \x7D {\x7D} \x7E {\x7E} \x7F {\x7F} \
             \x80 {\x80} \x81 {\x81} \x82 {\x82} \x83 {\x83} \
             \x84 {\x84} \x85 {\x85} \x86 {\x86} \x87 {\x87} \
             \x88 {\x88} \x89 {\x89} \x8A {\x8A} \x8B {\x8B} \
             \x8C {\x8C} \x8D {\x8D} \x8E {\x8E} \x8F {\x8F} \
             \x90 {\x90} \x91 {\x91} \x92 {\x92} \x93 {\x93} \
             \x94 {\x94} \x95 {\x95} \x96 {\x96} \x97 {\x97} \
             \x98 {\x98} \x99 {\x99} \x9A {\x9A} \x9B {\x9B} \
             \x9C {\x9C} \x9D {\x9D} \x9E {\x9E} \x9F {\x9F} \
             \xA0 {\xA0} \xA1 {\xA1} \xA2 {\xA2} \xA3 {\xA3} \
             \xA4 {\xA4} \xA5 {\xA5} \xA6 {\xA6} \xA7 {\xA7} \
             \xA8 {\xA8} \xA9 {\xA9} \xAA {\xAA} \xAB {\xAB} \
             \xAC {\xAC} \xAD {\xAD} \xAE {\xAE} \xAF {\xAF} \
             \xB0 {\xB0} \xB1 {\xB1} \xB2 {\xB2} \xB3 {\xB3} \
             \xB4 {\xB4} \xB5 {\xB5} \xB6 {\xB6} \xB7 {\xB7} \
             \xB8 {\xB8} \xB9 {\xB9} \xBA {\xBA} \xBB {\xBB} \
             \xBC {\xBC} \xBD {\xBD} \xBE {\xBE} \xBF {\xBF} \
             \xC0 {\xC0} \xC1 {\xC1} \xC2 {\xC2} \xC3 {\xC3} \
             \xC4 {\xC4} \xC5 {\xC5} \xC6 {\xC6} \xC7 {\xC7} \
             \xC8 {\xC8} \xC9 {\xC9} \xCA {\xCA} \xCB {\xCB} \
             \xCC {\xCC} \xCD {\xCD} \xCE {\xCE} \xCF {\xCF} \
             \xD0 {\xD0} \xD1 {\xD1} \xD2 {\xD2} \xD3 {\xD3} \
             \xD4 {\xD4} \xD5 {\xD5} \xD6 {\xD6} \xD7 {\xD7} \
             \xD8 {\xD8} \xD9 {\xD9} \xDA {\xDA} \xDB {\xDB} \
             \xDC {\xDC} \xDD {\xDD} \xDE {\xDE} \xDF {\xDF} \
             \xE0 {\xE0} \xE1 {\xE1} \xE2 {\xE2} \xE3 {\xE3} \
             \xE4 {\xE4} \xE5 {\xE5} \xE6 {\xE6} \xE7 {\xE7} \
             \xE8 {\xE8} \xE9 {\xE9} \xEA {\xEA} \xEB {\xEB} \
             \xEC {\xEC} \xED {\xED} \xEE {\xEE} \xEF {\xEF} \
             \xF0 {\xF0} \xF1 {\xF1} \xF2 {\xF2} \xF3 {\xF3} \
             \xF4 {\xF4} \xF5 {\xF5} \xF6 {\xF6} \xF7 {\xF7} \
             \xF8 {\xF8} \xF9 {\xF9} \xFA {\xFA} \xFB {\xFB} \
             \xFC {\xFC} \xFD {\xFD} \xFE {\xFE} \xFF {\xFF} ]
}

# hexquote text
#
# text           A text string
#
# Quotes all characters in the string in \xNN format.  This is 
# useful for turning binary strings into printable strings.

proc ::marsutil::hexquote {text} {
    string map $::marsutil::hexquoteMap $text
}

# outdent block
#
# block     A block of text in curly braces, indented like the
#	    body of a Tcl if or while command.
#
# Outdents the block as follows:
# 
# * Removes the first and last lines.
# * Finds the length of shortest whitespace leader over all remaining 
#   lines.
# * Deletes that many characters from the beginning of each line.
# * Returns the result.

proc ::marsutil::outdent {block} {
    # FIRST, delete the leading and trailing lines.
    regsub {^ *\n} $block {} block
    regsub {\n *$} $block {} block

    # NEXT, get the length of the minimum whitespace leader.
    set minLen 100

    foreach line [split $block \n] {
	if {[regexp {^\b*$} $line]} {
	    continue
	}

	regexp {^ *} $line leader

	set len [string length $leader]

	if {$len < $minLen} {
	    set minLen $len
	}
    }

    # NEXT, delete that length at the beginning of each line.
    set pattern "^ {$minLen}"

    regsub -all -line $pattern $block {} block

    # Return the updated block.
    return $block
}

# wildToRegexp pattern
# 
# Converts a wildcard match pattern to a regular expression.  Returns
# the converted pattern.

proc ::marsutil::wildToRegexp {pattern} {

    # Neutralize regexp/grep significant characters.
    regsub -all -- {[\\]}  $pattern  &&   pattern
    regsub -all -- {[.]}   $pattern  {\.} pattern
    regsub -all -- {[+]}   $pattern  {\+} pattern
    regsub -all -- {[(]}   $pattern  {\(} pattern
    regsub -all -- {[)]}   $pattern  {\)} pattern
    regsub -all -- {[|]}   $pattern  {\|} pattern
    regsub -all -- {\^}    $pattern  {\^} pattern
    regsub -all -- {[$]}   $pattern  {\$} pattern   
    regsub -all -- {[[]}   $pattern  {\[} pattern
    regsub -all -- {[]]}   $pattern  {\]} pattern

    # Make wildcard to regexp substitutions.  These must be done last or "."s
    # will be substituted with "\."s.
    regsub -all -- {[?]}   $pattern  {.}  pattern
    regsub -all -- {[*]}   $pattern  {.*} pattern
	
    return $pattern    
}

# stringToRegexp pattern
#
# Converts a normal string to a regular expression by inserting "\"s 
# before all regexp/grep significant characters.

proc ::marsutil::stringToRegexp {pattern} {

    # Neutralize all regexp sigificant characters.
    regsub -all -- {[\\]}  $string  &&   string  
    regsub -all -- {[.]}   $string  {\.} string    
    regsub -all -- {[+]}   $string  {\+} string    
    regsub -all -- {[?]}   $string  {\?} string    
    regsub -all -- {[(]}   $string  {\(} string    
    regsub -all -- {[)]}   $string  {\)} string    
    regsub -all -- {[|]}   $string  {\|} string    
    regsub -all -- {\^}    $string  {\^} string    
    regsub -all -- {[$]}   $string  {\$} string    
    regsub -all -- {[*]}   $string  {\*} string    
    regsub -all -- {[[]}   $string  {\[} string    
    regsub -all -- {[]]}   $string  {\]} string    

    return $string    
}

# optval argvar option ?defvalue?
#
# Looks for the named option in the named variable.  If found,
# it and its value are removed from the list, and the value
# is returned.  Otherwise, the default value is returned.

proc ::marsutil::optval {argvar option {defvalue ""}} {
    upvar $argvar argv

    set ioption [lsearch -exact $argv $option]

    if {$ioption == -1} {
        return $defvalue
    }

    set ivalue [expr {$ioption + 1}]
    set value [lindex $argv $ivalue]
    
    set argv [lreplace $argv $ioption $ivalue] 

    return $value
}

#-------------------------------------------------------------------
# File Handling Utilities

# fstringmap mapping filename
#
# mapping    A dict, as for [string map]
# filename   A file name
#
# Does a [string map] on the text of the file, writing it back to
# the file.  The original contents is copied to a backup file
# called "$filename~".

proc ::marsutil::fstringmap {mapping filename} {
    # FIRST, read the text from the file
    set f [open $filename r]
    set text [read $f]
    close $f

    # NEXT, backup the file
    set backup "$filename~"
    file copy -force $filename $backup

    # NEXT, do the replacement.
    set text [string map $mapping $text]

    # NEXT, save the new text.
    set f [open $filename w]
    puts $f $text
    close $f
}

# readfile filename
#
# filename    The file name
#
# Reads the file and returns the text.  Throws the normal
# open/read errors.

proc ::marsutil::readfile {filename} {
    set f [open $filename r]

    try {
        return [read $f]
    } finally {
        close $f
    }
}

#-------------------------------------------------------------------
# Type-Definition Ensembles
#
# The following are snit type-definition types.

# identifier: a name consisting of names, letters, and underscores

snit::stringtype ::marsutil::identifier \
    -regexp {^[0-9A-Za-z_]+$}


# ipaddress: An IP Address

snit::type ::marsutil::ipaddress {
    pragma -hastypedestroy 0 -hasinstances 0 -hastypeinfo 0
        
    typemethod validate {value} {
        if {![regexp {^\d+\.\d+\.\d+\.\d+$} $value]} {
            error "invalid value \"$value\", not an IP address"
        }

        foreach num [split $value "."] { 
            if {![string is integer -strict $num]
                || $num < 0
                || $num > 255} {
                error "invalid value \"$value\", not an IP address"
            }
        }
    }
}


# count: a non-negative integer

snit::integer ::marsutil::count \
    -min 0

# distance: a non-negative floating point value.

snit::double ::marsutil::distance \
    -min 0


#-------------------------------------------------------------------
# getcode

# getcode name args
#
# name        A Tcl proc, type, or instance command name
# args        Subcommands; name must be a type or instance
#
# Returns the code for the named command or method

proc ::marsutil::getcode {name args} {
    # FIRST, get the absolute name
    set name [uplevel 1 [list namespace origin $name]]

    # NEXT, Get the type of the command
    set ctype [cmdinfo type $name]

    # NEXT, handle it based on the type
    if {$ctype in {proc wproc}} {
        # Ignore any args
        return [GetProc $name]
    } elseif {$ctype in {nse wnse}} {
        # Assume it's a Snit type or instance
        return [GetMethod $name $args]
    } else {
        error "not a proc, snit type, or snit instance: \"$name\""
    }
}

# GetProc name
#
# name          Name of a Tcl proc
#
# Returns a Tcl script that would recreate the proc.

proc ::marsutil::GetProc {name} {
    # FIRST, get the argument list
    set arglist [GetArgList $name]

    # NEXT, return the proc
    return [list proc $name $arglist [info body $name]]
    
}

# GetArgList name
#
# name       Absolute name of a Tcl proc
#
# Returns the arglist, with defaults (if any)

proc ::marsutil::GetArgList {name} {
    set result {}

    foreach arg [info args $name] {
        if {[info default $name $arg defvalue]} {
            lappend result [list $arg $defvalue]
        } else {
            lappend result $arg
        }
    }

    return $result
}

# GetMethod object subcmd
#
# object         Absolute name of a snit type or instance
# subcmd         A subcommand of the type or instance
#
# Returns a snit::method or snit::typemethod definition

proc ::marsutil::GetMethod {object subcmd} {
    # FIRST, is it an instance or a type?
    if {![catch {set objtype [$object info type]} result]} {
        # Instance
        return [GetInstanceMethod $objtype $subcmd]
    } else {
        # Is it a type?
        if {[cmdinfo exists ${object}::Snit_typeconstructor]} {
            return [GetTypeMethod $object $subcmd]
        } else {
            error "not a proc, snit type, or snit instance: \"$object\""
        }
    }
}

# GetTypeMethod objtype subcmd
#
# objtype     A snit type
# subcmd      A typemethod name
#
# Retrieves the typemethod's definition

proc ::marsutil::GetTypeMethod {objtype subcmd} {
    if {[llength $subcmd] == 1} {
        set procName "${objtype}::Snit_typemethod${subcmd}"
    } else {
        set procName "${objtype}::Snit_htypemethod[join $subcmd _]"
    }

    if {[llength [info commands $procName]] != 1} {
        error "$objtype has no typemethod called \"$subcmd\""
    }

    # Get the argument list, skipping the implicit "type" argument
    set arglist [lrange [GetArgList $procName] 1 end]

    # Get the body of the typemethod
    set body [info body $procName]

    # Remove the Snit method prolog
    regsub {^.*\# END snit method prolog\n} $body {} body

    return [list snit::typemethod $objtype $subcmd $arglist $body]
}

# GetInstanceMethod objtype subcmd
#
# objtype     A snit type
# subcmd      A method name
#
# Retrieves the method's definition

proc ::marsutil::GetInstanceMethod {objtype subcmd} {
    if {[llength $subcmd] == 1} {
        set procName "${objtype}::Snit_method${subcmd}"
    } else {
        set procName "${objtype}::Snit_hmethod[join $subcmd _]"
    }

    if {[llength [info commands $procName]] != 1} {
        error "$objtype has no method called \"$subcmd\""
    }

    # Get the argument list, skipping the implicit "type" argument
    set arglist [lrange [GetArgList $procName] 4 end]

    # Get the body of the typemethod
    set body [info body $procName]

    # Remove the Snit method prolog
    regsub {^.*\# END snit method prolog\n} $body {} body

    return [list snit::method $objtype $subcmd $arglist $body]
}


