#-----------------------------------------------------------------------
# TITLE:
#    sqldocument.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Extensible SQL Database Object
#
#    This module defines the sqldocument(n) type.  Each instance 
#    of the type can wrap a single SQLite3 database handle, providing
#    access to all of the database handle's subcommands as well as
#    addition subcommands of its own.
#
#    Access to the database is document-centric: open/create the 
#    database, read and write until an appropriate save point is 
#    reached, then commit all changes.  In other words, it's expected
#    that any given database file has but one writer at a time, and
#    arbitrarily many writes are batched into a single transaction.
#    (Otherwise, each write would be a single transaction, and the necessary
#    locking and unlocking would cause a major performance hit.)
#
#    sqldocument(n) can be used to open and query any kind of SQL 
#    database file.  It addition, it can also create databases with
#    the necessary schema definitions to support other modules,
#    called sqlsections.  Each such module must adhere to the 
#    sqlsection(i) interface.  All definitions for all loaded sqlsection(i)
#    modules will be included in the created databases.
#
#    An sqlsection(i) module can define the following things:
#
#    * Persistent schema definitions
#    * Temporary schema definitions
#    * SQL functions
#
#    sqlsection(i) modules register themselves with sqldocument(n) on
#    load; sqldocument(n) queries the sqlsection(i) modules for their
#    definitions on database open and clear.  The names of the 
#    included sqlsection(i) modules are stored in such database's 
#    sqldocument_master table.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export sqldocument
}

#-----------------------------------------------------------------------
# sqldocument

