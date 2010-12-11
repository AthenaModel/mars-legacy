#-----------------------------------------------------------------------
# TITLE:
#	sqlib.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Mars: marsutil(n) Tcl Utilities
#
#	SQLite utilities
#
#       SQLite is a small SQL database manager for Tcl and other
#       languages.  This module defines a number of tools for use
#       with SQLite database objects.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export sqlib
}

#-----------------------------------------------------------------------
# sqlib Ensemble

snit::type ::marsutil::sqlib {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # clear db
    #
    # db     The fully-qualified SQLite database command.
    #
    # Deletes all persistent and temporary schema elements from the 
    # database.  Attached databases are ignored.

    typemethod clear {db} {
        set sql [list]

        $db eval {
            SELECT type AS dbtype, name FROM sqlite_master
            WHERE type IN ('table', 'view')
            UNION ALL
            SELECT type AS dbtype, name FROM sqlite_temp_master 
            WHERE type IN ('table', 'view')
        } {
            switch -exact -- $dbtype {
                table {
                    if {![string match "sqlite*" $name]} {
                        lappend sql "DROP TABLE $name;"
                    } else {
                        lappend sql "DELETE FROM $name;"
                    }
                }

                view {
                    lappend sql "DROP VIEW $name;"
                }
                default {
                    # Do nothing
                }
            }
        }

        $db eval [join $sql "\n"]
    }

    # saveas db filename
    #
    # db          The fully-qualified SQLite database command.
    # filename    A file name
    #
    # Saves a copy of the persistent contents of db as a new 
    # database file called filename.  It's an error if filename
    # already exists.

    typemethod saveas {db filename} {
        require {![file exists $filename]} \
            "File already exists: \"$filename\""

        # FIRST, create the saveas database.  This might throw
        # an error if the database cannot be opened.
        sqlite3 sadb $filename

        # NEXT, copy the schema and the user_version
        sadb transaction {
            set ver [$db eval {PRAGMA user_version}]

            sadb eval "PRAGMA user_version=$ver"

            $db eval {
                SELECT sql FROM sqlite_master 
                WHERE sql NOT NULL
                AND name NOT GLOB 'sqlite*'
            } {
                sadb eval $sql
            }
        }

        # NEXT, close the saveas database, and attach it to
        # db temporarily so we can copy tables.  If db is
        # in a transaction, we need to commit it. (Sigh!)

        sadb close

        $db eval "ATTACH DATABASE '$filename' AS saveas"

        # NEXT, copy the tables
        set tableList [$db eval {
            SELECT name FROM sqlite_master 
            WHERE type='table'
            AND name NOT GLOB 'sqlite*'
        }]

        $db transaction {
            foreach table $tableList {
                $db eval "INSERT INTO saveas.$table SELECT * FROM main.$table"
            }
        }

        # NEXT, detach the saveas database.
        $db eval {DETACH DATABASE saveas}
    }

    # compare db1 db2
    #
    # db1     A fully-qualified SQLite database command.
    # db2     Another fully-qualified SQLite database command.
    #
    # Compares the two databases, ignoring attached databases and
    # temporary entities.  Returns a string describing the first
    # difference found, or "" if no differences are found.  This is
    # not a particularly fast operation for large databases.
    #
    # First the schema is compared, and then the content of the
    # individual tables.

    typemethod compare {db1 db2} {
        set rows [list]

        # FIRST, get the rows from db1's master table
        $db1 eval {
            SELECT * FROM sqlite_master
            WHERE name NOT GLOB "sqlite*"
            ORDER BY name
        } row1 {
            lappend rows [array get row1]
        }

        # NEXT, compare them against the rows from db2's master table
        $db2 eval {
            SELECT * FROM sqlite_master
            WHERE name NOT GLOB "sqlite*"
            ORDER BY name
        } row2 {
            if {[llength $rows] == 0} {
                return \
                    "In $db2, found $row2(type) $row2(name), missing in $db1"
            }

            array set row1 [lshift rows]

            if {$row1(name) ne $row2(name)} {
                return \
    "In $db2, found $row2(type) $row2(name), expected $row1(type) $row1(name)"
            }

            foreach column {type tbl_name sql} {
                if {$row1($column) ne $row2($column)} {
                    return \
                        "Mismatch on \"$column\" for $row1(type) $row1(name)"
                }
            }
        }

        if {[llength $rows] > 0} {
            array set row1 [lshift rows]

            return "In $db1, found $row1(type) $row1(name), missing in $db2"
        }

        # NEXT, compare the individual tables.
        set tableList [$db1 eval {
            SELECT name FROM sqlite_master
            WHERE name NOT GLOB 'sqlite*'
            AND type == 'table'
            ORDER BY name
        }]

        foreach table $tableList {
            # FIRST, get all of the rows in db1's table
            set rows [list]
            array unset row1
            array unset row2

            $db1 eval "
                SELECT * FROM $table
            " row1 {
                unset -nocomplain row1(*)
                lappend rows [array get row1]
            }

            # NEXT, compare against each row in db2's table
            $db2 eval "
                SELECT * FROM $table
            " row2 {
                unset -nocomplain row2(*)

                if {[llength $rows] == 0} {
                    return \
                        "Table $table contains more rows in $db2 than in $db1"
                }

                array unset row1
                array set row1 [lshift rows]

                foreach column [array names row1] {
                    if {$row1($column) ne $row2($column)} {
                        return \
      "Mismatch on \"$column\" for table $table:\n$db1: [array get row1]\n$db2: [array get row2]"
                    }
                }
            }

            if {[llength $rows] > 0} {
                return "Table $table contains more rows in $db1 than in $db2"
            }
        }

        return ""
    }


    # tables db
    #
    # db     The fully-qualified SQLite database command.
    #
    # Returns a list of the names of the tables defined in the database.
    # Includes attached databases.

    typemethod tables {db} {
        set cmd {
            SELECT name FROM sqlite_master WHERE type='table'
            UNION ALL
            SELECT name FROM sqlite_temp_master WHERE type='table'
        }

        $db eval {PRAGMA database_list} {
            if {$name != "temp" && $name != "main"} {
                append cmd \
                    "UNION ALL SELECT '$name.' || name FROM $name.sqlite_master
                     WHERE type='table'"
            }
        }

        append cmd { ORDER BY 1 }

        return [$db eval $cmd]
    }

    # schema db ?table?
    #
    # db      The fully-qualified SQLite database command.
    # table   A table name or glob-pattern.
    #
    # Returns the SQL statements that define the schema.  If table
    # is given, returns only those tables/views/indices whose names
    # match the pattern.  Skips attached tables.

    typemethod schema {db {table "*"}} {
        set cmd {
            SELECT sql FROM sqlite_master 
            WHERE name GLOB $table
            AND sql NOT NULL 
            UNION ALL 
            SELECT sql FROM sqlite_temp_master
            WHERE name GLOB $table
            AND sql NOT NULL
        }

        return [join [$db eval $cmd] ";\n\n"]
    }

    # columns db table
    #
    # db          - The fully-qualified SQLite database command
    # table       - A table name in the db
    #
    # Returns a list of the table's column names, in order of
    # definitions, as returned by PRAGMA table_list().

    typemethod columns {db table} {
        set names [list]

        $db eval "PRAGMA table_info($table)" row {
            lappend names $row(name)
        }

        return $names
    }

    # query db sql ?options...?
    #
    # db            The fully-qualified SQLite database command.
    # sql           An SQL query.
    # options       Formatting options
    #
    #   -mode mc|list        Display mode: mc (multicolumn) or list
    #   -maxcolwidth num     Maximum displayed column width, in 
    #                        characters.
    #   -labels list         List of column labels.
    #   -headercols n        Number of header columns (default 0)
    #
    # Executes the query and accumulates the results into a nice
    # formatted output.
    #
    # If -mode is "list", each record is output in two-column
    # format: name  value, etc., with a blank line between records.
    #
    # If -mode is "mc" (the default) then multicolumn output is used.
    # In this mode, long values are truncated to -maxcolwidth.
    #
    # In either case, newlines are escaped.  If -labels is specified,
    # it is a list of column labels which are displayed instead of the 
    # column names used in the query.
    #
    # If -mode is "mc" and -headercols is greater than 0, then 
    # duplicate entries in the leading columns are omitted.

    typemethod query {db sql args} {
        # FIRST, get options.
        array set opts {
            -mode         mc
            -maxcolwidth  30
            -labels       {}
            -headercols   0
        }
        array set opts $args

        # NEXT, if the mode is "list", output the records individually
        if {$opts(-mode) eq "list"} {
            # FIRST, do the query; we'll output the data as we go.
            set out ""
            set labels {}
            set count 0

            $db eval $sql row {
                # FIRST, The first time figure out what the labels are.
                if {[llength $labels] == 0} {
                    # Did they specify labels?
                    if {[llength $opts(-labels)] > 0} {
                        set labels $opts(-labels)
                    } else {
                        set labels $row(*)
                    }

                    # What's the maximum label width?
                    set labelWidth [lmaxlen $labels]
                }

                # NEXT, output the record
                incr count

                if {$count > 1} {
                    append out "\n"
                }

                foreach label $labels name $row(*) {
                    set leader [string repeat " " $labelWidth]

                    regsub -all {\n} [string trimright $row($name)] \
                        "\n$leader  " value

                    append out \
                        [format "%-*s  %s\n" $labelWidth $label $value]
                }
            }
            
            # NEXT, return the result.
            return $out
        }

        # NEXT, if the mode is not "mc", that's an error.
        if {$opts(-mode) ne "mc"} {
            error "invalid -mode: \"$opts(-mode)\""
        }

        # NEXT, get the data; accumulate column widths as we go.
        set rows {}
        set names {}
        $db eval $sql row {
            if {[llength $names] eq 0} {
                set names $row(*)
                unset row(*)

                foreach name $names {
                    set colwidth($name) 0
                }
            }

            foreach name $names {
                set row($name) [string map [list \n \\n] $row($name)]

                set len [string length $row($name)]

                if {$opts(-maxcolwidth) > 0} {
                    if {$len > $opts(-maxcolwidth)} {
                        # At least three characters
                        set len [::marsutil::max $opts(-maxcolwidth) 3]
                        set end [expr {$len - 4}]
                        set row($name) \
                            "[string range $row($name) 0 $end]..."
                    }
                }

                if {$len > $colwidth($name)} {
                    set colwidth($name) $len
                }
            }

            lappend rows [array get row]
        }

        if {[llength $names] == 0} {
            return ""
        }

        # NEXT, include the label widths.
        if {[llength $opts(-labels)] > 0} {
            set labels $opts(-labels)
        } else {
            set labels $names
        }

        foreach label $labels name $names {
            set len [string length $label]

            if {$len > $colwidth($name)} {
                set colwidth($name) $len
            }
        }

        # NEXT, format the header lines.
        set out ""

        foreach label $labels name $names {
            append out [format "%-*s " $colwidth($name) $label]
        }
        append out "\n"

        foreach name $names {
            append out [string repeat "-" $colwidth($name)]
            append out " "

            # Initialize the lastrow array
            set lastrow($name) ""
        }
        append out "\n"
        
        # NEXT, format the rows
        foreach entry $rows {
            array set row $entry

            set i 0
            foreach name $names {
                # Append either the column value or a blank, with the
                # required width
                if {$i < $opts(-headercols) && 
                    $row($name) eq $lastrow($name)} {
                    append out [format "%-*s " $colwidth($name) "\""]
                } else {
                    append out [format "%-*s " $colwidth($name) $row($name)]
                }
                incr i
            }
            append out "\n"

            array set lastrow $entry
        }

        return $out
    }

    # mat db table iname jname ename ?options?
    #
    # db      An sqlite3 database object.
    # table   A table in the database.
    # iname   The name of the "i" or "row" column.
    # jname   The name of the "j" or "column" column.
    # ename   The name of the "element" column.
    # 
    # Options:
    #    -ikeys       A list of the "i" column keys, in the desired order
    #    -jkeys       A list of the "j" column keys, in the desired order
    #    -returnkeys  0|1.  If 1, the key lists are returned.
    #    -defvalue    Value for empty cells.
    #
    # Queries the named table, producing a matrix whose elements are
    # drawn from the element column, with the iname column defining
    # the rows and the jname column defining the columns.  If -ikeys
    # or -jkeys are specified, iname or jname values not included in
    # the lists will be excluded from the output, and the matrix rows
    # and columns will be in the order specified.  Otherwise, there
    # will be a row for each unique value in the iname column and a
    # column for each unique value in the jname column.
    #
    # Normally, the command returns the matrix.  If -returnkeys is 1,
    # the command returns a list {matrix ikeys jkeys}.

    typemethod mat {db table iname jname ename args} {
        # FIRST, get the options
        array set opts {
            -ikeys      ""
            -jkeys      ""
            -returnkeys 0
            -defvalue   ""
        }
        array set opts $args

        # NEXT, if no keys are specified, get the full list.
        if {[llength $opts(-ikeys)] == 0} {
            set opts(-ikeys) [rdb query "
                SELECT $iname FROM $table GROUP BY $iname
            "]
        }

        if {[llength $opts(-jkeys)] == 0} {
            set opts(-jkeys) [rdb query "
                SELECT $jname FROM $table GROUP BY $jname
            "]
        }

        # NEXT, get the matrix.
        set mat [mat new \
                     [llength $opts(-ikeys)] \
                     [llength $opts(-jkeys)] \
                     $opts(-defvalue)]

        rdb eval "
            SELECT $iname AS iname, 
                   $jname AS jname, 
                   $ename AS element
            FROM   $table
            WHERE  $iname IN ('[join $opts(-ikeys) ',']')
            AND    $jname IN ('[join $opts(-jkeys) ',']')
        " {
            set i [lsearch -exact $opts(-ikeys) $iname]
            set j [lsearch -exact $opts(-jkeys) $jname]

            lset mat $i $j $element
        }

        # NEXT, return the result.
        if {$opts(-returnkeys)} {
            return [list $mat $opts(-ikeys) $opts(-jkeys)]
        } else {
            return $mat
        }
    }

    # insert db table dict
    #
    # db      A database handle
    # table   Name of a table in db
    # dict    A dictionary whose keys are column names in the table
    #
    # Inserts the contents of dict into table.  This will be less
    # efficient than an explicit "INSERT INTO" with hardcoded column
    # names, but where performance isn't an issue it wins on 
    # maintainability.
    #
    # WARNING: None of the dict columns can be named "sqlib_table".

    typemethod insert {db table dict} {
        set sqlib_table $table
        set keys [dict keys $dict]

        dict with dict {
            $db eval [tsubst {
                INSERT INTO ${sqlib_table}([join $keys ,])
                VALUES(\$[join $keys ,\$])
            }]
        }
    }

    # replace db table dict
    #
    # db      A database handle
    # table   Name of a table in db
    # dict    A dictionary whose keys are column names in the table
    #
    # Inserts or replaces the contents of dict into table.  This will 
    # be less efficient than an explicit "INSERT OR REPLACE INTO" with 
    # hardcoded column names, but where performance isn't an issue it 
    # wins on  maintainability.
    #
    # WARNING: None of the dict columns can be named "sqlib_table".

    typemethod replace {db table dict} {
        set sqlib_table $table
        set keys [dict keys $dict]

        dict with dict {
            $db eval [tsubst {
                INSERT OR REPLACE INTO ${sqlib_table}([join $keys ,])
                VALUES(\$[join $keys ,\$])
            }]
        }
    }

    # grab db ?-tcl? table condition ?table condition...?
    #
    # db        - A database handle
    # table     - Name of a table in db
    # condition - A WHERE expression describing rows in the table.
    #
    # Grabs a collection of rows from one or more tables in the 
    # database, and returns them to the user as one value, a 
    # flat list with structure
    #
    #    <table> <values> ...
    #
    # where <table> is the table name and <values> is a flat list 
    # of column values for the columns in table.  The individual
    # column values are SQL-quoted appropriately for direct insertion 
    # into an INSERT statement; this allows grab/ungrab to preserve
    # NULLs.
    #
    # If the -tcl option is included before the first table
    # name, the values will not be SQL-quoted.

    typemethod grab {db args} {
        # FIRST, prepare to stash the grabbed data
        set result [list]

        # NEXT, get the option, if any.
        if {[lindex $args 0] eq "-tcl"} {
            lshift args
            set tclSyntax 1
        } else {
            set tclSyntax 0
        }

        # NEXT, grab rows for each table.
        foreach {table condition} $args {
            set quotes [list]

            foreach name [sqlib columns $db $table] {
                if {$tclSyntax} {
                    lappend quotes $name
                } else {
                    lappend quotes "quote($name)"
                }
            }

            set query "SELECT [join $quotes ,] FROM $table"

            if {$condition ne ""} {
                append query " WHERE $condition"
            }
            
            set rows [uplevel 1 [list $db eval $query]]

            if {[llength $rows] > 0} {
                lappend result $table $rows
            }
        }

        return $result
    }

    # ungrab db data
    #
    # db       - A database handle
    # data     - A list {table values ?table values...?} as returned
    #            by grab.
    #
    # Puts row data into each table using INSERT OR REPLACE.
    # Each "values" entry must be a list of column values quoted
    # appropriately for direct inclusion in an INSERT statement.
    # The length of the "values" entry must be a multiple of the
    # the number of columns in the table.

    typemethod ungrab {db data} {
        set sql ""

        foreach {table values} $data {
            # FIRST, get the number of columns in this table.
            set len [llength [sqlib columns $db $table]]

            require {$len > 0} "Unknown table: \"$table\""

            # NEXT, set up the query
            while {[llength $values] > 0} {
                set row    [lrange $values 0 $len-1]
                set values [lrange $values $len end]

                append sql \
                    "INSERT OR REPLACE INTO $table VALUES([join $row ,]);\n"
            }
        }

        # NEXT, evaluate the query.
        $db eval $sql
    }

    # fklist db table ?-indirect?
    #
    # db      - A database handle
    # table   - A table in the database
    #
    # Retrieves a list of the tables that have foreign keys that
    # references the given table.  If the -indirect option is given,
    # tables that depend on those are included.

    typemethod fklist {db table {opt ""}} {
        if {$opt ni {"" -indirect}} {
            error "invalid option: \"$opt\""
        }

        # FIRST, get the basic dependency data
        set tables [sqlib tables $db]

        if {$table ni $tables} {
            error "unknown table: \"$table\""
        }

        foreach tab $tables {
            $db eval "PRAGMA foreign_key_list($tab)" row {
                ladd dep($row(table)) $tab
            }
        }

        # NEXT, if there are no dependencies on this table, return
        # the empty list.
        if {![info exists dep($table)]} {
            return [list]
        }

        # NEXT, if they just want the direct dependencies, return them.
        if {$opt eq ""} {
            # The user knows the table depends on itself; if there's
            # a foreign key, ignore it.
            ldelete dep($table) $table
            return $dep($table)
        }

        # NEXT, if they want the indirect dependencies, compute and return
        # them.
        
        lappend depList $table
        set result [list]

        while {[llength $depList] > 0} {
            set next [lshift depList]
            if {$next ni $result} {
                lappend result $next

                if {[info exists dep($next)]} {
                    lappend depList {*}$dep($next)
                }
            }
        }

        # Skip the original table
        return [lrange $result 1 end]
    }

    #-------------------------------------------------------------------
    # grabbing_delete
    #
    # The following variables and routines are all related to the
    # "grabbing_delete" mechanism.

    # grab_data: A transient dictionary of grabbed rows.
    typevariable grab_data

    # grabbing_delete db table condition
    #
    # db         - An sqldocument handle
    # table      - A table in the db
    # condition  - A where condition specifying the rows to delete.
    #
    # Deletes the records, and returns a grab of the data that was deleted,
    # including cascading deletes.

    typemethod grabbing_delete {db table condition} {
        # FIRST, define the sqlib_grab() function on the DB.
        $db function sqlib_grab ${type}::GrabFunc

        # NEXT, define delete triggers on table and its dependents.
        set tables [GetDependentTables $db $table]
        SetDeleteTraces $db $tables

        # NEXT, clear the grab_data
        set grab_data [dict create]

        # NEXT, delete the data
        uplevel 1 [list $db eval "DELETE FROM $table WHERE $condition"]

        # NEXT, remove the triggers
        DropDeleteTraces $db $tables

        # NEXT, return the grabbed data, while clearing the cache.
        set result $grab_data
        set grab_data [dict create]

        return $result
    }

    
    # GrabFunc table values...
    #
    # table   - A table name
    # values  - A list of column values for a row.
    #
    # Stashes the grabbed data in the grab_data dict.

    proc GrabFunc {table args} {
        dict lappend grab_data $table {*}$args
        return
    }


    # GetDependentTables db table
    #
    # db         - An sqldocument handle
    # table      - A table in the db
    #
    # Returns the names of tables affected by a cascading delete on the 
    # specified table, *including* the specified table.
    #
    # TBD: Consider adding an option to fklist to get just the
    # cascading delete tables.

    proc GetDependentTables {db table} {
        # FIRST, for each table in the database, get the foreign key list, 
        # and record dependencies.
        foreach tab [sqlib tables $db] {
            $db eval "PRAGMA foreign_key_list($tab)" row {
                if {$row(on_delete) eq "CASCADE"} {
                    lappend dep($row(table)) $tab
                }
            }
        }

        # NEXT, starting with the subject table, get a list of the
        # distinct tables in the dependency tree.
        lappend depList $table
        set result [list]

        while {[llength $depList] > 0} {
            set next [lshift depList]
            if {$next ni $result} {
                lappend result $next

                if {[info exists dep($next)]} {
                    lappend depList {*}$dep($next)
                }
            }
        }

        # NEXT, return the list of tables.
        return $result
    }

    # SetDeleteTraces db tables
    #
    # db       - An sqldocument(n)
    # tables   - A list of tables in the db
    #
    # Adds a delete trace trigger on the tables, to grab the
    # data to be deleted.

    proc SetDeleteTraces {db tables} {
        foreach table $tables {
            set names [sqlib columns $db $table]

            $db eval "
                DROP TRIGGER IF EXISTS sqlib_trace_${table};

                CREATE TEMP TRIGGER sqlib_trace_${table}
                BEFORE DELETE ON $table BEGIN
                SELECT sqlib_grab('$table',quote(old.[join $names ),quote(old.]));
                END;
            "
        }
    }

    # DropDeleteTraces db tables
    #
    # db       - An sqldocument(n)
    # tables   - A list of tables in the db
    #
    # Drops the delete trace triggers from the tables.

    proc DropDeleteTraces {db tables} {
        foreach table $tables {
            $db eval "
                DROP TRIGGER IF EXISTS sqlib_trace_${table};
            "
        }
    }
}





