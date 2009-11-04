#-----------------------------------------------------------------------
# TITLE:
#    sqlbrowser.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Prototype tablebrowser(n) replacement
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export sqlbrowser
}


#-----------------------------------------------------------------------
# sqlbrowser

snit::widget ::marsgui::sqlbrowser {
    hulltype ttk::frame
    
    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        namespace import ::marsutil::*
    }
    
    #-------------------------------------------------------------------
    # Components
    
    component reloader  ;# Timeout that handles reloading the content.
    component sorter    ;# Timeout that handles re-sorting on update.
    component changer   ;# Timeout that calls -selectioncmd on delete.
    component toolbar   ;# The browser toolbar
    component filter    ;# filter(n) component used to filter entries
    component vmenu     ;# Pulldown of available views
    component cbar      ;# The client's toolbar, for application-specific
                         # widgets
    component db        ;# sqldocument(n) handle, or equivalent
    component tlist     ;# tablelist(n) widget, for displaying the data.
    
    #-------------------------------------------------------------------
    # Options
    
    # To hull frame
    delegate option -borderwidth to hull
    delegate option -relief      to hull
    
    # To Tablelist
    delegate option -height       to tlist
    delegate option -width        to tlist
    delegate option -selectmode   to tlist
    delegate option -titlecolumns to tlist
    
    # -db db
    #
    # The sqldocument(n) object
    option -db -readonly yes
    
    # -displaycmd cmd
    #
    # A command that's called for each row inserted into the table list.
    # It receives two additional arguments, the tablelist row index
    # and the list of the column data.
    
    option -displaycmd \
        -default ""
    
    # -layout spec
    #
    # A specification of the columns to display.  If not given, the
    # columns and labels are taken from the view.
    #
    # The spec is a list of lists, one for each column.  Each list
    # has this form:
    #
    #    name label options...
    #
    # The options are a subset of the tablelist columnconfigure
    # options.
    
    option -layout                           \
        -default         {}                  \
        -configuremethod ConfigureThenLayout
    
    # -selectioncmd
    #
    # A command that's called when the tablebrowser's selection
    # changes.
    
    option -selectioncmd \
        -default ""
    
    # -uid name
    #
    # Specifies the name of a column in the -view that contains
    # a unique ID for each row in the view.  If set, the "uid *"
    # subcommands are available.
    
    option -uid \
        -readonly yes \
        -default  ""
    
    # -view viewname
    #
    # The view or table to display.  Reloads the content on change.
    
    option -view \
        -configuremethod ConfigureView
    
    method ConfigureView {opt val} {
        # FIRST, if it didn't change, ignore it.
        if {$val eq $options($opt)} {
            return
        }
        
        # NEXT, save the change
        set options($opt) $val

        # NEXT, update the Views pulldown, if any.
        if {$vmenu ne ""} {
            set label ""

            if {[dict exists $options(-views) $val]} {
                set label [dict get $options(-views) $val]
            }
            
            $vmenu set $label
        }
        
        # NEXT, schedule a reload.
        $self reload
    }
    
    
    # -views viewdict
    #
    # A dictionary of view names and labels.  The labels will be
    # displayed in a pulldown in the tool bar; selecting the label
    # sets -view.
    #
    # TBD: We might want to be able to add to the list dynamically.
    
    option -views -readonly yes
    
    # ConfigureThenReload opt val
    #
    # -configuremethod.  Saves the option value, then schedules a
    # reload.
    
    method ConfigureThenReload {opt val} {
        # If nothing changed, do nothing.
        if {$val eq $options($opt)} {
            return
        }
        
        # Save the option
        set options($opt) $val
        
        # Schedule the reload
        $self reload
    }
    
    # ConfigureThenLayout opt val
    #
    # -configuremethod.  Saves the option value, then schedules a
    # reload.
    
    method ConfigureThenLayout {opt val} {
        # If nothing changed, do nothing.
        if {$val eq $options($opt)} {
            return
        }
        
        # Save the option
        set options($opt) $val
        
        # Schedule the layout
        $self layout
    }

    #-------------------------------------------------------------------
    # Instance Variables
    
    # info array
    #
    #   layoutFlag      1 if the columns have been laid out, and 0
    #                   otherwise.
    #   views           Dictionary of view names by label: The inverse
    #                   of -views.
    #   columns         Column names in the current view, in order.
    #   sortcol         The last column sorted on, or ""
    #   reloadRequests  Number of reload requests since the last reload.
    
    variable info -array {
        layoutFlag     0
        views          {}
        columns        {}
        reloadRequests 0
        sortcol        {}
    }
    
    # layout array: layout dicts by column name.  For each column:
    #
    #   name        Column name
    #   cindex      Column index
    #   sortdir     Sort direction, -increasing | -decreasing
    
    variable layout -array {}
    
    # uidmap: Map from UIDs to row indices
    
    variable uidmap -array {}
    
    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, create the components to which options are delegated.
        
        # Reloader: timeout controlling reload requests.
        install reloader using timeout ${selfns}::reloader \
            -command    [mymethod ReloadContent]           \
            -interval   1                                  \
            -repetition no
        
        # Sorter: timeout controlling re-sorting on uid update.
        install sorter using timeout ${selfns}::sorter     \
            -command    [mymethod SortData]                \
            -interval   1                                  \
            -repetition no
        
        # Changer: timeout controlling -selectioncmd on uid delete.
        install changer using timeout ${selfns}::changer   \
            -command    [mymethod SelectionChanged]        \
            -interval   1                                  \
            -repetition no

        # Set the hull defaults
        $hull configure       \
            -borderwidth 1    \
            -relief      flat
        
        # Create the tablelist.
        install tlist using tablelist::tablelist $win.tlist \
            -background       white                         \
            -foreground       black                         \
            -font             codefont                      \
            -width            80                            \
            -height           24                            \
            -state            normal                        \
            -stripebackground #CCFFBB                       \
            -selectbackground black                         \
            -selectforeground white                         \
            -labelborderwidth 1                             \
            -selectmode       extended                      \
            -exportselection  false                         \
            -movablecolumns   no                            \
            -activestyle      none                          \
            -yscrollcommand   [list $win.yscroll set]       \
            -xscrollcommand   [list $win.xscroll set]       \
            -labelcommand     [mymethod SortByColumn]

        # Scrollbars
        ttk::scrollbar $win.yscroll       \
            -orient  vertical             \
            -command [list $tlist yview]

        ttk::scrollbar $win.xscroll       \
            -orient  horizontal           \
            -command [list $tlist xview]


        # NEXT, configure the options
        $self configurelist $args
        
        # Save the database handle
        set db $options(-db)
        
        # Invert the list of views
        dict for {view label} $options(-views) {
            dict set info(views) $label $view
        }
        
        # NEXT, create the rest of the components
        
        # Browser Toolbar
        install toolbar using ttk::frame $win.toolbar
        
        # Filter box
        install filter using filter $toolbar.filter \
            -width      15                          \
            -filtertype incremental                 \
            -ignorecase yes                         \
            -filtercmd  [mymethod FilterData]
        
        pack $filter -side right -fill y -padx {2 0}
        
        # Client Toolbar
        install cbar using ttk::frame $toolbar.cbr
        pack $cbar -side left -fill x -expand yes
        
        # Views pulldown if any.
        # Install the views pulldown, if any.
        if {$options(-views) ne ""} {
            # FIRST, Get the list of labels
            set labels [dict keys $info(views)]

            # NEXT, Create the widgets
            ttk::label $toolbar.viewlabel \
                -text "View:"

            install vmenu using menubox $toolbar.vmenu     \
                -width     [expr {[lmaxlen $labels] + 2}]  \
                -values    $labels                         \
                -command   [mymethod SetView]

            pack $vmenu              -side right -fill y -padx {2 3}
            pack $toolbar.viewlabel  -side right -fill y -padx {2 0}

            # NEXT, either display the current view, or select the
            # first view.
            if {$options(-view) ne ""} {
                $vmenu set [dict get $options(-views) $options(-view)]
            } else {
                $self configure \
                    -view [lindex [dict keys $options(-views)] 0]
            }
        } else {
            set vmenu ""
        }
        
        # NEXT, layout the major components
        grid $toolbar     -row 0 -column 0 -columnspan 2 -sticky ew -pady 2
        grid $tlist       -row 1 -column 0 -sticky nsew
        grid $win.yscroll -row 1 -column 1 -sticky ns
        grid $win.xscroll -row 2 -column 0 -sticky ew

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 1 -weight 1
        
        # NEXT, Behaviour
        
        # Reload the content from the current view when the window
        # is mapped.
        bind $win <Map> [mymethod MapWindow]
        
        # Force focus when the tablelist is clicked
        bind [$tlist bodytag] <1> [focus $tlist]
        
        # Allow the user to copy the contents
        bind [$tlist bodytag] <<Copy>> [mymethod CopySelection]
        
        # Support -selectioncmd
        bind $tlist <<TablelistSelect>> [mymethod SelectionChanged]
        
        # When the widget receives the focus, pass it on to the tlist.
        bind $win <FocusIn> [mymethod FocusIn]
        
        # NEXT, schedule the first reload
        $self reload
    }
    
    #-------------------------------------------------------------------
    # Behaviour
    
    # MapWindow
    #
    # Reload the browser when the window is mapped, if there have
    # been any reload requests.
    
    method MapWindow {} {
        # If a reload has been requested, but the reloader is no
        # longer scheduled (i.e., the reload was requested while
        # the window was unmapped) then reload it now.
        if {$info(reloadRequests) > 0 &&
            ![$reloader isScheduled]
        } {
            $self ReloadContent
        }
    }
    
    # FocusIn
    #
    # When the widget receives the focus, give it to the tablelist.
    
    method FocusIn {} {
        focus $tlist
    }
    
    # SetView
    #
    # Called when a new view is selected from the Views pulldown.
    # Updates the display.

    method SetView {} {
        $self configure -view [dict get $info(views) [$vmenu get]]
    }
    
    # FilterData
    #
    # Filters the data based upon the specified target.
    #
    # TBD: For large data sets, would it be faster or slower to
    # retrieve the rows individually, so as not to build such a
    # massive list?
    
    method FilterData {} {
        # FIRST, initialize row and all data
        set rowidx 0
        set datasets [$tlist get 0 end]

        # NEXT, go through each dataset and see if it should be filtered
        foreach data $datasets {
            if {[$filter check $data]} {
                $tlist rowconfigure $rowidx -hide false
            } else {
                $tlist rowconfigure $rowidx -hide true
            }
            
            incr rowidx
        } 

        # NEXT, clear all selections 
        $tlist selection clear 0 end
        
        # NEXT, the selection has changed.
        $self SelectionChanged
    }
    
    # SelectionChanged
    #
    # The tablelist selection has changed.
    
    method SelectionChanged {} {
        callwith $options(-selectioncmd)
    }
    
    # CopySelection
    #
    # This method takes the currently selected text from the table list
    # and puts it on the system clipboard.

    method CopySelection {} {
        # FIRST, get currently selected rows
        set rows [$tlist curselection]

        # NEXT, if there is no selection, there's nothing to do.
        if {[llength $rows] == 0} {
            return
        }
        
        # NEXT, clear the clipboard
        clipboard clear
        
        # NEXT, append each row with a new line so it gets pasted nicely
        foreach row $rows {
            clipboard append "[$tlist get $row]\n"
        }
    }
    
    # ReloadContent
    #
    # Reloads the current -view.  Has no effect if the window is
    # not mapped.
    
    method ReloadContent {} {
        # FIRST, we don't do anything until we're mapped.
        if {![winfo ismapped $win]} {
            return
        }
        
        puts "Reloading $options(-view)!"
        
        # NEXT, clear the reload request counter.
        set info(reloadRequests) 0

        # NEXT, Layout the columns if need be.
        if {!$info(layoutFlag)} {
            $self LayoutColumns
        }
        
        # NEXT, Save the selection
        set ids [$tlist curselection]
        
        # NEXT, clear the table
        $self clear
        
        # NEXT, request and insert all rows from the current view
        set rindex -1
        
        $db eval "
            SELECT * FROM $options(-view)
        " row {
            incr rindex
            
            # FIRST, insert the data
            set data [list]
            foreach name $info(columns) {
                lappend data $row($name)
            }
            
            $tlist insert end $data
            
            # NEXT, if there's a -uid column, update the key map.
            if {$options(-uid) ne ""} {
                set uidmap($row($options(-uid))) $rindex
            }
            
            # NEXT, call the -displaycmd, if any.
            callwith $options(-displaycmd) end $data
            
            # NEXT, determine whether it should be filtered.
            if {[$filter check $data]} {
                $tlist rowconfigure end -hide false
            } else {
                $tlist rowconfigure end -hide true
            }
        }
        
        # NEXT, sort the contents
        $self SortData
        
        # NEXT, select the same rows
        $tlist selection set $ids
    }
    
    #-------------------------------------------------------------------
    # Layout
    
    # LayoutColumns
    #
    # If there's a -layout, layout the columns accordingly.  Otherwise,
    # get the column names from the view, and layout using those.
    
    method LayoutColumns {} {
        if {[$tlist columncount] > 0} {
            $tlist deletecolumns 0 end
            set info(columns) [list]
            array unset layout
        }
        
        if {$options(-layout) eq ""} {
            $self InferLayoutSpec
        } else {
            $self ParseLayoutSpec
        }
    }
    
    # InferLayoutSpec
    #
    # Infers the column layout from the current view, and puts it
    # in place.
    
    method InferLayoutSpec {} {
        # FIRST, get the column names for the current view.
        set cindex -1
        
        $db eval "PRAGMA table_info($options(-view))" row {
            lappend info(columns) $row(name)
            
            set layout($row(name)) [dict create \
                name    $row(name)     \
                cindex  [incr cindex]  \
                sortdir -increasing]
                    
            if {$row(type) in {DOUBLE INTEGER}} {
                set align right
            } else {
                set align left
            }
            
            $tlist insertcolumns end 0 $row(name) $align
        }
        
        if {[llength $info(columns)] == 0} {
            error "view has no columns: \"$options(-view)\""
        }
    }
    
    # ParseLayoutSpec
    #
    # Parses the -layout, lays out the columns, and saves the
    # column info.
    
    method ParseLayoutSpec {} {
        # FIRST, get the column names, and determine whether
        # we need to define a hidden -uid column.
        
        set bspec $options(-layout)
        
        foreach cspec $bspec {
            lappend info(columns) [lindex $cspec 0]
        }
        
        if {$options(-uid) ne "" &&
            $options(-uid) ni $info(columns)
        } {
            lappend bspec [list $options(-uid) $options(-uid) -hide 1]
        }

        
        # NEXT, Define the columns in the layout spec.
        set cindex -1
        
        foreach cspec $bspec {
            lassign $cspec cname label
            set opts [lrange $cspec 2 end]
            
            lappend info(columns) $cname
            
            set layout($cname) [dict create \
                name    $cname              \
                cindex  [incr cindex]       \
                sortdir -increasing]

            $tlist insertcolumns end 0 $label
            
            if {[llength $opts] > 0} {
                $tlist columnconfigure $cindex {*}$opts
            }            
        }
    }
    
    #-------------------------------------------------------------------
    # Sorting
   
    # SortData
    #
    # Sorts the contents of the tablelist widget by the last requested
    # sort command, and calls the -selectioncmd.
  
    method SortData {} {
        # FIRST, if we've not sorted on any column, then we're done.
        if {$info(sortcol) eq ""} {
            # Call -selectioncmd anyway, as SortData calls it for
            # reload.
            callwith $options(-selectioncmd)
            return
        }
        
        # NEXT, pass the command through to the tablelist widget
        dict with layout($info(sortcol)) {
            set sortdir [dict get $layout($info(sortcol)) sortdir]
        
            if {$sortdir ne "-none"} {
                $tlist sortbycolumn $cindex $sortdir
            }
        }
        
        # NEXT, update the uidmap, if any.
        if {$options(-uid) ne ""} {
            # FIRST, clear the old map
            array unset uidmap
            
            # NEXT, get the UID column index
            set cindex [dict get $layout($options(-uid)) cindex]
        
            # NEXT, rebuild the map between UID and row number
            set rindex -1

            foreach uid [$tlist getcolumns $cindex] {
                set uidmap($uid) [incr rindex]
            }
        }
        
        # NEXT, the selection might have changed.
        callwith $options(-selectioncmd)
    }
    
    # SortByColumn w cindex
    #
    # w         the tablelist widget 
    # cindex    the column index
    #
    # Sets the sort direction for the specified column, and resorts.

    method SortByColumn {w cindex} {
        # FIRST, get the column name
        set cname [lindex $info(columns) $cindex]
        
        dict with layout($cname) {
            # FIRST, if they have never sorted on this column, let it
            # be increasing.
            
            if {$sortdir eq "-none"} {
                set sortdir "-increasing"
            }
            
            # NEXT, if they've clicked on the same column, toggle the
            # sort order; otherwise, just remember the new column.
            
            if {$cname eq $info(sortcol)} {
                if {$sortdir eq "-increasing"} {
                    set sortdir "-decreasing"
                } else {
                    set sortdir "-increasing"
                }
            } else {
                set info(sortcol) $cname
            }
        }
        
        # NEXT, re-sort.
        $self SortData
    }



    #-------------------------------------------------------------------
    # Public Methods
    
    delegate method columnconfigure to tlist
    delegate method columncget      to tlist
    delegate method curselection    to tlist
    delegate method get             to tlist
    delegate method rowconfigure    to tlist
    delegate method rowcget         to tlist
    delegate method selection       to tlist
    
    # toolbar
    #
    # Returns a ttk::frame to which the client can add toolbar
    # controls.

    method toolbar {} {
        return $cbar
    }
    
    
    # clear
    #
    # Delete all rows, and clear the uidmap.
    
    method clear {} {
        array unset uidmap
        $tlist delete 0 end
        
        callwith $options(-selectioncmd)
    }
    
    # reload
    #
    # Schedules a reload of the content.  Note that the reload will
    # be ignored if the window isn't mapped.
    
    method reload {} {
        incr info(reloadRequests)
        $reloader schedule -nocomplain
    }
    
    # layout
    #
    # Schedules a reload of the content, but does a new layout of the
    # columns.
    
    method layout {} {
        set info(layoutFlag) 0
        $self reload
    }

    # sortby col ?direction?
    #
    # col        The name of the column to sort by
    # direction  -increasing/-decreasing/-none

    method sortby {col {direction "-increasing"}} {
        # FIRST, save the info
        set info(sortcol) $col
        dict set layout($col) sortdir $direction

        # NEXT, re-sort
        $self SortData
    }
    
    #-------------------------------------------------------------------
    # Conversions: column name to column index
    
    # cindex2cname cindex
    #
    # cindex     A Tablelist column index
    #
    # Returns the column name
    
    method cindex2cname {cindex} {
        lindex $info(columns) [$tlist columnindex $cindex]
    }

    # cname2cindex cname
    #
    # cname   A column name
    #
    # Returns the Tablelist column index
    
    method cname2cindex {cname} {
        dict get $layout($cname) cindex
    }

    #-------------------------------------------------------------------
    # Conversions: uid to row index

    # rindex2uid rindex
    #
    # rindex    A tablelist row index
    #
    # Returns the UID associated with the row index, if any, or ""
    # if none.
    
    method rindex2uid {rindex} {
        # FIRST, if there's no -uid column, return nothing.
        if {$options(-uid) eq ""} {
            return ""
        }
        
        # NEXT, if there's no such row, return nothing.
        if {$rindex < 0 || $rindex > [$tlist size]} {
            return ""
        }
        
        # NEXT, get the UID from the cell
        set cindex [dict get $layout($options(-uid)) cindex]
        
        return [$tlist getcell $rindex,$cindex]
    }
    
    # uid2rindex uid
    #
    # uid       A unique row ID
    #
    # Returns the row index associated with the UID, or "" if none.
    
    method uid2rindex {uid} {
        if {[info exists uidmap($uid)]} {
            return $uidmap($uid)
        } else {
            return ""
        }
    }
    
    #-------------------------------------------------------------------
    # UID Commands
    
    # uid curselection
    #
    # Returns a list of the IDs of the rows that are selected, or
    # the empty string if none.

    method {uid curselection} {} {
        require {$options(-uid) ne ""} "-uid is undefined"

        set cindex [$self cname2cindex $options(-uid)]
        
        set result [list]

        set uids [$tlist getcolumns $cindex]

        foreach row [$tlist curselection] {
            lappend result [lindex $uids $row]
        }

        return $result
    }

    # uid create uid
    #
    # uid     A value in the -uid column of the -view.
    #
    # Updates the browser to display a new row.

    method {uid create} {uid} {
        # FIRST, if the window's not mapped just request a reload on
        # <Map>.
        if {![winfo ismapped $win]} {
            incr info(reloadRequests)
            return
        }
        
        # FIRST, update the browser with the new data
        $self uid update $uid
    }

    
    # uid update uid
    #
    # uid   A value in the -uid column of the -view.
    #
    # Extract the row with the supplied uid from the db. Insert
    # the data, and then sort it.
    # 
    # NOTE: If -views is being used, the updated entity might not
    # currently be displayed.  If no data is retrieved, just return.

    method {uid update} {uid} {
        # FIRST, if the window's not mapped just request a reload on
        # <Map>.
        if {![winfo ismapped $win]} {
            incr info(reloadRequests)
            return
        }

        require {$options(-uid) ne ""} "-uid is undefined"

        # FIRST, get the row from the view
        set row(*) ""
        
        $db eval "
            SELECT * from $options(-view)
            WHERE $options(-uid) == \$uid
        " row {}

        # NEXT, if we retrieved nothing, there's nothing to do.
        if {$row(*) eq ""} {
            return
        }

        # NEXT get the data.
        set data [list]
        foreach name $info(columns) {
            lappend data $row($name)
        }
        
        # NEXT, this can be a create or an update.  If it's a create,
        # insert the data; otherwise, update the existing row.
        if {[info exists uidmap($uid)]} {
            $tlist rowconfigure $uidmap($uid) -text $data
        } else {
            set uidmap($uid) [$tlist index end]
            $tlist insert end $data
        }
        
        # NEXT, call the -displaycmd, if any.
        callwith $options(-displaycmd) $uidmap($uid) $data
        
        # NEXT, determine whether it should be filtered.
        if {[$filter check $data]} {
            $tlist rowconfigure $uidmap($uid) -hide false
        } else {
            $tlist rowconfigure $uidmap($uid) -hide true
        }

        # NEXT, sort the rows, the update may have changed the column we
        # are sorting on
        $sorter schedule -nocomplain
    }

    # uid delete
    #
    # uid   A value in the -uid column of the -view.
    #
    # This method deletes the specified row from the table.
    #
    # NOTE: If -views is being used, the deleted entity might not
    # currently be displayed.

    method {uid delete} {uid} {
        # FIRST, if the window's not mapped just request a reload on
        # <Map>.
        if {![winfo ismapped $win]} {
            incr info(reloadRequests)
            return
        }

        require {$options(-uid) ne ""} "-uid is undefined"

        # FIRST, look for a match on uid.  If there is none, there's
        # nothing to be done.
        if {![info exists uidmap($uid)]} {
            return
        }

        # NEXT, delete the entry.
        $tlist delete $uidmap($uid)

        # NEXT, clear the array
        array unset uidmap

        # NEXT, rebuild the uidmap
        set cindex [$self cname2cindex $options(-uid)]
        set uids [$tlist getcolumns $cindex]
        set rindex -1

        foreach uid $uids {
            set uidmap($uid) [incr rindex]
        }
        
        # NEXT, schedule the -selectioncmd
        $changer schedule -nocomplain
    }
    
    
    # uid select uids
    #
    # uids    A list of UIDs
    #
    # Selects the rows with the associated UIDs.  Unknown IDs
    # are ignored.
    # 
    # NOTE: Calling this command calls the -selectioncmd

    method {uid select} {uids} {
        $tlist selection clear 0 end
        
        set rows [list]

        foreach uid $uids {
            if {[info exists uidmap($uid)]} {
                lappend rows $uidmap($uid)
            }
        }

        $tlist selection set $rows
        
        callwith $options(-selectioncmd)
    }
    

    # uid setfg uid color
    #
    # uid    A row UID
    # color  The foreground color that the row should take
    # 
    # This method translates UID to row index and sets the
    # foreground color of that row to the requested color

    method {uid setfg} {uid color} {
        $tlist rowconfigure $uidmap($uid) -foreground $color
    }

    # uid setbg uid color
    #
    # uid    A row UID
    # color  The background color that the row should take
    # 
    # This method translates UID to row index and sets the
    # background color of that row to the requested color

    method {uid setbg} {uid color} {
        $tlist rowconfigure $uidmap($uid) -background $color
    }

    # uid setcellfg uid cname color
    #
    # uid     A row UID
    # cname   A column name
    # color   The background color that the cell should take
    # 
    # This method translates UID and cname to row index and cindex
    # and sets foreground color of the specified cell.

    method {uid setcellfg} {uid cname color} {
        set cindex [$self cname2cindex $cname]
        
        $tlist cellconfigure $uidmap($uid),$cindex -foreground $color
    }

    # uid setcellbg uid cname color
    #
    # uid     A row UID
    # cname   A column name
    # color   The background color that the cell should take
    # 
    # This method translates UID and cname to row index and cindex
    # and sets background color of the specified cell.

    method {uid setcellbg} {uid cname color} {
        set cindex [$self cname2cindex $cname]
        
        $tlist cellconfigure $uidmap($uid),$cindex -background $color
    }


    # uid setfont uid font
    #
    # uid   A row UID
    # font  The font
    #
    # This method sets the font for the specified row.

    method {uid setfont} {uid font} {
        $tlist rowconfigure $uidmap($uid) -font $font
    }
}