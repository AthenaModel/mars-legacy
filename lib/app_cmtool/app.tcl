#-----------------------------------------------------------------------
# FILE: app.tcl
#
# Main Application Module
#
# PACKAGE:
#   app_cmtool(n) -- mars_cmtool(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: app
#
# This module defines app, the application ensemble.  app contains
# the application start-up code, as well a variety of subcommands
# available to the application as a whole.  To invoke the 
# application,
#
# > package require app_cmtool
# > app init $argv
#
# Note that app_cmtool is usually invoked by mars(1).

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Look-up Tables

    # Type Variable: appname
    #
    # This is the name of the application, for use in usage strings.

    typevariable appname "mars cmtool"

    # Type Variable: help
    #
    # This is an array of mars_cmtool(1) subcommands, with a 
    # brief help string for each.

    typevariable help -array {
        check     "Model sanity check"
        dump      "Dump initial cell values and formulas"
        help      "This help."
        run       "Run several cases of the model."
        solve     "Solve the model."
        xref      "Cross-reference of cell dependencies."
    }

    #-------------------------------------------------------------------
    # Group: Application Initialization

    # Type method: init
    #
    # Initializes the application, and executes the selected subcommand.
    #
    # Syntax:
    #   app init _argv_
    #
    #   argv - Command line arguments

    typemethod init {argv} {
        # FIRST, if there are no arguments, do help.
        if {[llength $argv] == 0} {
            $type Cmd_help {}
            exit
        }

        # NEXT, create the cellmodel
        cellmodel ::cs

        # NEXT, execute the subcommand.
        set sub [lshift argv]

        if {![info exists help($sub)]} {
            puts "No such subcommand: \"$sub\""
            puts "Try \"mars cmtool help\"."
            exit
        }

        $type Cmd_$sub $argv
    }

    #-------------------------------------------------------------------
    # Group: help subcommand
    #
    # Displays the <help> text for the full list of subcommands.
    #
    # Syntax:
    #   help
    
    # Type method: Cmd_help
    #
    # Implements the "help" subcommand.
    #
    # Syntax:
    #   Cmd_help _argv_
    #
    #   argv - The remainder of the command line.

    typemethod Cmd_help {argv} {
        # FIRST, get the argument list.
        if {[llength $argv] != 0} {
            puts "Usage: $appname help"
            exit
        }

        # NEXT, format and display the help information.
        set wid [lmaxlen [array names help]]

        puts "cmtool subcommands:\n"

        foreach sub [lsort [array names help]] {
            puts [format "   %-*s  %s" $wid $sub $help($sub)]
        }
    }

    #-------------------------------------------------------------------
    # Group: check subcommand
    #
    # Loads a model, and outputs the results of the model sanity check.
    #
    # Syntax:
    #   check _filename_

    # Type method: Cmd_check
    #
    # Implements the "check" subcommand.
    #
    # Syntax:
    #   Cmd_check _argv_
    #
    #   argv - The remainder of the argument list.

    typemethod Cmd_check {argv} {
        # FIRST, get the argument.
        if {[llength $argv] != 1} {
            puts "Usage: $appname check filename.cm"
            exit
        }

        # NEXT, Load the model.
        $type LoadModel [lshift argv]

        # NEXT, output the results in human-readable form.
        set sections [list]

        # Basic info about each page.
        if {[cs sane]} {
            set out ""
            foreach page [cs pages] {
                if {[cs pageinfo cyclic $page]} {
                    append out "Page \"$page\" is cyclic.\n"
                } else {
                    append out "Page \"$page\" is acyclic.\n"
                }
            }

            lappend sections $out
        }

        # Defined but not referenced.
        if {[llength [cs cells unused]] > 0} {
            set out "The following cells are defined but not referenced:\n"

            foreach cell [cs cells unused] {
                append out "    $cell\n"
            }

            lappend sections $out
        }

        

        # Referenced but not defined.
        if {[llength [cs cells unknown]] > 0} {
            set out "The following cells are referenced but not defined:\n"

            foreach cell [cs cells unknown] {
                set refcount [llength [cs cellinfo usedby $cell]]

                append out [format "    %3d refs: %s\n" \
                                $refcount $cell]
            }

            lappend sections $out
        }

        # Invalid cells
        if {[llength [cs cells invalid]] > 0} {
            set out "The following cells have serious errors:\n"

            foreach cell [cs cells invalid] {
                append out [format "  %s = \"%s\"\n" $cell [cs formula $cell]]

                if {[cs cellinfo error $cell] ne ""} {
                    append out \
                        "      => [normalize [cs cellinfo error $cell]]\n"
                }

                foreach rcell [cs cellinfo unknown $cell] {
                    append out \
                        "      => References undefined cell: $rcell\n"
                }

                foreach rcell [cs cellinfo badpage $cell] {
                    append out \
                        "      => References cell on later page: $rcell\n"
                }
            }

            lappend sections $out
        }

        # Sanity
        if {[cs sane]} {
            lappend sections "The model is sane.\n"
        } else {
            lappend sections "The model is not sane.\n"
        }

        set result [join $sections \n]

        puts $result
    }

    #-------------------------------------------------------------------
    # Group: xref subcommand
    #
    # Loads a model, and outputs a cross-reference of the cells that
    # reference each cell.
    #
    # Syntax:
    #   xref _filename_

    # Type method: Cmd_xref
    #
    # Implements the "xref" subcommand.
    #
    # Syntax:
    #   Cmd_xref _argv_
    #
    #   argv - The remainder of the argument list.

    typemethod Cmd_xref {argv} {
        # FIRST, get the argument.
        if {[llength $argv] != 1} {
            puts "Usage: $appname xref filename.cm"
            exit
        }

        # NEXT, dump it and output the result.
        $type LoadModel [lshift argv]

        # NEXT, output the results in human-readable form.
        set wid [lmaxlen [cs cells]]
        puts [format "%-*s    Is used by these cells" $wid Cell]
        foreach cell [cs cells] {
            puts [format "%-*s => %s" $wid $cell \
                      [cs cellinfo usedby $cell]]
        }
    }

    #-------------------------------------------------------------------
    # Group: dump subcommand
    #
    # Loads a model, and dumps each cell, value, and formula in human
    # readable form.  If desired, outputs only a single page.
    #
    # Syntax:
    #   dump _filename_ ?-page _page_?

    # Type method: Cmd_dump
    #
    # Implements the "dump" subcommand.
    #
    # Syntax:
    #   Cmd_dump _argv_
    #
    #   argv - The remainder of the argument list.

    typemethod Cmd_dump {argv} {
        # FIRST, get the file name.
        if {[llength $argv] == 0} {
            puts "Usage: $appname dump filename.cm ?-page page?"
            exit
        }

        set filename [lshift argv]

        # NEXT, get the options
        array set opts {
            -page all
        }

        while {[llength $argv] > 0} {
            set opt [lshift argv]

            switch -exact -- $opt {
                -page {
                    set opts(-page) [lshift argv]
                }

                default {
                    puts "Unknown option: \"$opt\""
                    exit 1
                }
            }
        }

        # NEXT, dump it and output the result.
        $type LoadModel $filename

        if {$opts(-page) ni [concat all [cs pages]]} {
            puts "No such page in model: \"$opts(-page)\""
        }

        puts [cs dump $opts(-page)]

        if {![cs sane]} {
            puts "Error, model is not sane.  Run \"cs check\" for details."
        }
    }

    #-------------------------------------------------------------------
    # Group: run subcommand
    #
    # Solves the model contained in _filename_ multiple times, once for
    # each "-case".  Each case consists of a name, used in the output,
    # and zero or more cell/value pairs.  The output is displayed in
    # parallel columns.
    #
    # Syntax:
    #   run _filename ?options?_
    #
    # Options:
    #   -epsilon value              - Epsilon for solution
    #   -maxiters value             - Max number of iterations
    #   -case name ?cell value....? - Specifies a case.

    # Type method: Cmd_run
    #
    # Implements the "run" subcommand.
    #
    # Syntax:
    #   Cmd_run _argv_
    #
    #   argv - The remainder of the argument list.

    typemethod Cmd_run {argv} {
        # FIRST, get the argument.
        if {[llength $argv] == 0} {
            puts "Usage: $appname run filename.cm ?options...?"
            exit
        }

        # NEXT, load it
        $type LoadModel [lshift argv]

        if {![cs sane]} {
            puts "Error, model is not sane.  Run \"cs check\" for details."
            exit 1
        }

        # NEXT, get the cellname width
        set wid [lmaxlen [cs cells]]

        # NEXT, get the options
        set cases [list]
        set epsilon  [cs cget -epsilon]
        set maxiters [cs cget -maxiters]

        while {[llength $argv] > 0 } {
            set opt [lshift argv]

            switch -exact -- $opt {
                -epsilon { 
                    set epsilon \
                        [validate "$opt:" ::epsilon [lshift argv]]
                }

                -maxiters { 
                    set maxiters \
                        [validate "$opt:" ::maxiters [lshift argv]]
                }

                -case {
                    set case [lshift argv]

                    require {$case ne ""} "$opt: Invalid case name: \"\""
                    require {$case ni $cases} \
                        "$opt: Duplicate case name: \"$case\""

                    lappend cases $case
                    set casedict($case) [dict create]

                    puts "Case: $case"

                    while {[llength $argv] > 0 &&
                           ![string match "-*" [lindex $argv 0]]} {

                        set cell [lshift argv]
                        set value [lshift argv]

                        require {$cell in [cs cells]} \
                            "-case $case: Unknown cell: \"$cell\""
                    
                        require {[string is double -strict $value]} \
                            "-case $case: Not a numeric value: \"$value\""
                        
                        dict set casedict($case) $cell $value

                        puts [format "    %-*s %s" $wid $cell $value]
                    }
                }
            }
        }

        # NEXT, configure the cell model.

        cs configure \
            -epsilon  $epsilon  \
            -maxiters $maxiters

        # NEXT, solve each of the cases.
        foreach case $cases {
            # FIRST, reset the model to its initial values, and apply
            # the case's parameters.
            cs reset
            cs set $casedict($case)

            # NEXT, solve it and save the result.
            set result($case) [cs solve]
            if {$result($case) eq "ok"} {
                set values($case) [cs get]
            }
        }

        # NEXT, output the results.
        puts ""
        section "Results for each case"

        puts -nonewline [format "%-*s" $wid "Cell"]

        foreach case $cases {
            puts -nonewline [format " %12s" $case]
        }

        puts ""

        puts -nonewline [string repeat - $wid]

        foreach case $cases {
            puts -nonewline " [string repeat - 12]"
        }

        puts ""

        foreach cell [cs cells] {
            # FIRST, output the cell name.
            puts -nonewline [format "%-*s" $wid $cell]

            set old ""

            # NEXT, do each case.
            foreach case $cases {
                # If there's an error result, print that in the space.
                # Otherwise, print the cell value.
                if {$result($case) ne "ok"} {
                    set new [format " %12s" $result($case)]
                } else {
                    set new [format " %12g" [dict get $values($case) $cell]]
                }

                if {$new eq $old} {
                    puts -nonewline [format " %12s" " "]
                } else {
                    puts -nonewline $new
                    set old $new
                }


            }

            puts ""
        }
    }


    #-------------------------------------------------------------------
    # Group: solve subcommand
    #
    # Solves the model once, outputting a variety of detailed information
    # about the results and the process of computation.
    #
    # Syntax:
    #   solve _filename ?options?_
    #
    # There are two sets of options.  The first set apply to the run as
    # a whole:
    #
    #  -epsilon epsilon - Epsilon for solution; defaults to 0.0001
    #  -maxiters num    - Max number of iterations; defaults to 100
    #  -dumpstart       - Output dump of starting cell values and 
    #                     formulas.
    #  -dumpfinal       - Output dump of final cell values and formulas.
    #  -diffpages a b   - Dumps a comparison of the final values of two 
    #                     pages a and b.
    #
    # The remaining options apply only to cyclic pages.  The value of
    # each is the name of a cyclic page; each can be repeated to produce
    # the output for multiple pages.
    # 
    #  -logiters page    - Log iteration deltas
    #  -dumpiters page   - Dump values for each iteration, as for "dump".
    #  -tracevalues page - Prints out a trace of cell values by iteration 
    #                      for the first and last few iterations.
    #  -tracedeltas page - Prints out a trace of cell value deltas by 
    #                      iteration for the first and last few iterations.

    # Type Variable: opts
    #
    # Array of command-line options for the <solve subcommand>.
    typevariable opts -array {}

    # Type Variable: idelta
    #
    # Iteration delta for the <solve subcommand>.
    typevariable idelta 0.0

    # Type Variable: snap
    #
    # Array of model snapshots, by iteration number, for the 
    # <solve subcommand>.
    typevariable snap -array {}

    # Type Variable: convergence
    # 
    # List of convergence messages for the cyclic pages, for the
    # <solve subcommand>.
    typevariable convergence

    # Type method: Cmd_solve
    #
    # Implements the "solve" subcommand.
    #
    # Syntax:
    #   Cmd_solve _argv_
    #
    #   argv - The remainder of the argument list.

    typemethod Cmd_solve {argv} {
        # FIRST, get the argument.
        if {[llength $argv] == 0} {
            puts "Usage: $appname solve filename.cm ?options...?"
            exit
        }

        # NEXT, load it
        $type LoadModel [lshift argv]

        if {![cs sane]} {
            puts "Error, model is not sane.  Run \"cs check\" for details."
            exit 1
        }

        # NEXT, get the options
        array set opts {
            -dumpstart   0
            -dumpfinal   0
            -diffpages   {}
            -logiters    {}
            -dumpiters   {}
            -tracevalues {}
            -tracedeltas {}
        }
        set opts(-epsilon)  [cs cget -epsilon]
        set opts(-maxiters) [cs cget -maxiters]

        while {[llength $argv] > 0 } {
            set opt [lshift argv]

            switch -exact -- $opt {
                -epsilon { 
                    set opts($opt) \
                        [validate "$opt:" ::epsilon [lshift argv]]
                }

                -maxiters { 
                    set opts($opt) \
                        [validate "$opt:" ::maxiters [lshift argv]]
                }

                -set {
                    set cell [lshift argv]
                    set value [lshift argv]

                    require {$cell in [cs cells]} \
                        "-set: Unknown cell: \"$cell\""
                    
                    require {[string is double -strict $value]} \
                        "-set: Not a numeric value: \"$value\""

                    puts "let $cell = $value"
                    cs set [list $cell $value]
                }

                -dumpstart -
                -dumpfinal { 
                    set opts($opt) 1 
                }

                -diffpages {
                    set pa [lshift argv]
                    set pb [lshift argv]

                    if {$pa ni [cs pages]} {
                        puts "$opt: unknown page, \"$pa\""
                        exit 1
                    }

                    if {$pb ni [cs pages]} {
                        puts "$opt: unknown page, \"$pb\""
                        exit 1
                    }

                    lappend opts(-diffpages) [list $pa $pb]
                }

                -logiters    -
                -dumpiters   -
                -tracevalues - 
                -tracedeltas {
                    set page [lshift argv]
                    
                    if {$page ni [cs pages]} {
                        puts "$opt: unknown page, \"$page\""
                        exit 1
                    }

                    if {![cs pageinfo cyclic $page]} {
                        puts "$opt: page isn't cyclic, \"$page\""
                        exit 1
                    }

                    lappend opts($opt) $page
                }

                default {
                    puts "Invalid option: \"$opt\""
                    exit 1
                }
            }
        }

        # NEXT, if no final outputs are specified, print the results.
        if {!$opts(-dumpstart)        &&
            !$opts(-dumpfinal)        &&
            $opts(-logiters)    eq "" &&
            $opts(-dumpiters)   eq "" &&
            $opts(-tracevalues) eq "" &&
            $opts(-tracedeltas) eq "" &&
            $opts(-diffpages)   eq ""
        } {
            set opts(-dumpfinal) 1
        }

        # NEXT, -dumpstart
        if {$opts(-dumpstart)} {
            section "Initial Model"
            puts [cs dump]
            puts ""
        }
        
        # NEXT, solving
        section "Solving, -epsilon $opts(-epsilon) -maxiters $opts(-maxiters)"

        cs configure \
            -epsilon  $opts(-epsilon)  \
            -maxiters $opts(-maxiters) \
            -tracecmd [mytypemethod Trace]

        set convergence [list]

        set result [cs solve]

        # NEXT, -dumpfinal
        if {$opts(-dumpfinal)} {
            section "Final Model"

            puts [cs dump]
            puts ""
        }

        # NEXT, -diffpages
        foreach pair $opts(-diffpages) {
            lassign $pair pa pb
            section "Comparison: Pages \"$pa\" and \"$pb\""
            puts [$type DiffPages $pa $pb]
        }

        # NEXT, output the result.  Print out the convergence messages
        # for those pages that converges; then, note any errors.
        
        if {[llength $convergence] > 0} {
            puts [join $convergence \n]
        }

        switch -exact -- [lindex $result 0] {
            diverge {
                puts "Page \"[lindex $result 1]\" diverged after $opts(-maxiters) iterations"
                $type OutputTrace [lindex $result 1] $opts(-maxiters)
            }

            errors {
                puts "Page \"[lindex $result 1]\" contains errors:"
                
                set wid [lmaxlen [cs cells error]]

                foreach cell [cs cells error] {
                    puts [format "%-*s => %s" $wid $cell \
                              [normalize [cs cellinfo error $cell]]]
                }

                $type OutputTrace [lindex $result 1] $opts(-maxiters)
            }

            ok {
                puts "ok"
            }
        }
    }

    # Type method: DiffPages
    #
    # Returns output comparing the values of identically named 
    # cells on two pages.
    #
    # Syntax:
    #   DiffPages _pa pb_
    #
    #   pa - Name of the first page
    #   pb - Name of the second page

    typemethod DiffPages {pa pb} {
        # FIRST, accumulate the output.
        set out ""
        
        # NEXT, get page a's cell values
        array set avalues [cs get $pa -bare]
        set wid [lmaxlen [array names avalues]]

        # NEXT, iterate over page b's values, outputting 
        # those cells that also exist in A.

        append out [format "%-*s  %12s  %12s\n" \
                        $wid "Cell" "${pa}::" "${pb}::"]
        
        foreach {cell value} [cs get $pb -bare] {
            # FIRST, if there's no matching cell in pa, skip it.
            if {![info exists avalues($cell)]} {
                continue
            }

            set aval [format %12g $avalues($cell)]
            set bval [format %12g $value]

            if {$aval eq $bval} {
                set bval ""
            }

            # NEXT, save it.
            append out [format "%-*s  %12s  %12s\n" \
                            $wid $cell $aval $bval]
        }

        return $out
    }
    

    # Type method: Trace iterate
    #
    # This method is called on each iteration of each cyclic page.
    #
    # Syntax:
    #   Trace iterate _page i maxdelta maxcell_
    #
    #   page      - The page being iterated
    #   i         - The iteration number, 0 through N
    #   maxdelta  - The iteration's maxdelta
    #   maxcell   - The cell for which the maxdelta was computed

    typemethod "Trace iterate" {page i maxdelta maxcell} {
        # FIRST, if iteration is 0, throw away any results for
        # the previous page.
        if {$i == 0} {
            array unset snap
            set snap(0) [cs get $page]
            set idelta $maxdelta
            return
        }

        # NEXT, save the current values
        set snap($i) [cs get $page]

        # NEXT, get the old and new ideltas.
        set old $idelta
        set idelta $maxdelta

        # NEXT, if iterations are logged for this page, do so.
        if {$page in [concat $opts(-logiters) $opts(-dumpiters)]} {
            if {$old != 0.0} {
                let delta {($idelta-$old)/$old}
                set delta [format %g $delta]
            } else {
                set delta "N/A"
            }
            puts "$page, Iteration $i: maxdelta=[format %g $idelta] on $maxcell ($delta)"
        }

        # NEXT, if iterations are being dumped for this page, do so.
        if {$page in $opts(-dumpiters)} {
            puts [cs dump $page]
        }
    }
    
    # Type method: Trace converge
    #
    # This method is called for each cyclic page that converges.
    #
    # Syntax:
    #   Trace converge _page num_
    #
    #   page - The page name
    #   num  - The number of iterations
    
    typemethod "Trace converge" {page num} {
        # FIRST, skip acyclic pages
        if {![cs pageinfo cyclic $page]} {
            return
        }

        # NEXT, save the convergence message.
        lappend convergence "Page \"$page\" converged after $num iterations."

        # NEXT, do any tracing of this page.
        $type OutputTrace $page $num
    }

    # Type method: Trace diverge
    #
    # This method is called for cyclic pages that diverge.
    #
    # Syntax:
    #   Trace diverge _page_
    #
    #   page - The page name
    
    typemethod {Trace diverge} {page} {

        puts "Page \"$page\" diverged after $opts(-maxiters) iterations"

        # NEXT, do any tracing of this page.
        $type OutputTrace $page $opts(-maxiters)
    }


    # Type method: OutputTrace
    #
    # Outputs the -tracevalues and -tracedeltas information for a page.
    #
    # Syntax:
    #   OutputTrace _page num_
    #
    #   page - The page name
    #   num  - The iteration number

    typemethod OutputTrace {page num} {
        # FIRST, return unless we're tracing something.
        if {$page ni [concat $opts(-tracevalues) $opts(-tracedeltas)]} {
            return
        }

        # NEXT, Determine the set of iterations for which we want to 
        # output results.
        set iters [list 0]

        for {set i 1} {$i <= $num && $i <= 3} {incr i} {
            lappend iters $i
        }

        for {set i [expr {$num - 2}]} {$i <= $num} {incr i} {
            if {$i ni $iters} {
                lappend iters $i
            }
        }

        # NEXT, get the width of the longest cell name.
        set wid [lmaxlen [dict key $snap(0)]]

        # NEXT, if -tracevalues, print out a trace of the page's values.
        if {$page in $opts(-tracevalues)} {
            section "Page \"$page\": Cell Results by Iteration"

            puts -nonewline [format "%-*s  " $wid "Results:"]
                
            foreach i $iters {
                puts -nonewline [format " %12s" "Iteration $i"]
            }

            puts ""

            foreach cell [dict keys $snap(0)] {
                puts -nonewline [format "%-*s =" $wid $cell]

                set new [format " %12g" [dict get $snap(0) $cell]]
                puts -nonewline [format " %12g" $new]

                foreach i [lrange $iters 1 end] {
                    set old $new
                    set new [format " %12g" [dict get $snap($i) $cell]]

                    if {$new ne $old} {
                        puts -nonewline $new
                    } else {
                        puts -nonewline [format " %12s" ""]
                    }
                }
                puts ""
            }
            
            puts ""
        }


        # NEXT, if -tracedeltas, print out a trace of the page's deltas.
        if {$page in $opts(-tracedeltas)} {
            section "Page \"$page\": Cell Deltas by Iteration"

            puts -nonewline [format "%-*s  " $wid "Deltas:"]
                
            foreach i $iters {
                puts -nonewline [format " %12s" "Iteration $i"]
            }

            puts ""

            foreach cell [dict keys $snap(0)] {
                puts -nonewline [format "%-*s =" $wid $cell]
                
                set new [dict get $snap(0) $cell]
                puts -nonewline [format " %12g" $new]

                foreach i [lrange $iters 1 end] {
                    set old $new
                    set new [dict get $snap($i) $cell]
                    
                    puts -nonewline [format " %12g" [expr {$new - $old}]]
                }
                puts ""
            }
            
            puts ""
        }
    }


    #-------------------------------------------------------------------
    # Group: Utility Routines

    # Type Method: LoadModel
    #
    # Loads the model from the named file into the cellmodel(n) object.
    #
    # Syntax:
    #   LoadModel _filename_
    #
    #   filename - The name of the model file

    typemethod LoadModel {filename} {
        if {[catch {
            cs load [readfile $filename]
        } result]} {
            puts "Error reading model: $result"
            puts "$::errorInfo"
            exit 1
        }
    }

    # Proc: validate
    #
    # Validates a _value_ using a validation type _vtype_.  On success, 
    # returns the value; on failure, outputs the validation error, 
    # beginning with the _prefix_, and exits.
    #
    # Syntax:
    #   validate _prefix vtype value_
    #
    #   prefix - An error message prefix
    #   vtype  - A validation type
    #   value  - A value to validate

    proc validate {prefix vtype value} {
        if {[catch {{*}$vtype validate $value} result]} {
            puts "$prefix $result"
            exit 1
        }

        return $value
    }

    # Proc: section
    #
    # Formats and outputs a section header, for the program's output.
    #
    # Syntax:
    #   section "string"
    #
    #   string - A text string used as the section title.

    proc section {string} {
        set len [string length $string]

        set stars [string repeat "*" [expr {max(3, 55-$len)}]]

        puts "*** $string $stars\n"
    }
}

#-------------------------------------------------------------------
# Section: Data Types

# Type: epsilon
#
# Validation type for -epsilon values.

snit::double epsilon  -min 0.0000001

# Type: maxiters
#
# Validation type for -maxiters values.

snit::double maxiters -min 1