snit::type ::marsutil::sqldocument {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*

        # Register self as an sqlsection(i) module
        $type register $type
    }

    #-------------------------------------------------------------------
    # Type Variables

    # List of registered sqlsection module names, in order of registration.
    typevariable registry {}   

    #-------------------------------------------------------------------
    # Type Methods

    # register section
    #
    # section     Fully qualified name of an sqlsection(i) module
    #
    # Registers the section for later use

    typemethod register {section} {
        if {[lsearch -exact $registry $section] == -1} {
            lappend registry $section
        }
    }

    # sections
    #
    # Returns a list of the names of the registered sections

    typemethod sections {} {
        return $registry
    }

    #-------------------------------------------------------------------
    # sqlsection(i)
    #
    # The following routines implement the module's sqlsection(i)
    # interface.

    # This module's sqlsection(i) schema
    typevariable section_schema {
        CREATE TABLE sqldocument_master (
            -- Name of a registered sqlsection(i) module
            section TEXT PRIMARY KEY
        );
    }

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "sqldocument(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        return [outdent $section_schema]
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
        set functions [list]

        lappend functions error     [list ::error]
        lappend functions format    [list ::format]
        lappend functions joinlist  [list ::join]
        lappend functions percent   [list ::marsutil::percent]
        lappend functions wallclock [list ::clock seconds]

        return $functions
   }


    #-------------------------------------------------------------------
    # Components

    component db   ;# The SQLite3 database command, or NullDatabase if none

    #-------------------------------------------------------------------
    # Options

    # TBD

    #-------------------------------------------------------------------
    # Instance variables

    # Array of data variables:
    #
    # dbIsOpen      Flag: 1 if there is an open database, and 0
    #               otherwise.
    # dbFile        Name of the current database file, or ""

    variable info -array {
        dbIsOpen 0
        dbFile   {}
    }

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {} {
        # FIRST, we have no database; set the db component accordingly.
        set db [myproc NullDatabase]
    }


    #-------------------------------------------------------------------
    # Public Methods: Database Management

    # open ?filename?
    #
    # filename         database file name
    #
    # Opens the database file, creating it if necessary.  Does not
    # change the database in any way; use "clear" to initialize it.
    # If filename is not specified, will reopen the previous file, if any.
    
    method open {{filename ""}} {
        # FIRST, the database must not already be open!
        require {!$info(dbIsOpen)} "database is already open"

        # NEXT, get the file name.
        if {$filename eq ""} {
            require {$info(dbFile) ne ""} "database file name not specified"

            set filename $info(dbFile)
        }

        # NEXT, attempt to open the database and define the db component.
        # 
        # NOTE: since the db command is defined in the instance
        # namespace, it will be destroyed automatically when the
        # instance is destroyed.  Note that uncommitted updates will
        # *not* be saved.
        set db ${selfns}::db

        sqlite3 $db $filename

        # NEXT, set the hardware security requirement
        $db eval {
            -- We don't need to safeguard the database from 
            -- hardware errors.
            PRAGMA synchronous=OFF;

            -- Keep temporary data in memory
            PRAGMA temp_store=MEMORY;
        }

        # NEXT, define the temporary tables
        $self DefineTempSchema

        # NEXT, define standard functions.
        $self DefineFunctions

        # NEXT, save the file name; we are in business
        set info(dbFile)   $filename
        set info(dbIsOpen) 1

        # NEXT, open the initial transaction.
        $db eval {BEGIN IMMEDIATE TRANSACTION;}        

    }

    # clear
    #
    # Initializes the database, clearing old content and redefining
    # the schema according to the registered list of sqlsections.

    method clear {} {
        # FIRST, are the requirements for clearing the database met?
        require {$info(dbIsOpen)}         "database is not open"

        # NEXT, Clear the current contents, if any, and set up the 
        # schema.  If the database is being written to by another
        # application, we will get a "database is locked" error.

        if {[catch {$self DefineSchema} result]} {
            if {$result eq "database is locked"} {
                error $result
            } else {
                error "could not initialize database: $result"
            }
        }
    }

    # DefineSchema
    #
    # Deletes old data from the database, and defines the proper schema.

    method DefineSchema {} {
        # FIRST, commit any open transaction.  If it fails, that's no
        # big deal.
        catch {$db eval {COMMIT TRANSACTION;}}

        # NEXT, open an exclusive transaction; if there's another
        # application attached to this database file, 
        # we'll get a "database is locked" error.
        $db eval {BEGIN EXCLUSIVE TRANSACTION}

        # NEXT, clear any old content
        sqlib clear $db

        # NEXT, define persistent schema entities
        foreach section $registry {
            set schema [$section sqlsection schema]

            if {$schema ne ""} {
                $db eval $schema
            }
        }

        # NEXT, insert the section names into the sqldocument_master
        # table, for later use.
        foreach section $registry {
            $db eval {
                INSERT INTO sqldocument_master(section)
                VALUES($section)
            }
        }

        # NEXT, define temporary schema entities
        $self DefineTempSchema

        # NEXT, commit the schema changes
        $db eval {COMMIT TRANSACTION;}

        # NEXT, begin an immediate transaction; we want there to be a
        # transaction open at all times.  We'll commit the data to
        # disk from time to time.
        $db eval {BEGIN IMMEDIATE TRANSACTION;}
    }

    # DefineTempSchema
    #
    # Define the temporary tables for the sqlsections included in
    # the registry.  This should be called on both "open"
    # and "clear", so that the temporary tables are always defined.
    #
    # NOTE: Possibly, we should only define the temporary schema for
    # modules already included in the database.  On other hand,
    # if we define extra, what's the big deal?  And similarly,
    # if a module no longer exists, what are we to do?  We don't
    # want to fail to open the database!

    method DefineTempSchema {} {
        foreach section $registry {
            set schema [$section sqlsection tempschema]

            if {$schema ne ""} {
                $db eval $schema
            }
        }
    }

    # DefineFunctions
    #
    # Define SQL functions.

    method DefineFunctions {} {
        foreach section $registry {
            foreach {name definition} [$section sqlsection functions] {
                $db function $name $definition
            }
        }
    }

    # lock tables
    #
    # tables      A list of table names
    #
    # Creates triggers which effectively make the listed tables read-only.
    # It's OK if the tables are already locked.  Note that locking
    # a table doesn't prevent the database from being "clear"ed.
    #
    # NOTE: Doesn't support attached databases.

    method lock {tables} {
        require {$info(dbIsOpen)} "database is not open"

        foreach table $tables {
            foreach event {DELETE INSERT UPDATE} {
                $db eval [outdent "
                    CREATE TRIGGER IF NOT EXISTS
                    sqldocument_lock_${event}_${table} BEFORE $event ON $table
                    BEGIN SELECT error('Table \"$table\" is read-only'); END;
                "]
            }
        }
    }

    # unlock tables
    #
    # tables      A list of table names
    #
    # Deletes any lock triggers. It's OK if the tables are already unlocked.
    #
    # NOTE: Doesn't support attached databases.

    method unlock {tables} {
        require {$info(dbIsOpen)} "database is not open"

        foreach table $tables {
            foreach event {DELETE INSERT UPDATE} {
                $db eval [outdent "
                    DROP TRIGGER IF EXISTS sqldocument_lock_${event}_${table}
                "]
            }
        }
    }

    # islocked table
    # 
    # table      The name of a table
    #
    # Returns 1 if the table is locked, and 0 otherwise.
    #
    # Note: if a table is a temporary table, the lock triggers will
    # *automatically* be temporary triggers; otherwise they will be
    # persistent triggers.  Thus, we need to look into both the
    # sqlite_master and the sqlite_temp_master for matching triggers.
    #
    # NOTE: Doesn't support attached databases.
   
    method islocked {table} {
        # Just query whether the UPDATE trigger exists
        set trigger "sqldocument_lock_UPDATE_$table"

        $db exists {
            SELECT name FROM sqlite_master
            WHERE name=$trigger
            UNION
            SELECT name FROM sqlite_temp_master
            WHERE name=$trigger
        }
    }

    # commit
    #
    # Commits all database changes to the db, and opens a new 
    # transaction.

    method commit {} {
        require {$info(dbIsOpen)} "database is not open"

        $db eval {
            COMMIT TRANSACTION;
            BEGIN IMMEDIATE TRANSACTION;
        }
    }

    # close
    #
    # Commits all changes and closes the wsdb.  Once this is done,
    # the database must be opened before it can be used.

    method close {} {
        require {$info(dbIsOpen)} "database is not open"

        # Try to commit any changes; but if it's not possible, it's
        # not possible.
        catch {$db eval {COMMIT TRANSACTION;}}
        $db close

        set info(dbIsOpen) 0
        set db [myproc NullDatabase]
    }

    #-------------------------------------------------------------------
    # Public Methods: General database queries

    # Delegated methods
    delegate method saveas to db using {::marsutil::sqlib %m %c}
    delegate method query  to db using {::marsutil::sqlib %m %c} 
    delegate method tables to db using {::marsutil::sqlib %m %c} 
    delegate method schema to db using {::marsutil::sqlib %m %c} 
    delegate method mat    to db using {::marsutil::sqlib %m %c} 
    delegate method *      to db

    # dbfile
    #
    # Returns the file name, if any

    method dbfile {} {
        return $info(dbFile)
    }

    # isopen
    #
    # Returns 1 if the database is open, and 0 otherwise.
    
    method isopen {} {
        return $info(dbIsOpen)
    }


    #-------------------------------------------------------------------
    # Utility Procs

    # NullDatabase args
    #
    # args       Arguments to the db component.  Ignored.
    #
    # Used as the db component when no database is open.  Causes all 
    # methods delegated to the db to be rejected with a good error
    # message

    proc NullDatabase {args} {
        return -code error "database is not open"
    }
}





