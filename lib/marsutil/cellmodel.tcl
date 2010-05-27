#-----------------------------------------------------------------------
# FILE: cellmodel.tcl
#   
#   Pseudo-Spreadsheet Cell Model
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export cellmodel
}

#-------------------------------------------------------------------
# Object Type: cellmodel
#
# Pseudo-spreadsheet Cell Model
#
# Instances of the cellmodel type implement "cell models".
# A cell model is essentially a spreadsheet model without the
# two-dimensional layout or presentation features.  A model
# consists of one or more cells.  Each cell has a name, a
# value, and (optionally) a formula.  (A cell with no formula is a 
# constant.) Formulas can refer to the values of other cells.
#
# Just as a spreadsheet can contain multiple linked worksheets, a
# cell model can contain multiple "pages".  A formula on a given 
# page can refer to cells on its own page by name, and cells on
# previous pages by page name and cell name.
#
# The first page is called the "null" page; null page cells can be
# referenced in formulas on any page without qualification.
#
# Pages are computed in the order of definition, iterating through
# the cells on each page until the results converge.  Thus, the 
# formulas on a page cannot refer to cells on any subsequent page.
#
# Formulas on a page may refer to other cells on the same page in 
# a circular fashion; the model will iterate each page to convergence
# before going on to the next page.  Iterating a page means running 
# through the cells in order, computing a new set of values using the 
# formulas.  Values are updated as the iteration proceeds.  Consider 
# cells A and B on page P, where A comes before B.
#
#    * If A depends on B, it is updated using the previous value of B.
#    * If B depends on A, it is updated using the newly computed value
#      of A.
#
# Iteration continues until the maximum delta between successive 
# iterations is less than some epsilon, or until it has iterated too long.
# (This is the Gauss-Seidel algorithm.)
#
# A checkpoint of the model is the vector of cell values.  It is 
# represented as a dictionary of cell names and values.  It is also
# possible to retrieve checkpoints of specific pages, with the 
# cell names qualified or unqualified.
#
# The model can be initialized from its initial values, or from a
# saved checkpoint.
#
#-----------------------------------------------------------------------

