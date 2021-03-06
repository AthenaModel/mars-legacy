#-----------------------------------------------------------------------
# TITLE:
#    reporter.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Report Manager
#
#    This module defines the reporter(n) report manager.  The
#    reporter saves reports in the database, and categorizes them
#    according to application-defined bins.  It also allows particular
#    reports to be added and removed from a "hotlist".
#
#    The report manager is designed to work in both monolithic and
#    client/server settings; see the man page for details.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export reporter
}

#-----------------------------------------------------------------------
# scenario

snit::type ::marsutil::reporter {
    # Singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent db                         ;# The sqldocument(n).
    typecomponent clock                      ;# The simclock(i).

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*

        # NEXT, initialize the components
        set db    [myproc NullDB]
        set clock [myproc NullClock]
    }


    #-------------------------------------------------------------------
    # sqlsection(i)
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "reporter(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::marsutil::library reporter.sql]]
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return ""
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        return ""
    }

    #-------------------------------------------------------------------
    # Type Variables

    # reportcmd -- callback when report is saved
    typevariable reportcmd {}

    # deletecmd -- callback when report is deleted
    typevariable deletecmd {}


    # Array - Bin Definitions
    #
    #    bins        List of names of all bins
    #    kids-$bin:  List of names of child bins.  Top-level bins
    #                are children of "".
    #    bin-$bin:   Dictionary of data for this bin
    #                 bin     $bin
    #                 title   The bin title
    #                 parent  The parent bin, or ""
    #                 query   The SELECT statement
    #                 view    The view name
    
    typevariable bins -array {
        bins  {}
        kids- {}
    }


    #-------------------------------------------------------------------
    # Option Management

    # configure option value ?option value...?
    #
    # Configures the reporter(n) options:
    #
    # -clock      The simclock(i) for timestamping reports.
    # -db         The sqldocument(n) into which reports are written.
    # -deletecmd  The callback for when reports are deleted
    # -reportcmd  The callback for when reports are saved

    typemethod configure {args} {
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -clock { 
                    set clock [lshift args] 

                    if {$clock eq ""} {
                        set clock [myproc NullClock]
                    }
                }

                -db { 
                    set db [lshift args] 

                    if {$db eq ""} {
                        set db [myproc NullDB]
                    } else {
                        require {$type in [$db sections]} \
                            "reporter(n) is not registered with database $db"
                    }
                }

                -deletecmd {
                    set deletecmd [lshift args]
                }

                -reportcmd {
                    set reportcmd [lshift args]
                }

                default { 
                    error "unknown option: \"$opt\"" 
                }
            }
        }
    }

    # cget option
    #
    # option    A reporter(n) option
    #
    # Returns the option's value

    typemethod cget {option} {
        switch -exact -- $option {
            -clock     { set result $clock     }
            -db        { set result $db        }
            -deletecmd { return $deletecmd     }
            -reportcmd { return $reportcmd     }

            default { 
                error "unknown option: \"$option\"" 
            }
        }

        if {[string match "${type}::Null*" $result]} {
            set result ""
        }

        return $result
    }


    #-------------------------------------------------------------------
    # Report Bins

    # bin clear 
    #
    # Deletes all bins.

    typemethod {bin clear} {} {
        # FIRST, drop any views that exist
        foreach bin $bins(bins) {
            set view [dict get $bins(bin-$bin) view]

            $db eval "DROP VIEW IF EXISTS $view"
        }

        # NEXT, clear all of the bin data
        array unset bins
        set bins(bins) {}
        set bins(kids-) {}
    }

    # bin define bin title parent query
    #
    # bin     The bin's symbolic name
    # title   The bin's title, used for display
    # parent  The parent bin's symbolic name, or "" for a top-level bin.
    # query   The SELECT statement that defines the bin.
    #
    # Defines a bin.  The query should begin with
    # "SELECT * FROM reports ..."; it may reference any of
    # the reports columns.  If the bin has a parent, its query should
    # yield a subset of it's parent's query.

    typemethod {bin define} {bin title parent query} {
        # FIRST, check the inputs
        if {$parent ne ""} {
            require {[info exists bins(bin-$parent)]} \
                "no such parent bin: \"$parent\""
        }


        # NEXT, try to create a view for the bin
        set view "reports_bin_$bin"

        # NEXT, we don't really need to define it here,
        # as the call to "view" will define it again...but this
        # way we catch any SQL errors immediately.
        $db eval "
            DROP VIEW IF EXISTS $view;
            CREATE TEMPORARY VIEW $view AS
            $query;
        "

        # NEXT, remember the bin
        lappend bins(bins) $bin

        # NEXT, Add the bin to the list of its parent's children
        if {$bin ni $bins(kids-$parent)} {
            lappend bins(kids-$parent) $bin
        }

        # NEXT, save the bin data.
        set bins(bin-$bin)                            \
            [dict create                              \
                 bin $bin title $title parent $parent \
                 query $query view $view]

        if {![info exists bins(kids-$bin)]} {
            set bins(kids-$bin) {}
        }

        return
    }


    # bin children ?bin?
    #
    # bin     A bin's symbolic name
    #
    # By default, returns a list of the names of the top-level bins.
    # If a bin is given, returns a list of the names of the bin's
    # children.

    typemethod {bin children} {{bin ""}} {
        require {[info exists bins(kids-$bin)]} \
            "no such bin: \"$bin\""

        return $bins(kids-$bin)
    }
    

    # bin view bin
    #
    # bin   A bin's symbolic name
    #
    # Returns the name of the view for this bin.

    typemethod {bin view} {bin} {
        require {[info exists bins(bin-$bin)]} \
            "no such bin: \"$bin\""

        dict with bins(bin-$bin) {
            # FIRST, define the view, in case the database has
            # changed.
            $db eval "
                DROP VIEW IF EXISTS $view;
                CREATE TEMPORARY VIEW $view AS
                $query;
            "

            # NEXT, return the view's name
            return $view
        }
    }

    # bin parent bin
    #
    # bin    A bin's symbolic name
    #
    # Returns the name of the bin's parent, or "" if none

    typemethod {bin parent} {bin} {
        require {[info exists bins(bin-$bin)]} \
            "no such bin: \"$bin\""

        return [dict get $bins(bin-$bin) parent]
    }


    # bin title bin
    #
    # bin    A bin's symbolic name
    #
    # Returns the name of the bin's title

    typemethod {bin title} {bin} {
        require {[info exists bins(bin-$bin)]} \
            "no such bin: \"$bin\""

        return [dict get $bins(bin-$bin) title]
    }


    # bin getall
    #
    # Returns a string containing the full set of bin definitions.

    typemethod {bin getall} {} {
        set result [list]

        foreach bin $bins(bins) {
            set dict $bins(bin-$bin)
            lappend result [dict remove $bins(bin-$bin) view]
        }

        return $result
    }

    # bin setall bindefs
    #
    # bindefs     A set of bin definitions returned by "bin getall"
    #
    # Sets the bin definitions to the bindefs.

    typemethod {bin setall} {bindef} {
        # FIRST, clear all of the bin definitions
        reporter bin clear

        foreach dict $bindef {
            dict with dict {
                reporter bin define $bin $title $parent $query
            }
        }
    }
    
    

    #-------------------------------------------------------------------
    # Report Management

    # save options...
    #
    # -type        The rtype, e.g., "INPUT"; required.
    # -subtype     The report subtype, if any; defaults to ""
    # -title       The title of the report; required
    # -text        The formatted text of the report; required.
    # -requested   The requested flag, 1 or 0; defaults to 0.
    # -meta1       Meta-data, for binning.  Defaults to "".
    # -meta2       Meta-data, for binning.  Defaults to "".
    # -meta3       Meta-data, for binning.  Defaults to "".
    # -meta4       Meta-data, for binning.  Defaults to "".
    #
    # The following options are used on the client side:
    #
    #    -id       The report's ID
    #    -time     The report time, in ticks
    #    -stamp    The report's time stamp string
    #
    # Saves a report with the current timestamp, and notifies the
    # application, returning the report ID.

    typemethod save {args} {
        # FIRST, set the default option values:
        array set opts {
            -id        {}
            -rtype     {}
            -subtype   {}
            -title     {}
            -text      {}
            -requested 0
            -meta1     {}
            -meta2     {}
            -meta3     {}
            -meta4     {}
        }

        set opts(-time)  [$clock now]
        set opts(-stamp) [$clock asString]


        # NEXT, get and validate the required option values
        array set opts $args

        require {$opts(-title) ne ""} "Report has no -title"
        require {$opts(-text)  ne ""} "Report has no -text"

        # NEXT, save it to the runtime database
        if {$opts(-id) eq ""} {
            # Server side: ID is generated automatically
            $db eval {
                INSERT INTO 
                reports(rtype, 
                        subtype, 
                        time, 
                        stamp, 
                        title,
                        text,
                        requested,
                        meta1,
                        meta2,
                        meta3,
                        meta4)
                VALUES($opts(-rtype), 
                       $opts(-subtype), 
                       $opts(-time), 
                       $opts(-stamp), 
                       $opts(-title), 
                       $opts(-text),
                       $opts(-requested),
                       $opts(-meta1),
                       $opts(-meta2),
                       $opts(-meta3),
                       $opts(-meta4)); 
            }

            # Save the ID
            set opts(-id) [$db last_insert_rowid]
        } else {
            # We have an ID already
            $db eval {
                INSERT INTO 
                reports(id,
                        rtype, 
                        subtype, 
                        time, 
                        stamp, 
                        title,
                        text,
                        requested,
                        meta1,
                        meta2,
                        meta3,
                        meta4)
                VALUES($opts(-id),
                       $opts(-rtype), 
                       $opts(-subtype), 
                       $opts(-time), 
                       $opts(-stamp), 
                       $opts(-title), 
                       $opts(-text),
                       $opts(-requested),
                       $opts(-meta1),
                       $opts(-meta2),
                       $opts(-meta3),
                       $opts(-meta4)); 
            }
        }


        # NEXT, notify the application
        if {$reportcmd ne ""} {
            {*}$reportcmd [array get opts]
        }

        # NEXT, return the new row ID
        return $opts(-id)
    }

    # delete id
    #
    # Deletes the report with the specified ID.

    typemethod delete {id} {
        if {[$db exists {SELECT id FROM reports WHERE id=$id}]} {
            # FIRST, delete the report
            $db eval {
                DELETE FROM reports
                WHERE id=$id
            }

            # NEXT, notify the application
            if {$deletecmd ne ""} {
                {*}$deletecmd $id
            }
        }
    }


    #-------------------------------------------------------------------
    # Hot List Management


    # hotlist set idlist|all flag
    #
    # idlist   A list of report IDs, or "all"
    # flag     1 or 0
    #
    # Sets the hotlist flag for one or more reports.

    typemethod {hotlist set} {idlist flag} {
        if {$idlist eq "all"} {
            $db eval {
                UPDATE reports SET hotlist=$flag
            }
        } else {
            $db eval "
                UPDATE reports
                SET hotlist=$flag
                WHERE id IN ([join $idlist ,])
            "
        }
    }


    #-------------------------------------------------------------------
    # Utility Procs


    # NullDB ?args...?
    #
    # Throws an error when an undefined component is referenced.

    proc NullDB {option args} {
        error "reporter(n) option -db is has not been set."
    }

    # NullClock ?args...?
    #
    # Throws an error when an undefined component is referenced.

    proc NullClock {option args} {
        error "reporter(n)(n) option -clock is has not been set."
    }


}





