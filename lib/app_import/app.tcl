#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_import(1) Application
#
#    This module defines app, the application ensemble.
#
#        package require app_import
#        app init $argv
#
#    This program is a CM tool that imports versions of Mars into
#    a client project's work area.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor

    # TBD

    #-------------------------------------------------------------------
    # Type Variables

    # TBD

    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv         Command line arguments
    #
    # This the main program.

    typemethod init {argv} {
        # FIRST, get the argument, or show usage
        if {[llength $argv] != 1} {
            ShowUsage
            exit 1
        }

        set marsVersion [lindex $argv 0]

        # NEXT, print out the current working directory:

        puts "In Directory: [file normalize .]"
        puts "Importing:    Mars $marsVersion"

        # NEXT, Mars can only be imported into a Subversion workarea.
        if {[catch {app svninfo . info}]} {
            puts [tsubst {
                |<--

                Mars cannot be imported here; this directory is not part
                of a Subversion work area.
            }]

            exit 1
        }

        # NEXT, Mars mustn't be imported into itself.
        if {[string match "*/mars/*" $info(URL)]} {
            puts [tsubst {
                |<--

                Mars cannot be imported here; this directory is already
                part of a Mars work area.  Importing Mars here would cause
                Mars to check itself out recursively, which would be
                a *bad* thing.
            }]

            exit 1
        }

        # NEXT, Determine the URL of the desired version of Mars, 
        # assuming that it is in the same repository.

        set rep $info(Repository_Root)

        if {$marsVersion eq "trunk"} {
            set marsUrl $rep/mars/trunk
        } else {
            set marsUrl $rep/mars/tags/mars_$marsVersion
        }

        # NEXT, add ".jpl.nasa.gov", if need be.
        if {![string match "*jpl.nasa.gov*" $marsUrl]} {
            set marsUrl [string map {/oak/ /oak.jpl.nasa.gov/} $marsUrl]
        }

        puts "Mars URL:     $marsUrl"

        # NEXT, Ensure that the desired version of Mars actually
        # exists!

        if {[catch {exec svn ls $marsUrl} result]} {
            puts [tsubst {
                |<--

                Mars cannot be imported; no such version of Mars is
                available in this repository.
            }]

            exit 1
        }

        # NEXT, We're ready to go.  Set the svn:externals so that this 
        # version will be checked out automatically in the future.

        app svn propset svn:externals "mars $marsUrl\n" .

        # NEXT, If there is already a version of Mars checked out,
        # switch it to this version; otherwise, check out a new one.
        
        set marsDir [file join . mars]
        
        if {[file exists $marsDir]} {
            app svn switch $marsUrl $marsDir
        } else {
            app svn checkout $marsUrl $marsDir
        }
    }


    # ShowUsage
    #
    # Display command line syntax.

    proc ShowUsage {} {
        puts {Usage: mars import trunk|<version>}
    }

    #-------------------------------------------------------------------
    # Subversion Utilities

    # svninfo path infoVar
    #
    # path     A file or directory path
    # infoVar  Name of an array to receive the info
    #
    # Retrieves "svn info" for the path and returns it in the array.
    
    typemethod svninfo {path infoVar} {
        upvar 1 $infoVar info

        set result [exec svn info $path]

        foreach line [split $result "\n"] {
            set colonIndex [string first ":" $line]
            
            set key [string map {" " _} [string range $line 0 $colonIndex-1]]
            set value [string range $line $colonIndex+2 end]
            
            if {$key ne ""} {
                set info($key) $value
            }
        }
    }

    # svn cmd args...
    #
    # Logs and executes the Subversion cmd, and returns the result
    
    typemethod svn {cmd args} {
        puts "svn $cmd $args"
        puts [exec svn $cmd {*}$args]
    }
}




