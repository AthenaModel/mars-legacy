#-----------------------------------------------------------------------
# TITLE:
#    gramdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Parser for the gramdb(5) database format.
#
#    This parser is based on tabletext(n) which provides a generic
#    mechanism for loading data from text files into SQLite3 tables.
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export gramdb
}

#-----------------------------------------------------------------------
# gramdb

snit::type ::simlib::gramdb {
    # Make it a singleton
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Import needed commands
        namespace import ::marsutil::* 
    }

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # List of the table names.
    typevariable tableNames {
        gramdb_c
        gramdb_g
        gramdb_n
        gramdb_mn
        gramdb_ng
        gramdb_gc
        gramdb_fg
        gramdb_ngc
        gramdb_nfg
    }

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "gramdb(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::simlib::library gramdb.sql]]
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
        return [list]
    }

    #-------------------------------------------------------------------
    # Type Components

    typecomponent tt               ;# tabletext(n) object

    #-------------------------------------------------------------------
    # Lookup Tables

    # Concern Definitions
    typevariable concernDefinitions {
        table gramdb_c {
            record c AUT {
                field gtype CIV 
            }

            record c QOL {
                field gtype CIV 
            }

            record c CUL {
                field gtype CIV 
            }

            record c SFT {
                field gtype CIV 
            }

            record c CAS {
                field gtype ORG 
            }

            record c SVC {
                field gtype ORG 
            }
        }
    }

    #-------------------------------------------------------------------
    # Type Variables

    typevariable initialized 0     ;# 1 if initialized, 0 otherwise.
                                    # gramdb is initialized on first use.

    #-------------------------------------------------------------------
    # Initialization

    typemethod Initialize {} {
        # FIRST, skip if we're already initialized
        if {$initialized} {
            return
        }

        set initialized 1

        # NEXT, define the parser.
        set tt [tabletext ${type}::tt]

        #---------------------------------------------------------------
        # Table: gramdb_c

        $tt table gramdb_c                                  \
            -tablevalidator [mytypemethod Val_gramdb_c]
        $tt field gramdb_c c -key                           \
            -validator [mytypemethod ValidateSymbolicName]
        $tt field gramdb_c gtype -required                  \
            -validator [mytypemethod ValidateEnum egrouptype]

        #---------------------------------------------------------------
        # Table: gramdb_g

         $tt table gramdb_g                                     \
           -tablevalidator  [mytypemethod Val_gramdb_g]         \
           -recordvalidator [mytypemethod Val_gramdb_g_record]
 
        $tt field gramdb_g g -key                                \
            -validator [mytypemethod ValidateSymbolicName]
        $tt field gramdb_g gtype                                 \
            -validator [mytypemethod ValidateEnum egrouptype]

        # CIVs and ORGs only
        $tt field gramdb_g rollup_weight                        \
            -validator [mytypemethod ValidateMagnitude]
        $tt field gramdb_g effects_factor                       \
            -validator [mytypemethod ValidateMagnitude]

        #---------------------------------------------------------------
        # Table: gramdb_n

        $tt table  gramdb_n                                 \
            -tablevalidator  [mytypemethod Val_gramdb_n]

        $tt field gramdb_n n -key                           \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table: gramdb_mn

        $tt table gramdb_mn -dependson gramdb_n                  \
            -tablevalidator  [mytypemethod Val_gramdb_mn]        \
            -recordvalidator [mytypemethod Val_gramdb_mn_record]

        $tt field gramdb_mn m -key                               \
            -validator [mytypemethod ValidateField gramdb_n n]
        $tt field gramdb_mn n -key                               \
            -validator [mytypemethod ValidateField gramdb_n n]
        $tt field gramdb_mn proximity                            \
            -validator [mytypemethod ValidateEnum eproximity]
        $tt field gramdb_mn effects_delay                      \
            -validator [mytypemethod ValidateMagnitude]



        #---------------------------------------------------------------
        # Table: gramdb_ng

        $tt table gramdb_ng -dependson {gramdb_n gramdb_g}         \
            -tablevalidator  [mytypemethod Val_gramdb_ng]

        $tt field gramdb_ng n -key                               \
            -validator [mytypemethod ValidateField gramdb_n n]
        $tt field gramdb_ng g -key                               \
            -validator [mytypemethod ValidateCivOrgPgroup] 
        $tt field gramdb_ng rollup_weight                        \
            -validator [mytypemethod ValidateMagnitude]
        $tt field gramdb_ng effects_factor                       \
            -validator [mytypemethod ValidateMagnitude]
        $tt field gramdb_ng population -required                 \
            -validator [mytypemethod ValidateIntMagnitude]

        #---------------------------------------------------------------
        # Table: gramdb_gc
        
        $tt table gramdb_gc -dependson {gramdb_g gramdb_c} \
            -tablevalidator [mytypemethod Val_gramdb_gc] \
            -recordvalidator [mytypemethod Val_gramdb_gc_record]

        $tt field gramdb_gc g -key \
            -validator [mytypemethod ValidateCivOrgPgroup]
        $tt field gramdb_gc c -key \
            -validator [mytypemethod ValidateField gramdb_c c]

        $tt field gramdb_gc sat0 \
            -validator [mytypemethod ValidateQuality qsat]
        $tt field gramdb_gc trend0 \
            -validator [mytypemethod ValidateQuality qtrend]
        $tt field gramdb_gc saliency \
            -validator [mytypemethod ValidateQuality qsaliency]
        
        #---------------------------------------------------------------
        # Table: gramdb_fg
        
        $tt table gramdb_fg -dependson gramdb_g \
            -tablevalidator [mytypemethod Val_gramdb_fg]

        $tt field gramdb_fg f -key \
            -validator [mytypemethod ValidateField gramdb_g g]
        $tt field gramdb_fg g -key \
            -validator [mytypemethod ValidateField gramdb_g g]

        $tt field gramdb_fg rel \
            -validator [mytypemethod ValidateQuality qrel]
        $tt field gramdb_fg coop0 \
            -validator [mytypemethod ValidateQuality qcooperation]

        #---------------------------------------------------------------
        # Table: gramdb_ngc
        
        $tt table gramdb_ngc -dependson {gramdb_n gramdb_g gramdb_c} \
            -tablevalidator  [mytypemethod Val_gramdb_ngc]           \
            -recordvalidator [mytypemethod Val_gramdb_ngc_record]

        $tt field gramdb_ngc n -key \
            -validator [mytypemethod ValidateField gramdb_n n]
        $tt field gramdb_ngc g -key \
            -validator [mytypemethod ValidateCivOrgPgroup]
        $tt field gramdb_ngc c -key \
            -validator [mytypemethod ValidateField gramdb_c c]

        $tt field gramdb_ngc sat0 \
            -validator [mytypemethod ValidateQuality qsat]
        $tt field gramdb_ngc trend0 \
            -validator [mytypemethod ValidateQuality qtrend]
        $tt field gramdb_ngc saliency \
            -validator [mytypemethod ValidateQuality qsaliency]

        #---------------------------------------------------------------
        # Table: gramdb_nfg
        
        $tt table gramdb_nfg -dependson {gramdb_n gramdb_g}       \
            -tablevalidator  [mytypemethod Val_gramdb_nfg]        \
            -recordvalidator [mytypemethod Val_gramdb_nfg_record]

        $tt field gramdb_nfg n -key \
            -validator [mytypemethod ValidateField gramdb_n n]
        $tt field gramdb_nfg f -key \
            -validator [mytypemethod ValidateField gramdb_g g]
        $tt field gramdb_nfg g -key \
            -validator [mytypemethod ValidateField gramdb_g g]

        $tt field gramdb_nfg rel \
            -validator [mytypemethod ValidateQuality qrel]
        $tt field gramdb_nfg coop0 \
            -validator [mytypemethod ValidateQuality qcooperation]
    }

    #-------------------------------------------------------------------
    # Generic Validators
    #
    # All validators take at least three arguments:
    #
    # db         The SQLite3 or sqldocument(n) object
    # table      The current table name
    # value      The value to validate
    #
    # Some take additional arguments at the beginning of the argument
    # list, to parameterize the validator.
    

    # ValidateSymbolicName db table value
    #
    # The value must be an "identifier" (see marsutil(n)); it
    # will be converted to uppercase.

    typemethod ValidateSymbolicName {db table value} {
        identifier validate $value
        return [string toupper $value]
    }


    # ValidateEnum enum db table value
    #
    # enum       An enum(n) object
    #
    # Value must be a valid value for the enum; the 
    # equivalent short name is returned.

    typemethod ValidateEnum {enum db table value} {
        $enum validate $value
        return [$enum name $value]
    }

    # ValidateQuality qual db table value
    #
    # qual       An quality(n) object
    #
    # Value must be a valid value for the quality; the 
    # equivalent "value" is returned.

    typemethod ValidateQuality {qual db table value} {
        $qual validate $value
        return [$qual value $value]
    }


    typemethod ValidateCivOrgPgroup {db table value} {
        $db eval {SELECT gtype FROM gramdb_g WHERE g=$value} row {

            require {$row(gtype) eq "CIV" || $row(gtype) eq "ORG"} \
                "expected CIV or ORG group, got: \"$value\""

            return $value
        }

        error "unknown group: \"$value\""
    }

    # ValidateField otherTable field db table value
    #
    # otherTable     The name of some other table
    # field          The name of a field in the other table
    #
    # The value must be a value found in the named field in the other
    # table.  If it is, it is returned unchanged.

    typemethod ValidateField {otherTable field db table value} {
        $db eval "SELECT rowid FROM $otherTable WHERE $field=\$value" row {
            return $value
        }

        error "unknown $otherTable $field: \"$value\""
    }

    # ValidateMagnitude db table value
    #
    # The value must be a numeric value (integer or decimal)
    # greater than or equal to zero.

    typemethod ValidateMagnitude {db table value} {
        require {[string is double -strict $value]} \
            "non-numeric input: \"$value\""
        require {$value >= 0} \
            "value is negative: \"$value\""

        return $value
    }

    # ValidateIntMagnitude db table value
    #
    # The value must be an integer value
    # greater than or equal to zero.

    typemethod ValidateIntMagnitude {db table value} {
        require {[string is integer -strict $value]} \
            "non-integer input: \"$value\""
        require {$value >= 0} \
            "value is negative: \"$value\""

        return $value
    }

    #-------------------------------------------------------------------
    # Table: gramdb_c

    typemethod Val_gramdb_c {db table} {
        # Must have at least one concern of each type
        foreach gtype {CIV ORG} {
            require {
                [$db exists {SELECT c FROM gramdb_c WHERE gtype=$gtype}]
            } "Zero concerns of type $gtype defined"
        }
    }

    #-------------------------------------------------------------------
    # Table: gramdb_g

    typemethod Val_gramdb_g {db table} {
        # Must have at least one of each type
        foreach gtype {CIV FRC ORG} {
            require {
                [$db exists {SELECT g FROM gramdb_g WHERE gtype=$gtype}]
            } "Zero groups of type $gtype defined"
        }
    }

    typemethod Val_gramdb_g_record {db table rowid} {
        # Verify that the necessary fields are defined, given the
        # group type.
        $db eval "SELECT * FROM $table WHERE rowid=\$rowid" row {}

        array set required {
            CIV {
                rollup_weight effects_factor
            }
            ORG {
                rollup_weight effects_factor
            }
            FRC { }
        }

        array set nulls {
            CIV { }
            ORG { }
            FRC {
                rollup_weight effects_factor
            }
        }
        
        foreach field $required($row(gtype)) {
            if {$row($field) eq ""} {
                error "missing field: $field"
            }
        }

        foreach field $nulls($row(gtype)) {
            $db eval "
                UPDATE gramdb_g
                SET $field = ''
                WHERE ROWID = \$rowid
            "
        }
    }

    #-------------------------------------------------------------------
    # Table: gramdb_n

    typemethod Val_gramdb_n {db table} {
        # FIRST, We must have at least one neighborhood
        require {
            [$db exists {SELECT n FROM gramdb_n}]
        } "no neighborhoods defined"
    }

    #-------------------------------------------------------------------
    # Table: gramdb_mn

    typemethod Val_gramdb_mn {db table} {
        # Fill out table with default values: HERE when m==n, FAR otherwise.

        set nbhoods [$db eval {SELECT n FROM gramdb_n}]

        foreach m $nbhoods {
            foreach n $nbhoods {
                let prox {$m == $n ? "HERE" : "FAR"}

                # Insert the record, if it doesn't exist
                $db eval {
                    INSERT OR IGNORE INTO gramdb_mn(m,n) 
                    VALUES($m,$n)
                }
            }
        }
        
        $db eval {
            UPDATE gramdb_mn
            SET proximity = "HERE"
            WHERE m = n AND proximity IS NULL;
            
            UPDATE gramdb_mn
            SET proximity = "FAR"
            WHERE m != n AND proximity IS NULL;
        }
    }
    
    typemethod Val_gramdb_mn_record {db table rowid} {
        # Verify that HERE is set only for m = n,
        # and that effects_delay is 0.0 when m = n.

        $db eval "SELECT * FROM $table WHERE rowid=\$rowid" row {
            if {$row(proximity) ne ""} {
                if {$row(m) eq $row(n)} {
                    require {$row(proximity) eq "HERE"} \
                        "mismatch, proximity must be HERE when m = n"
                } else {
                    require {$row(proximity) ne "HERE"} \
                        "mismatch, proximity must not be HERE when m != n"
                }
            }
            
            if {$row(effects_delay) ne "" && $row(m) eq $row(n)} {
                require {$row(effects_delay) == 0.0} \
                    "effects_delay must be 0.0 when m = n"
            }
        }
    }
    

    #-------------------------------------------------------------------
    # Table: gramdb_ng
    
    typemethod Val_gramdb_ng {db table} {
        # Fill in missing records.  
        # Population will default to 0 for all missing records.

        $db eval {
            INSERT OR IGNORE INTO gramdb_ng(n,g)
            SELECT n,g
            FROM gramdb_n JOIN gramdb_g
            WHERE gramdb_g.gtype IN ('CIV', 'ORG')
        }

        # Next, default NULL fields to the equivalent values from
        # gramdb_g.
        $db eval {
            SELECT g, rollup_weight, effects_factor FROM gramdb_g
        } {
            $db eval {
                UPDATE gramdb_ng
                SET rollup_weight = COALESCE(rollup_weight,$rollup_weight),
                    effects_factor = COALESCE(effects_factor,$effects_factor)
                WHERE gramdb_ng.g = $g
            }
        }

        # Ensure that there's at least one CIV group in each 
        # neighborhood with non-zero population.
        $db eval {
            SELECT n, TOTAL(population) AS sum
            FROM gramdb_ng JOIN gramdb_g USING (g)
            WHERE gramdb_g.gtype = 'CIV'
            GROUP BY n
        } {
            require {$sum > 0} \
            "neighborhood $n contains no CIV gramdb_g with non-zero population"
        }

        # Ensure that each CIV pgroup has non-zero population in at
        # least one neighborhood.
        $db eval {
            SELECT g, TOTAL(population) AS sum
            FROM gramdb_ng JOIN gramdb_g USING (g)
            WHERE gramdb_g.gtype = 'CIV'
            GROUP BY g
        } {
            require {$sum > 0} \
                "group $g has zero population in all neighborhoods"
        }
    }


    #-------------------------------------------------------------------
    # Table: gramdb_gc
    
    typemethod Val_gramdb_gc {db table} {
        # Insert rows for all missing combinations of g and c
        # with compatible types.  We'll get the defaults from the
        # schema.
        
        $db eval {
            SELECT g,c
            FROM gramdb_g JOIN gramdb_c USING (gtype)
        } {
            $db eval {
                INSERT OR IGNORE INTO gramdb_gc(g,c) VALUES($g,$c)
            }
        }
    }

    typemethod Val_gramdb_gc_record {db table rowid} {
        # Verify that the group and concern have the same type.

        $db eval {
            SELECT gramdb_gc.g    AS g,
                   gramdb_g.gtype AS gtype,
                   gramdb_gc.c    AS c,
                   gramdb_c.gtype AS ctype
            FROM gramdb_gc
            JOIN gramdb_g 
            JOIN gramdb_c 
            WHERE gramdb_gc.ROWID=$rowid
            AND   gramdb_g.g = gramdb_gc.g
            AND   gramdb_c.c = gramdb_gc.c
        } {
            require {$gtype eq $ctype} \
                "mismatch, $g is $gtype, $c is $ctype"
        }
    }

    #-------------------------------------------------------------------
    # Table: gramdb_fg

    typemethod Val_gramdb_fg {db table} {
        # Fill out table with default values: 1.0 when f==g, 0.0 otherwise.
        # Insert rows for all missing combinations of f and g.
        
        $db eval {
            SELECT F.g AS f,
                   G.g AS g
            FROM gramdb_g AS F JOIN gramdb_g AS G    
        } {
            $db eval {
                INSERT OR IGNORE INTO gramdb_fg(f,g) 
                VALUES($f,$g)
            }
        }
        
        $db eval {
            UPDATE gramdb_fg
            SET rel   = COALESCE(rel, 1.0),
                coop0 = COALESCE(rel, 100.0)
            WHERE f = g;
            
            UPDATE gramdb_fg
            SET rel   = COALESCE(rel, 0.0),
                coop0 = COALESCE(rel, 50.0)
            WHERE f != g;
        }
    }

    typemethod Val_gramdb_fg_record {db table rowid} {
        # Verify that rel is 1.0 and coop0 is 100 when f=g

        $db eval "SELECT * FROM $table WHERE rowid=\$rowid" row {
            if {$row(f) eq $row(g)} {
                if {$row(rel) ne ""} {
                    require {$row(rel) eq 1.0} \
                        "rel must be 1.0 when f = g"
                }

                if {$row(coop0) ne ""} {
                    require {$row(coop0) == 100.0} \
                        "coop0 must be 100.0 when f = g"
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Table: gramdb_ngc
    
    typemethod Val_gramdb_ngc {db table} {
        # Copy data from gramdb_gc for all missing combinations of n, g and c
        # with compatible types.
        $db eval {
            INSERT OR IGNORE INTO gramdb_ngc(n,g,c)
            SELECT n, g, c
            FROM gramdb_n JOIN gramdb_gc
        }

        $db eval {
            SELECT n, g, c, sat0, trend0, saliency
            FROM gramdb_n JOIN gramdb_gc
        } {
            $db eval {
                UPDATE gramdb_ngc
                SET sat0     = COALESCE(sat0,$sat0),
                    trend0   = COALESCE(trend0,$trend0),
                    saliency = COALESCE(saliency,$saliency)
                WHERE n=$n AND g=$g AND c=$c;
            }
        }
    }

    typemethod Val_gramdb_ngc_record {db table rowid} {
        # Verify that the group and concern have the same type.

        $db eval {
            SELECT gramdb_ngc.g    AS g,
                   gramdb_g.gtype  AS gtype,
                   gramdb_gc.c     AS c,
                   gramdb_c.gtype  AS ctype
            FROM gramdb_ngc
            JOIN gramdb_g USING (g)
            JOIN gramdb_c USING (c)
            WHERE gramdb_ngc.ROWID=$rowid
        } {
            require {$gtype eq $ctype} \
                "mismatch, $g is $gtype, $c is $ctype"
        }
    }

    #-------------------------------------------------------------------
    # Table: gramdb_nfg
    
    typemethod Val_gramdb_nfg {db table} {
        # Copy data from gramdb_fg for all missing combinations of n, f and g
        # with compatible types.

        $db eval {
            INSERT OR IGNORE INTO gramdb_nfg(n,f,g)
            SELECT n, f, g
            FROM gramdb_n JOIN gramdb_fg
        }

        $db eval {
            SELECT n, f, g, rel, coop0
            FROM gramdb_n JOIN gramdb_fg
        } {
            $db eval {
                UPDATE gramdb_nfg
                SET rel   = COALESCE(rel,$rel),
                    coop0 = COALESCE(coop0,$coop0)
                WHERE n=$n AND f=$f AND g=$g;
            }
        }
    }

    typemethod Val_gramdb_nfg_record {db table rowid} {
        # Verify that rel is 1.0 and coop0 is 100 when f=g

        $db eval "SELECT * FROM $table WHERE rowid=\$rowid" row {
            if {$row(f) eq $row(g)} {
                if {$row(rel) ne ""} {
                    require {$row(rel) eq 1.0} \
                        "rel must be 1.0 when f = g"
                }

                if {$row(coop0) ne ""} {
                    require {$row(coop0) == 100.0} \
                        "coop0 must be 100.0 when f = g"
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Public Type Methods: Loading data

    # loadfile dbfile ?db?
    #
    # dbfile     A gramdb(5) text file
    # db         An sqldocument(n) in which to load the data.  One is
    #            created if no database is specified.
    #
    # Parses the contents of the named file into the relevant tables
    # in the db, returning the name of the db.

    typemethod loadfile {dbfile {db ""}} {
        $type Initialize

        if {$db eq ""} {
            set db [$type CreateDatabase]
        } elseif {$type ni [$db sections]} {
            error "schema not defined"
        }

        $db unlock $tableNames
        $tt loadfile $db $dbfile $concernDefinitions
        $db lock $tableNames

        return $db
    }

    # load text ?db?
    #
    # text       A gramdb(5) text string
    # db         An sqldocument(n) in which to load the data.  One is
    #            created if no database is specified.
    #
    # Parses the contents of the text string into the relevant tables
    # in the db, returning the name of the db.

    typemethod load {text {db ""}} {
        $type Initialize

        if {$db eq ""} {
            set db [$type CreateDatabase]
        } elseif {$type ni [$db sections]} {
            error "schema not defined"
        }

        $db unlock $tableNames
        $tt load $db $text $concernDefinitions
        $db lock $tableNames

        return
    }
  
    #-------------------------------------------------------------------
    # Other Private Routines

    # CreateDatabase
    #
    # Creates an in-memory run-time database if one is not specified.

    typemethod CreateDatabase {} {
        set db [sqldocument %AUTO%]
        $db register $type
        $db open :memory:
        $db clear

        return $db
    }
}