snit::type ::marsutil::cellmodel {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Look-up Tables

    # Reserved Words: The following words cannot be used as cell
    # or page names.
    typevariable reserved {
        all
        append
        error
        expr
        format
        if
        invalid
        return
        set
        string
        unknown
        unused
    }

    # Loader procs, used directly or indirectly in models.
    typevariable loaderProcs {
        # fsubst formula
        #
        # formula   A formula or formula template
        #
        # Does a subst on the formula, preserving square brackets.
        # Macros can be used; they must use <: and :> as their 
        # brackets in the formula.  If there are no variables or macros, 
        # it will leave the formula unchanged.
        #
        # NOTE: This command should be called exactly once on any
        # given string, e.g., [let] can call it on the formula, and
        # [define] can call it on its body.  Macros like [sum], which
        # are intended for use within formulas and formula templates,
        # should call "subst".  The sequence of processing then
        # becomes:
        #
        #   * Protect square brackets and convert <: and :> to [ and ]
        #   * Substitute, possibly recursively
        #   * Unprotect square brackets.

        proc fsubst {formula} {
            set formula [string map {    
                [ \\\[
                ] \\\]
                <: [
                :> ]
            } $formula]
            return [uplevel 1 [list subst $formula]]
        }

        # define name arglist ?initbody? template
        #
        # name        The formula template's name
        # arglist     The template's argument list
        # initbody    Optionally, some code to execute before evaluating
        #             the template.
        # template    The actual "subst" template string.
        #
        # Defines a template command called "name" in the caller's
        # context.  The template takes the arguments listed in
        # "arglist", which follows the normal Tcl proc rules.  When
        # called, the template command does a "subst" on the "template"
        # string and returns the result.  If given, "initbody" is
        # executed before the substitution; it can define variables to
        # be used in the template string, including declaring
        # global variables.

        proc define {name arglist initbody {template ""}} {
            # FIRST, have we an initbody?
            if {"" == $template} {
                set template $initbody
                set initbody ""
            }

            # NEXT, define the body of the new proc so that the initbody, 
            # if any, is executed and then the substitution is 
            set body "$initbody\n    fsubst [list $template]\n"

            # NEXT, define
            uplevel 1 [list proc $name $arglist $body]
        }

        # forall index script
        #
        # index     An index name
        # script    A script of cellmodel(5) commands.
        #
        # Evaluates the script for all values of the index.

        proc forall {index script} {
            global indices
            upvar 1 $index i

            if {![info exists indices($index)]} {
                return -code error -errorcode invalid \
                    "Invalid index: \"$index\""
            }

            foreach i $indices($index) {
                uplevel 1 $script
            }

            return
        }


        # sum index formula
        #
        # index      The index name, e.g., "i"
        # formula    The formula to sum up, in terms of $index, e.g.,
        #            A.$i
        #
        # Creates a formula that is a sum of the formula for
        # each value of the index

        proc sum {index formula} {
            global indices
            upvar $index i

            if {![info exists indices($index)]} {
                return -code error -errorcode invalid \
                    "Invalid index: \"$index\""
            }

            foreach i $indices($index) {
                lappend terms [uplevel 1 [list subst $formula]]
            }

            return "([join $terms { + }])"
        }

        # prod index formula
        #
        # index      The index name, e.g., "i"
        # formula    The formula to take the product of.
        #
        # Creates a formula that is the product of the formula for
        # each value of the index variable.


        proc prod {index formula} {
            global indices
            upvar $index i

            if {![info exists indices($index)]} {
                return -code error -errorcode invalid \
                    "Invalid index: \"$index\""
            }

            foreach i $indices($index) {
                lappend terms "([uplevel 1 [list subst $formula]])"
            }

            return [join $terms "*"]
        }

    }


    #-------------------------------------------------------------------
    # Components

    component interp    ;# Safe interpreter used for evaluating formulas.

    #-------------------------------------------------------------------
    # Group: Options

    # Option: -epsilon
    #
    # The epsilon for convergence of page during <solve>.

    option -epsilon \
        -type    {snit::double -min 0.0} \
        -default 0.0001

    # Option: -maxiters
    #
    # The maximum number of iterations when iterating a page
    # to convergence during <solve>.

    option -maxiters \
        -type    {snit::integer -min 1} \
        -default 100

    # Option: -tracecmd
    #
    # A command that's called to trace computation of the model
    # during <solve>.  The command is passed a variety of additional
    # arguments, depending on the trace point.  The patterns are as
    # follows:
    #
    # iterate _page iteration maxdelta_
    #
    # Called before the first iteration of the page, and after each
    # iteration.
    #
    # page      - The name of the page being iterated.
    # iteration - The iteration number; 0 before the first iteration.
    # maxdelta  - The iteration's _maxdelta_; 0.0 at iteration 0.
    #
    # converge _page iterations_
    #
    # Called when a page converges; _page_ is the page, and 
    # _iterations_ is the number of iterations.

    option -tracecmd


    #-------------------------------------------------------------------
    # Group: Uncheckpointed variables

    # Variable: info
    #
    # Array of miscellaneous data.
    #
    #   mode - null | compute | analysis
    
    variable info -array { 
        mode null
    }

    # Variable: model
    #
    # Array of model-specific data.  This data derives entirely from
    # the loaded model, and hence need not be checkpointed.  The
    # keys are as follows; $page is a page name, and $cell is a 
    # fully-qualified page name.
    #
    # NOTE: page fields and cell fields must have distinct names.
    #
    # sane            - 1 if the model appears to be "sane", and 0 
    #                   if there are problems.
    # functions       - Flat list of function definitions:
    #                   name arglist body...
    # indices         - Dictionary of index names and lists
    # pages           - List of page IDs, in the order of definition, 
    #                   which is also the order of computation.
    # cells           - List of fully-qualified cell names, in the order 
    #                   of definition.
    # barecells       - List of unqualified cell names, with no 
    #                   duplicates.
    # unknown         - List of unknown cells referenced in formulas.
    # unused          - List of cells unused by other cells.
    # invalid         - Cells with serious model errors, if sane=0
    # cyclic-$page    - 1 if $page contains cyclic definitions, and
    #                   0 otherwise.
    # cells-$page     - List of fully-qualifed names of cells on page 
    #                   $page, in order of definition.
    # barecells-$page - List of bare names of cells on page $page, in
    #                   order of definition.
    # order-$page     - List of fully-qualified names of cells on page
    #                   $page, in computation order.
    # page-$cell      - The name of the page on which $cell appears.
    # bare-$cell      - The bare name of $cell.
    # ctype-$cell     - Cell Type: constant|formula
    # vtype-$cell     - Value Type: number|symbol
    # ivalue-$cell    - The initial value of the cell.
    # formula-$cell   - The formula expression, or "" for constants.
    # uses-$cell      - List of the fully-qualified names of the cells
    #                   used by $cell's formula.
    # usedby-$cell    - List of the fully-qualified names of the cells
    #                   whose formulas include $cell.
    # unknown-$cell   - List of unknown cells used by $cell's formula
    # badpage-$cell   - List of cells used by $cell's formula that
    #                   are on subsequent pages.

    variable model -array {}

    # Variable: trans
    #
    # An array variable used for transient values.  During loading:
    #
    #   page        - Page currently being defined.
    #   copiedCells - Names of cells that were originally copied from
    #                 another page; the current page may override them
    #                 once only.
    #
    # During analysis of the loaded model
    #
    #   cell        - The name of the cell currently being analyzed.
    
    variable trans -array { }


    #-------------------------------------------------------------------
    # Group: Checkpointed Variables

    # Variable: values
    #
    # Array of current cell values, by fully-qualified cell name
    variable values -array { }

    # Variable: errors
    #
    # Array of evaluation errors for cells, by cell name.  Cells with
    # no error are omitted.  The entry "all" is a list of the cells
    # that had errors.
    #
    # This variable is set on <load>, for errors in the
    # cell formulas; and it's cleared and set on each <iterate>.

    variable errors -array { }

    #-------------------------------------------------------------------
    # Group: Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, set up the data to indicate an empty model.
        $self clear
    }

    #-------------------------------------------------------------------
    # Group: Loading the Model
    #
    # The model is loaded from a script of "page" and "let" commands.
    # Initial "let" commands define cells on the "null" page; subsequent
    # "page" commands create new pages.  "let" then defines cells on the
    # most recently created page.


    # Method: reset
    #
    # Resets all cells to their initial values.

    method reset {} {
        foreach cell $model(cells) {
            set values($cell) $model(ivalue-$cell)
        }
    }

    # Method: clear
    #
    # Deletes all content.

    method clear {} {
        array unset model
        array unset values
        array unset errors
        set info(mode) null

        set model(sane)           0
        set model(functions)      [list]
        set model(indices)        [list]
        set model(pages)          [list null]
        set model(cells)          [list]
        set model(barecells)      [list]
        set model(unknown)        [list]
        set model(unused)         [list]
        set model(invalid)        [list]
        set model(cells-null)     [list]
        set model(barecells-null) [list]
    }

    # Method: load
    #
    # Loads a new model from a model definition script.
    #
    # Syntax:
    #   load _model_
    #
    #   model - A model definition script.

    method load {text} {
        # FIRST, create the load interpreter.
        set loader [interp create -safe]
        $loader alias index    $self Load_index    $loader
        $loader alias function $self Load_function $loader
        $loader alias page     $self Load_page     $loader
        $loader alias let      $self Load_let      $loader
        $loader alias letsym   $self Load_letsym   $loader

        $loader eval $loaderProcs

        # NEXT, clear any previous model.
        $self clear

        # NEXT, prepare transient data
        array unset trans
        set trans(page)        null
        set trans(copiedCells) {}

        # NEXT, load the model, and destroy the loader when done.
        try {
            $loader eval $text
        } finally {
            rename $loader ""
        }

        # NEXT, analyze the model for problems and dependencies.
        $self reset
        $self AnalyzeModel

        # NEXT, prepare for computation.
        $self reset
        $self SetMode compute

        # NEXT, notify the user whether the model is sane or not.
        return $model(sane)
    }

    # Method: Load_index
    #
    # Defines an index that can be used with sum and prod in load
    # scripts.  The index list is saved for introspection.
    #
    # Syntax:
    #   index _name list_
    #
    #   name    - The index name
    #   list    - The values it iterates over.

    method Load_index {loader name list} {
        # FIRST, validate the index
        validate {![dict exists $model(indices) $name]} \
            "Duplicate index name: \"$name\""
    
        validate {[regexp {^\w+$} $name]} \
            "Invalid index name: \"$name\""

        # NEXT, save it for introspection
        dict set model(indices) $name $list

        # NEXT, save it into the loader, for use by macros
        $loader eval [list set ::indices($name) $list]

        return

    }

    # Method: Load_function
    #
    # Defines a function in the formula interpreter's tcl::mathfunc
    # namespace, so that it can be used in formulas.  The function
    # is just a Tcl proc; it can access cell values and use normal
    # Tcl logic.
    #
    # Syntax:
    #   function _name arglist body_
    #
    #   name    - The function's name
    #   arglist - The argument list
    #   body    - The function's body

    method Load_function {loader name arglist body} {
        # TBD: What kind of error checking can we do?
        lappend model(functions) $name $arglist $body
    }

    # Method: Load_page
    #
    # The implementation of the definition script's "page" command.
    # Adds a new page with the specified name.  The name must not
    # match any reserved word or page or cell name, must begin with a
    # letter, and may contain letters, numbers, and underscores.
    #
    # Syntax:
    #   page _page ?options?_
    #
    #   page - The page name
    #
    # The options are as follows:
    # 
    #   -copy page    - Copies all currently defined cells on the 
    #                   named page
    #   -except cells - Excludes particular cells from being copied.
    #                   Ignored if -copy is absent.

    method Load_page {loader page args} {
        # FIRST, validate the page name.
        $self ValidatePageName $page

        # NEXT, make it the current page.
        set trans(page)        $page
        set trans(copiedCells) {}

        # NEXT, get the options
        array set opts {
            -copy   {}
            -except {}
        }

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -copy { 
                    set opts(-copy) [lshift args]

                    validate {$opts(-copy) ne "null"} \
                        "Can't -copy the null page"

                    validate {$opts(-copy) in [$self pages]} \
                        "-copy unknown page: \"$opts(-copy)\""

                }

                -except {
                    set opts(-except) [lshift args]
                }

                default {
                    error "Invalid option: \"$opt\""
                }
            }
        }

        
        # NEXT, create the page.
        lappend model(pages) $page

        set model(cyclic-$page)    0
        set model(cells-$page)     [list]
        set model(barecells-$page) [list]
        set model(order-$page)     [list]

        # NEXT, copy the cells from the copy page, if any.  
        # Remember the names, because we can override them.
        if {$opts(-copy) ne ""} {
            foreach cell $model(cells-$opts(-copy)) {
                # Skip excluded cells.
                if {$model(bare-$cell) in $opts(-except)} {
                    continue
                }

                # Add the cell just as it was.
                $self AddCell $model(vtype-$cell) $model(bare-$cell)    \
                    -value    $model(ivalue-$cell)  \
                    -formula  $model(formula-$cell)
            }

            set trans(copiedCells) $model(cells-$page)
        }

        return
    }

    # Method: ValidatePageName
    #
    # Validates the page name, throwing an error if it's invalid
    # and returning it otherwise.  A new page name must:
    #
    # * Begin with a letter.
    # * Consist only of letters, numbers, and underscores.
    # * Not be a reserved word.
    # * Not duplicate an existing page name.
    #
    # Syntax: 
    #   ValidatePageName _name_
    #
    #   name - A new page name

    method ValidatePageName {name} {
        validate {[regexp {^[[:alpha:]]\w*$} $name]} \
            "Invalid page name: \"$name\""

        validate {$name ni $reserved} \
            "page name is reserved word: \"$name\""

        validate {$name ni $model(pages)} \
            "duplicate page name: \"$name\""

        return $name
    }
    

    # Load_let name = formula ?options...?
    #
    #   name     - The cell name
    #   =        - Sugar
    #   formula  - The formula
    #   options  - Cell options
    #
    # The implementation of the definition script's "let" command.
    # If _formula_ is a real number, defines a constant;
    # otherwise, defines a formula.

    method Load_let {loader name "=" formula args} {
        if {[string is double -strict $formula]} {
            $self AddCell number $name -value $formula {*}$args
        } else {
            set formula [$loader eval [list fsubst $formula]]
            $self AddCell number $name -formula $formula {*}$args
        }
    }


    # Load_letsym name = formula ?options...?
    #
    #   name     - The cell name
    #   =        - Sugar
    #   formula  - The formula
    #   options  - Cell options
    #
    # The implementation of the definition script's "letsym" command.
    # Defines a formula that returns a symbolic value, rather than
    # a number.

    method Load_letsym {loader name "=" formula args} {
        set formula [$loader eval [list fsubst $formula]]
        $self AddCell symbol $name -formula $formula {*}$args
    }


    # AddCell vtype name options...
    #
    # vtype    - number|symbol
    # name     - The cell's unqualified name
    # options  - The cell's options.
    #
    #   -value value         - The cell's initial value
    #   -formula expression  - For non-constant cells, the formula
    #
    # Creates a new cell with the specified name, initial value,
    # and formula (if any).  If the cell has no formula, it's a 
    # constant.  The cell is added to the current page.

    method AddCell {vtype name args} {
        # FIRST, get some data about the new cell.
        set barename [string trim $name]
        set ns       [pagens $trans(page)]
        set cell     ${ns}$barename
        set formula  [normalize [from args -formula]]
        let celltype {$formula ne "" ? "formula" : "constant"}

        # NEXT, validate the new cell name.

        # The barename must be syntactically valid.
        $self ValidateNewCellName $barename

        # The barename can't be a reserved word.
        validate {$barename ni $reserved} \
            "cell name is reserved word: \"$barename\""

        # The full cell name must be unique, unless it was copied from
        # another page.

        if {$cell in $trans(copiedCells)} {
            ldelete trans(copiedCells) $cell 
        } else {
            validate {$cell ni $model(cells)} \
                "Duplicate cell name: \"$cell\""
        }

        # If the cell is defined on a page, its barename can't match the name
        # of any cell defined on the null page.
        if {$trans(page) ne "null"} {
            validate {$barename ni $model(barecells-null)} \
                "Cell name shadows null page cell name: \"$cell\""
        }

        # NEXT, get the rest of the options.
        if {$vtype eq "number"} {
            set value [from args -value 0.0]
        } else {
            set value [from args -value ""]
        }

        validate {[llength $args] == 0} \
            "Invalid option: \"[lindex $args 0]\""
        
        # NEXT, save the data.
        ladd model(cells)                  $cell
        ladd model(barecells)              $barename
        ladd model(cells-$trans(page))     $cell
        ladd model(barecells-$trans(page)) $barename

        set model(page-$cell)    $trans(page)
        set model(bare-$cell)    $barename
        set model(ctype-$cell)   $celltype
        set model(vtype-$cell)   $vtype
        set model(ivalue-$cell)  $value
        set model(formula-$cell) $formula
        set model(uses-$cell)    [list]
        set model(usedby-$cell)  [list]
        set model(unknown-$cell) [list]
        set model(badpage-$cell) [list]

        return $cell
    }

    # ValidateNewCellName name
    #
    # name   A bare cell name
    #
    # Validates the name, throwing an error if:
    #
    # * The name doesn't match the required syntax.
    # * The name matches a reserved word

    method ValidateNewCellName {name} {
        set pattern {
            # Match whole word
            ^

            # Begin with a letter
            [[:alpha:]]

            # The body can contain letters, numbers, underscores, and
            # periods, but may not end with a period.  The body is
            # optional.
            (   # Begin body

             # Zero or more letters, numbers, underscores, or periods.
             [[:alnum:]_.]*

             # But not ending in a period.
             [[:alnum:]_]

            )?   # End Body

            # Match whole word
            $
        }

        validate {[regexp -expanded $pattern $name]} \
            "Invalid cell name: \"$name\""

        return $name
    }

    #-------------------------------------------------------------------
    # Analysis
    #
    # This section of  code analyzes the contents of a model for 
    # dependencies, undefined cells, unreferenced cells, invalid
    # cell references, and so forth.  This is done when the
    # model is loaded, and the "sane" flag is set accordingly.

    # AnalyzeModel
    #
    # Analyzes the model, putting the results into the model() array
    # and setting the model(sane) flag.
    
    method AnalyzeModel {} {
        # FIRST, Use instrumented cell references.
        $self SetMode analysis

        # NEXT, determine dependencies, and check formulas for 
        # syntax errors.
        array unset trans
        array unset errors
        set errors(all) [list]
        
        foreach cell $model(cells) {
            # FIRST, save the cell name, so that the evaluation
            # commands will know what it is.
            set trans(cell) $cell

            # NEXT, Skip constant cells.
            if {$model(formula-$cell) eq ""} {
                continue
            }

            # NEXT, evaluate the cell's formula.  Since we're in
            # analysis mode, the cell reference commands will
            # accumulate data for us.

            # Get the cell's page.

            if {$model(page-$cell) eq "null"} {
                set ns ::
            } else {
                set ns $model(page-$cell)
            }

            if {[catch {
                $interp invokehidden namespace eval $ns \
                    [list expr $model(formula-$cell)]
            } result opts]} {
                # Sometimes div/0 get us a result of Inf,
                # and sometimes it gets us an "ARITH DOMAIN" error.
                # In the latter case, ignore it.  Otherwise, 
                # remember the error message.
                set code [dict get $opts -errorcode]

                if {![string match "ARITH DOMAIN*" $code]} {
                    lappend errors(all) $cell
                    set errors($cell) $result
                }
            }
        }

        # NEXT, build list of unused cells and cells with errors.
        foreach cell $model(cells) {
            # Cell is unused.
            if {[llength $model(usedby-$cell)] == 0} {
                lappend model(unused) $cell
            }

            # Cell has a significant error.
            if {[llength $model(badpage-$cell)] > 0 ||
                [llength $model(unknown-$cell)] > 0 ||
                [info exists errors($cell)]
            } {
                lappend model(invalid) $cell
            }
        }

        # NEXT, set sane flag
        if {[llength $model(invalid)] == 0} {
            set model(sane) 1
        } else {
            set model(sane) 0
        }

        # NEXT, Only if sane, for each page, determine whether it's cyclic or
        # acyclic; and what the corresponding computation order
        # should be.
        
        if {$model(sane)} {
            foreach page $model(pages) {
                set order [toposort [$self Analyze_Graph $page]]

                if {[llength $order] == 0} {
                    set model(cyclic-$page) 1
                    set model(order-$page) $model(cells-$page)
                } else {
                    set model(cyclic-$page) 0
                    set model(order-$page) $order
                }
            }
        }

        return $model(sane)
    }

    # Analyze_CellValue cell
    #
    # An instrumented reference to the cell's value.  Notes the
    # following during "analysis" mode:
    #
    # Cell was referenced.

    method Analyze_CellValue {cell} {
        # FIRST, remember that the cell being evaluated references this cell.
        ladd model(uses-$trans(cell)) $cell

        # NEXT, remember that this cell is used by the cell being
        # evaluated.
        ladd model(usedby-$cell) $trans(cell)

        # NEXT, if this cell is from a later page than the cell whose
        # formula is being evaluated, that's a bad page reference.
        if {[$self Analyze_PageLater $trans(cell) $cell]} {
            ladd model(badpage-$trans(cell)) $cell
        }
    
        # FINALLY, return the value, as usual.
        return [$self CellValue $cell]
    }

    # Analyze_CellUnknown cell args...
    #
    # Called for unknown commands in analysis mode. Notes that an
    # unknown cell was referenced.

    method Analyze_CellUnknown {cell args} {
        # FIRST, remember the name.
        ladd model(unknown) $cell

        # NEXT, remember that the cell whose formula is being 
        # evaluated references this cell.
        ladd model(uses-$trans(cell))    $cell
        ladd model(unknown-$trans(cell)) $cell

        # NEXT, remember that this unknown cell is used by the
        # the cell whose formula is being evaluated.
        ladd model(usedby-$cell) $trans(cell)

        return [$self CellUnknown $cell {*}$args]
    }

    
    # Analyze_PageLater fcell rcell
    #
    # fcell    A cell with a formula
    # rcell    A cell referenced by fcell's formula
    #
    # Returns 1 if rcell is defined on a later page than fcell (which
    # is not allowed).

    method Analyze_PageLater {fcell rcell} {
        set fndx [lsearch -exact $model(pages) $model(page-$fcell)]
        set rndx [lsearch -exact $model(pages) $model(page-$rcell)]

        return [expr {$rndx > $fndx}]
    }

    # Analyze_Graph page
    #
    # Returns a dependency graph for the named page.

    method Analyze_Graph {page} {
        set graph [dict create]
        
        foreach fcell $model(cells-$page) {
            set uses [list]

            foreach rcell $model(uses-$fcell) {
                # Skip cells on prior pages
                if {$model(page-$rcell) ne $page} {
                    continue
                }
                
                lappend uses $rcell
            } 

            dict set graph $fcell $uses
        }

        return $graph
    }

    #-------------------------------------------------------------------
    # Computation Modes and Interpreter
    #
    # In compute mode, the model is computed as efficiently as possible.
    # In analysis mode, data is accumulated to allow sanity checking.

    # CreateInterp
    #
    # Creates a clean safe interpreter, possibly destroying its
    # predecessor.

    method CreateInterp {} {
        # FIRST, create the interp, destroying any previous interp.
        if {$interp ne ""} {
            rename $interp ""
        }
    
        set interp [interp create -safe ${selfns}::interp]

        # NEXT, empty it of commands in ::.
        foreach command [$interp eval {info commands}] {
            $interp hide $command
        }

        # NEXT, add a few back in.
        $interp expose append
        $interp expose expr
        $interp expose format
        $interp expose if
        $interp expose return
        $interp expose set
        $interp expose string

        # NEXT, alias in min and max funcs; the default versions
        # use commands we've hidden, and don't currently work in
        # -safe interpreters anyway.
        $interp alias ::tcl::mathfunc::min  ::tcl::mathfunc::min
        $interp alias ::tcl::mathfunc::max  ::tcl::mathfunc::max
        $interp alias ::tcl::mathfunc::case ::marsutil::cellmodel::CaseFunc

        # NEXT, add additional functions
        $interp alias ::tcl::mathfunc::epsilon $self Epsilon
        $interp alias ::tcl::mathfunc::ediff   $self EpsilonDiff
        $interp alias ::tcl::mathfunc::format  ::format

        # NEXT, define user functions
        foreach {name arglist body} $model(functions) {
            $interp invokehidden -global -- \
                proc ::tcl::mathfunc::$name $arglist $body
        }
    }

    # Proc: CaseFunc
    #
    # Defines a function case(condition1,value1,condition2, value2,...)
    # that returns value1 if condition1 is true, and value2 if 
    # condition2 is true, and so on.

    proc CaseFunc {args} {
        foreach {flag value} $args {
            if {$flag} {
                return [expr {double($value)}]
            }
        }
        
        return 0.0
    }

    # Method: Epsilon
    #
    # Defines a function epsilon() that returns the current
    # epsilon value.

    method Epsilon {} {
        return $options(-epsilon)
    }


    # Method: EpsilonDiff
    #
    # Defines a function ediff() that takes the difference of
    # two values and returns 0 if the difference is within
    # epsilon (when scaled by the size of the terms).

    method EpsilonDiff {a b} {
        set diff [expr {$a - $b}]
        
        if {abs($diff/max(1.0, abs($a), abs($b))) > $options(-epsilon)} {
            return $diff
        } else {
            return 0.0
        }
    }

    # SetMode mode
    #
    # Sets up the interpreter for the given mode.

    method SetMode {mode} {
        # FIRST, if the mode is already the desired mode, do nothing.
        if {$mode eq $info(mode)} {
            return
        }

        # NEXT, create a new interp.
        $self CreateInterp

        # NEXT, switch on the mode.
        switch -exact -- $mode {
            null {
                return
            }

            compute {
                set method CellValue

                $interp alias unknown $self CellUnknown
            }

            analysis {
                set method Analyze_CellValue
                $interp alias unknown $self Analyze_CellUnknown
            }

            default { 
                error "No such mode: \"$mode\"" 
            }
        }

        # NEXT, set up the cell reference handlers.
        foreach name $model(cells) {
            $interp alias $name $self $method $name
        }

        set info(mode) $mode
    }

    # CellValue cell
    #
    # A reference to the cell with the given name, returning the
    # cell's value.  Used in "compute" mode.

    method CellValue {cell} {
        return [expr {double($values($cell))}]
    }

    # CellUnknown cell args...
    #
    # Called for unknown commands in compute mode. Returns 0.

    method CellUnknown {cell args} {
        return 0
    }


    #-------------------------------------------------------------------
    # Public computation methods

    # get ?page? ?-bare?
    #
    #   page   - A page name, or "all" for all pages. Defaults to "all".
    #   -bare  - Returns bare cell names
    #
    # Returns a dictionary of cell names and current values.  By 
    # default, returns a dictionary of all cell values using
    # fully qualified cell names.  If a specific page is selected, 
    # only that page's cells are included.  If the "-bare" option is
    # also included, the dictionary keys are bare, lacking the page
    # name.  "-bare" is ignored if page is "all".

    method get {{page all} {opt ""}} {
        require {$page in [concat all [$self pages]]} \
            "Invalid page name: \"$page\""

        # FIRST, Determine what should be included.
        if {$page eq "all"} {
            set cells $model(cells)
            set keys  $cells
        } elseif {$opt eq "-bare"} {
            set cells $model(cells-$page)
            set keys  $model(barecells-$page)
        } else {
            set cells $model(cells-$page)
            set keys  $cells
        }

        # NEXT, build and return the dictionary.
        set result [dict create]

        foreach cell $cells key $keys {
            dict set result $key $values($cell)
        }
        
        return $result

    }

    # set dict ?page?
    #
    #   dict  - A dictionary of cell names and values.
    #   page  - A page name
    #
    # Sets the current cell values to match the dictionary.
    # If page is given, then it's assumed that the dictionary
    # keys are bare cell names relative to the specified page; otherwise,
    # it's assumed that all cell names are fully qualified.

    method set {dict {page ""}} {
        # FIRST, handle qualified names.
        if {$page eq ""} {
            # TBD: Should probably check names for validity.
            array set values $dict
            return
        }

        # NEXT, handle the bare names case.
        set ns [pagens $page]

        dict for {barename value} $dict {
            set values(${ns}$barename) $value
        }
    }

    # iterate page
    #
    #   page - The page over which to iterate
    #
    # Iterates once over the cells on the specified page, 
    # computing the max delta.  Returns a list of the max delta
    # and the cell which yielded the max delta.
    #
    # If there were errors while computing the page, there
    # will be entries in the errors() array when iterate
    # returns.

    method iterate {page} {
        # FIRST, clear the cell errors.
        array unset errors
        set errors(all) [list]

        # FIRST, get the full namespace name.
        if {$page eq "null"} {
            set ns ::
        } else {
            set ns $page
        }

        set maxDelta 0.0
        set maxCell  ""

        foreach cell $model(order-$page) {
            set formula $model(formula-$cell)

            if {$formula ne ""} {
                if {[catch {
                    set new [$interp invokehidden namespace eval $ns \
                                 [list expr $model(formula-$cell)]]

                    if {$model(vtype-$cell) eq "number"} {
                        if {$new eq "Inf"} {
                            error "cell $cell is Inf"
                        }

                        if {abs($values($cell)) > 1.0} {
                            let delta {
                                abs(($new - $values($cell))/$values($cell))
                            }
                        } else {
                            let delta {abs($new - $values($cell))}
                        }
                    } else {
                        set delta 0.0
                    }

                    set values($cell) $new
                } result]} {
                    # FIRST, save the error
                    lappend errors(all) $cell
                    set errors($cell) $result

                    # NEXT, set the delta to something greater than
                    # epsilon, so that we don't converge if there are
                    # errors.
                    let delta {int($options(-epsilon) + 1.0)}
                }

                if {$delta > $maxDelta} {
                    set maxDelta $delta
                    set maxCell $cell
                }
            }
        }

        return [list $maxDelta $maxCell]
    }

    # Method: solve
    #
    # Attempts to solve the model, computing each page in order.
    # Acyclic pages are computed once, and cyclic pages are iterated
    # to convergence.  Set a -tracecmd to trace the progress of the
    # computation.  Note that it's an error to call solve if the model
    # is not <sane>.
    #
    # By default, all pages are solved.  If _from_ is given, it is
    # the name of a single page to solve.  If _from_ and _to_ are given,
    # the pages in that sequence are solved.  It's an error for 
    # _to_ to precede _from_ in the list of pages.
    #
    # Syntax:
    #    solve _?from ?to??_
    #
    #    from -  Name of the page to start with.
    #    to   -  Name of the page to end with; can be "end", meaning
    #            the final page.
    #
    # Returns the result of the attempt.
    #
    #   ok              - Computation was successful; all cyclic pages 
    #                     converged.
    #   diverge <page>  - Unsuccessful; the named page diverged.
    #   errors <page>   - There are cell errors on the named page.
    
    method solve {{from ""} {to ""}} {
        require {$model(sane)} "Model is not sane."

        # FIRST, get the pages to solve.
        if {$from eq ""} {
            set pages $model(pages)
        } else {
            if {$to eq ""} {
                set to $from
            } elseif {$to eq "end"} {
                set to [lindex $model(pages) end]
            }

            set ifrom [lsearch -exact $model(pages) $from]
            set ito   [lsearch -exact $model(pages) $to]

            require {$ifrom != -1}   "Unknown from page: \"$from\""
            require {$ito != -1}     "Unknown to page: \"$to\""
            require {$ifrom <= $ito} "To page precedes from page"

            set pages [lrange $model(pages) $ifrom $ito]
        }

        # NEXT, solve, each page in sequence.
        foreach page $pages {
            # FIRST, solve acyclic pages.
            if {!$model(cyclic-$page)} {
                # Compute all cells; once is enough.
                callwith $options(-tracecmd) iterate $page 0 0.0 n/a
                set result [$self iterate $page]
                callwith $options(-tracecmd) iterate $page 1 {*}$result

                callwith $options(-tracecmd) converge $page 1

                # If there are errors, report them.
                if {[llength $errors(all)] > 0} {
                    return [list errors $page]
                }

                # Otherwise, go on to the next cell.
                continue
            }

            # NEXT, this is a cyclic page.  We need to iterate to a
            # solution.
            if {![$self PageConverges $page]} {
                # If there are errors, report them; otherwise, report
                # that the page diverges.
                if {[llength $errors(all)] > 0} {
                    return [list errors $page]
                } else {
                    return [list diverge $page]
                }
            }
        }

        return ok
    }

    # Method: PageConverges
    #
    # Tries to iterate a cyclic page to convergence.
    #
    # Syntax:
    #   PageConverges _page_
    #
    #   page - Name of page to solve

    method PageConverges {page} {
        set new 0.0

        callwith $options(-tracecmd) iterate $page 0 0.0 n/a

        for {set i 1} {$i <= $options(-maxiters)} {incr i} {
            set old $new
            lassign [$self iterate $page] new maxcell

            callwith $options(-tracecmd) iterate $page $i $new $maxcell

            if {$new <= $options(-epsilon)} {
                callwith $options(-tracecmd) converge $page $i
                return 1
            }
        }

        return 0
    }


    #-------------------------------------------------------------------
    # Queries

    # sane
    #
    # Returns 1 if the model is sane, and 0 otherwise.

    method sane {} {
        return $model(sane)
    }

    # pages
    #
    # Returns a list of the pages in 
    # order of definition.

    method pages {} {
        return $model(pages)
    }

    # cells ?page?
    #
    # page    A page name, or all|unknown|unused|error
    #
    # Returns a list of the cell names of the cells on all
    # pages.  If page is given, the cells are
    # limited to that page.  The page must exist.

    method cells {{page "all"}} {
        switch -exact -- $page {
            all     { return $model(cells)        }
            unknown { return $model(unknown)      }
            unused  { return $model(unused)       }
            invalid { return $model(invalid)      }
            error   { return $errors(all)         }
            default { return $model(cells-$page)  }
        }
    }

    # pageinfo field page
    #
    # field   A page field
    # page    A page name
    #
    # Returns the value of a page info field.
    
    method pageinfo {field page} {
        return $model($field-$page)
    }

    # cellinfo field cell
    #
    # field   A cell field
    # cell    A cell name
    #
    # Returns the value of a cell info field.
    
    method cellinfo {field cell} {
        if {$field eq "error"} {
            if {[info exists errors($cell)]} {
                return $errors($cell)
            } else {
                return ""
            }
        }

        return $model($field-$cell)
    }

    # value cell
    #
    # cell    A cell name
    #
    # Returns the current value of the named cell.  The cell must
    # exist.

    method value {cell} {
        return $values($cell)
    }

    # formula cell
    #
    # cell    A cell name
    #
    # Returns the formula associated with the cell, or "" if none.  
    # The cell must exist.

    method formula {cell} {
        return $model(formula-$cell)
    }

    # index ?name?
    #
    # name   An index name
    #
    # Called with no arguments, returns a list of the defined index
    # names.  Called with an index name, returns the associated list.

    method index {{name ""}} {
        if {$name eq ""} {
            return [lsort [dict keys $model(indices)]]
        } elseif {[dict exist $model(indices) $name]} {
            return [dict get $model(indices) $name]
        } else {
            error "Unknown index name: \"$name\""
        }
    }

    #-------------------------------------------------------------------
    # Debugging dumps

    # dump ?page|all?
    #
    # Dumps all or part of the model, with current cell values.

    method dump {{page all}} {
        # FIRST, get the width of the cell names.
        set wid [lmaxlen [$self cells $page]]

        set out ""
        foreach cell [$self cells $page] {
            set value $values($cell)

            if {$model(vtype-$cell) eq "number"} {
                append out [format "%-*s = %12g" $wid $cell $value]
            } else {
                append out [format "%-*s = %12s" $wid $cell \"$value\"]
            }

            if {$model(formula-$cell) ne ""} {
                append out " <= $model(formula-$cell)"
            }

            append out "\n"
        }

        return $out
    }


    #-------------------------------------------------------------------
    # Group: Utility Procs

    # Proc: pagens
    #
    # Returns the namespace for a given page.
    #
    # Syntax:
    #   pagens _page_
    #
    #   page - A page name

    proc pagens {page} {
        if {$page eq "null"} {
            return ""
        } else {
            return "${page}::"
        }
    }
    
    # validate expression message
    #
    # expression    A boolean expression
    # message        An error message
    #
    # Throws an error with errorcode INVALID if the expression is false.

    proc validate {expression message} {
        if {[uplevel [list expr $expression]]} {
            return
        }

        return -code error -errorcode INVALID $message
    }

    # Proc: toposort
    #
    # Does a topological sort of a directed acyclic graph; throws an
    # error if the graph isn't actually acyclic.  Uses the Kahn
    # algorithm; http://en.wikipedia.org/wiki/Topological_sort.
    #
    # Syntax:
    #   toposort _dict_
    #
    #   dict     A DAG; see below.
    #
    # The _dict_ parameter contains a directed acyclic graph expressed
    # as a dictionary whose keys are node IDs and whose values are 
    # list of node IDs that connect *to* the key node.
    #
    # Returns a list of the node IDs in sorted order, or "" if 
    # the DAG contains cycles.

    proc toposort {dict} {
        # FIRST, build a list S of nodes with no incoming edges.
        set S [list]

        dict for {node incoming} $dict {
            if {[llength $incoming] == 0} {
                lappend S $node
                set dict [dict remove $dict $node]
            }
        }

        # NEXT, sort the nodes into L.
        set L [list]

        while {[llength $S] > 0} {
            # Remove a node n from S
            set n [lshift S]

            # Insert n into L
            lappend L $n

            # For each remaining node m, if m depends on n, remove
            # n from its list.  If the list is empty, add m to S.
            dict for {m incoming} $dict {
                ldelete incoming $n

                if {[llength $incoming] == 0} {
                    lappend S $m
                    set dict [dict remove $dict $m]
                } else {
                    dict set dict $m $incoming
                }
            }
        }

        # NEXT, if there are any edges left in the data array, there
        # were cycles; return nothing.
        if {[dict size $dict] > 0} {
            return ""
        }

        return $L
    }

}