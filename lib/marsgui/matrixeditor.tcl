#-----------------------------------------------------------------------
# TITLE:
#    matrixeditor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    JNEM gui(n) package: Matrix Editor
#
#    This widget provides a spreadsheet-like editor for mat(n) matrices
#    based on the tktable widget.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require Tktable

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::gui:: {
    namespace export matrixeditor
}


#-----------------------------------------------------------------------
# The Matrixeditor Widget Type

snit::widget ::gui::matrixeditor {
    widgetclass Matrixeditor

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Import commands
        namespace import ::marsutil::* ::marsutil::* ::gui::*

        # Add defaults to the option database
        option add *Matrixeditor.font               codefont
        option add *Matrixeditor.height             10
        option add *Matrixeditor.width              10
        option add *Matrixeditor.colwidth           8
        option add *Matrixeditor.resizeborders      none
        option add *Matrixeditor.titlefont          {Helvetica 12}
    }

    #-------------------------------------------------------------------
    # Components

    component table    ;# The Tktable widget
    component entry    ;# Cell editing entry widget

    #-------------------------------------------------------------------
    # Options

    # Options delegated to hull
    delegate option * to hull

    # Options delegated to table
    delegate option -font          to table
    delegate option -height        to table
    delegate option -width         to table
    delegate option -colwidth      to table
    delegate option -resizeborders to table

    # Local options

    # -titlefont
    # 
    # Title font
    option -titlefont

    # -state
    #
    # "disabled" or "normal".  When "disabled", the table can't be
    # edited.
    option -state normal

    # -rowtitles
    #
    # List of row labels
    option -rowtitles -default {}

    # -coltitles
    #
    # List of column labels
    option -coltitles {}

    # -validatecmd
    #
    # Command prefix to validate a cell's value; the value will be
    # lappend'd.  Command should throw an error if value is invalid.
    option -validatecmd {}

    # -normalizecmd
    #
    # Command prefix to normalize a cell's value.  The value will be
    # appended, and the command should return the normalized value.
    option -normalizecmd {}

    #-------------------------------------------------------------------
    # Instance variables

    # Array of matrix content indexed "$i,$j".  Titles are row -1 and
    # column -1.
    variable tabdata

    # Number of rows of matrix data
    variable m 0

    # Number of columns of matrix data
    variable n 0

    # Contents of cellBeingEdited
    variable celldata ""

    # $i,$j index of cell being edited
    variable cellBeingEdited ""

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the table and its scroll bars
        install table using table $win.table         \
            -roworigin      -1                       \
            -colorigin      -1                       \
            -drawmode       slow                     \
            -titlerows      1                        \
            -titlecols      1                        \
            -multiline      0                        \
            -resizeborders  none                     \
            -selectmode     extended                 \
            -rowseparator   "\n"                     \
            -colseparator   "\t"                     \
            -state          disable                  \
            -variable       [myvar tabdata]          \
            -cursor         left_ptr                 \
            -xscrollcommand [list $win.xscroll set]  \
            -yscrollcommand [list $win.yscroll set]  \
            -browsecommand  [mymethod BrowseCell]

        scrollbar $win.xscroll \
            -orient horizontal \
            -command [list $table xview]

        scrollbar $win.yscroll \
            -orient vertical \
            -command [list $table yview]

        # NEXT, create the edit entry; it will be placed over the
        # cell, as needed.
        install entry using entry $table.entry    \
            -width        [$table cget -colwidth] \
            -font         [$table cget -font]     \
            -borderwidth  1                       \
            -relief       flat                    \
            -foreground   black                   \
            -background   white                   \
            -textvariable [myvar celldata]
       
        # NEXT, handle the options.
        $self configurelist $args

        # NEXT, define the table tags.
        $table tag configure title \
            -font $options(-titlefont) \
            -foreground black \
            -relief raised \
            -borderwidth 1

        # NEXT, bind events.
        bind $table <Key-Return>      [mymethod BeginEditing]
        bind $table <Double-Button-1> [mymethod BeginEditing]

        bind $entry <Key-Escape>      [mymethod DoneEditing 0]
        bind $entry <Key-Return>      [mymethod DoneEditing 1]

        # NEXT, Grid the components into place
        grid columnconfigure $win 0 -weight 1
        grid columnconfigure $win 1 -weight 0

        grid rowconfigure $win 0 -weight 1
        grid rowconfigure $win 1 -weight 0

        grid $table       $win.yscroll -sticky nsew
        grid $win.xscroll              -sticky nsew
    }

    #-------------------------------------------------------------------
    # Private Methods

    # BrowseCell
    #
    # This method is called whenever Tktable is asked to browse a
    # different cell.  It ensures that the active cell is never a
    # title cell.

    method BrowseCell {} {
        # If the active cell is a title cell, activate the selection
        # anchor instead.
        if {[$table tag includes title active]} {
            $table activate anchor
        }
    }

    # BeginEditing 
    #
    # This is called when a user wishes to edit a cell.  It pops up
    # the cell entry with the cell's content.

    method BeginEditing {} {
        if {$options(-state) eq "disabled"} {
            return -code break
        }

        set ij [$table index active]
        set bbox [$table bbox $ij]

        set celldata $tabdata($ij)
        set cellBeingEdited $ij

        place $entry \
            -bordermode outside          \
            -x          [lindex $bbox 0] \
            -y          [lindex $bbox 1] \
            -width      [lindex $bbox 2] \
            -height     [lindex $bbox 3]

        $entry icursor end
        $entry selection range 0 end

        # Focus on the entry, wait for the focus take effect, and then
        # grab on the entry so that they have to ESC or RETURN before
        # doing anything else.
        focus $entry
        update idletasks
        grab set $entry

        return -code break
    }

    # DoneEditing keeper
    #
    # keeper         1 if the new value should be saved, and 0 otherwise.
    #
    # Handles the end of the editing transaction.  The value is validated
    # and saved (or not), and the entry is hidden.

    method DoneEditing {keeper} {
        if {$keeper} {
            if {$options(-validatecmd) ne ""} {
                set cmd $options(-validatecmd)
                lappend cmd $celldata

                puts "Validating: $cmd"
                if {[catch {uplevel \#0 $cmd} result]} {
                    # TBD: Log the error message to a message line.
                    bell
                    return -code break
                }
            }

            if {$options(-normalizecmd) ne ""} {
                set cmd $options(-normalizecmd)
                lappend cmd $celldata

                set celldata [uplevel \#0 $cmd]
            }

            set tabdata($cellBeingEdited) $celldata
        }

        grab release $entry
        place forget $entry

        focus $table
        $table activate active
        $table selection set active

        return -code break
    }


    #-------------------------------------------------------------------
    # Public Methods

    # set mat 
    #
    # mat      A mat(n) matrix
    # 
    # Loads the matrix into the tabdata array using the pre-specified
    # row and column labels.  It's up to the caller to make sure the 
    # dimensions match.

    method set {mat} {
        # FIRST, get the size of the matrix.
        set m [mat rows $mat]
        set n [mat cols $mat]

        # NEXT, size the table, leaving room for the titles.
        $table configure \
            -rows [expr {$m + 1}] \
            -cols [expr {$n + 1}]

        # NEXT, save the data
        array unset tabdata

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                set tabdata($i,$j) [lindex $mat $i $j]
            }
        }

        # NEXT, set the titles.
        for {set i 0} {$i < $m} {incr i} {
            set tabdata($i,-1) [lindex $options(-rowtitles) $i]
        }

        for {set j 0} {$j < $n} {incr j} {
            set tabdata(-1,$j) [lindex $options(-coltitles) $j]
        }
    }

    # get
    #
    # Returns a matrix corresponding to the current data.

    method get {} {
        set mat [matrix new $m $n 0]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                lset mat $i $j $tabdata($i,$j)
            }
        }

    }
}


