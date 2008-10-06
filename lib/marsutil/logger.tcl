#-----------------------------------------------------------------------
# TITLE:
#	logger.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       JNEM: marsutil(n) Tcl Utilities
#
#	Logger type.
#
#       The Logger type is used to define debugging log objects.  It's
#       expected that most applications will reference a single well-known
#       logger object, typically with a name like "log".
#
#       Each log entry has an associated verbosity level, in order 
#       of increasing verbosity:
#
#       silent:   -verbosity setting; means no entries are made
#       fatal:    Used when the program is about to halt.
#       warning:  Used when a potential problem is noticed.
#       normal:   Normal informational message.
#       debug1:   Debugging message, low verbosity.
#       debug2:   Debugging message, medium verbosity.
#       debug3:   Debugging message, high verbosity.
#       never:    Means message is *never* logged.
#
#       The log object will have its own verbosity level; entries logged
#       at that level and lower will be output, but entries at higher
#       verbosity levels will not.
#
#       Each log entry will include the name of the component that logged
#       it.  Verbosity can be set to maximum for specific components, 
#       enabling targetted debugging.
#
#       Logs are usually written to log files.  By default, though, if
#       no log file is open (or if the requested log file *can't* be
#       opened) entries are written to stdout.
#
#       Log entries are written in the form of a proper Tcl list
#       with these elements
#
#       t <systemTime> v <level> c <component> m <message> ?<key> <value>....?
#
#       <systemTime>   The wall-clock time as yyyy-mm-ddThh:mm:ss.
#                      This is sortable, and readable by [clock scan].
#       <level>        The verbosity level
#       <component>    The component logging the message
#       <message>      The text of the message, with "\n" substituted for
#                      all newlines and "\\" substituted for all
#                      pre-existing backslashes.  This guarantees that
#                      each message is on a single line.
#       <key>, <value> The application may specify a context command which
#                      adds key/value pairs to the end of the message.
#
#       Support for Zulu Time
#
#       In actual use, the Zulu Time of an entry is liable to be of
#       more interest than the wall-clock time.  Zulu Time will be
#       included automatically if the logger is given a -simclock.
#       The keyword is "zulu".
#
#       Merging Log Files
#
#       If the JNEM simulation is split into multiple executables,
#       and hence multiple log files, it would be desirable for log 
#       files to be strictly sortable for easier merging.  In Uplink, we 
#       did this by logging time to the ten-thousandth of a second.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export logger
}

#-----------------------------------------------------------------------
# Logger Type

snit::type ::marsutil::logger {
    #-------------------------------------------------------------------
    # Look-up tables

    # Verbosity levels
    typevariable levels {
        silent
        fatal
        warning
        normal
        debug1
        debug2
        debug3
        never
    }

    # Component verbosity modes
    typevariable modes {
        silent
        level
        all
    }

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Import needed commands.
        namespace import ::marsutil::* 
    }

    #-------------------------------------------------------------------
    # Options

    # -verbosity level
    #
    # level     The desired verbosity level (see "levels", above).
    #
    # Sets the verbosity level.  To disable logging entirely, set
    # -verbosity silent.
    option -verbosity -default normal \
        -configuremethod CfgVerbosity \
        -cgetmethod CgetVerbosity

    method CfgVerbosity {option value} {
        # FIRST, "never" isn't allows.
        set allowedLevels [lrange $levels 0 end-1]
        
        # NEXT, what is it?
        set ndx [lsearch -exact $allowedLevels $value]

        if {$ndx != -1} {
            set verbosity $ndx
            set options($option) $value
        } else {
            set choices [join $allowedLevels ", "]

            return -code error \
                "-level: got \"$value\", should be one of: $choices"
        }
    }

    method CgetVerbosity {option} {
        lindex $levels $verbosity
    }

    # -logdir name
    #
    # name        A log directory
    #
    # This is a creation time option; it specifies a log directory 
    # within which logger will create log files automatically.

    option -logdir -default "" -readonly 1

    # -logfile name
    #
    # name     The new log file name, or "".
    #
    # If the name is unchanged, does nothing.
    #
    # Otherwise, closes the existing log file (if any).  If name is "",
    # messages will go to stdout; otherwise, the logger tries to open
    # the named file.  On success, all subsequent messages will be 
    # written to the file; on failure, an error is thrown, and messages
    # will go to stdout.

    option -logfile -default "" \
        -configuremethod CfgLogfile

    method CfgLogfile {option value} {
        # FIRST, do nothing if the name is unchanged.
        if {$value eq $options($option)} {
            return
        }

        # NEXT, if -logdir is set then it's an error to set this.
        if {$options(-logdir) ne ""} {
            error "Cannot set -logfile when -logdir is set."
        }

        # NEXT, Open the new file; this will save the value.
        $self OpenFile $value
    }

    # -maxentries num
    #
    # num    A positive integer
    #
    # Specifies the number of entries after which the logger should
    # automatically open a new log file.

    option -maxentries -default 5000

    # -simclock cmd
    #
    # cmd    A simclock(n) object command
    #
    # Specifies a simclock which will provide simulated time.
    # If specified, "zulu <zulutime>" will be included in each log message.

    option -simclock -default ""

    # -contextcmd cmd
    #
    # cmd    A command which returns a context dictionary.
    #
    # Specifies a command which logger will call for each entry to
    # retrieve the current application context.  The context must be
    # returned in the form of a dictionary, which will be merged with
    # the entry's context (if any).  
    #
    # If there are key-conflicts between the application context and 
    # the entry's context, both will be included, with likely 
    # confusing results; so don't do that.
    
    option -contextcmd -default {}

    # -entrycmd cmd
    #
    # cmd    A command which receives each logged entry.
    #
    # Specifies a command which logger will call for each entry.
    # The command is passed a single argument, the entry dictionary,
    # including the application context.

    option -entrycmd -default {}

    # -overflowcmd cmd
    #
    # cmd    A command which is called when the log overflows.
    #
    # If -maxentries is exceeded, logger will open a new log file
    # and call this command.  The command is passed a single argument,
    # the new log file name.

    option -overflowcmd -default {}

    #-------------------------------------------------------------------
    # Instance variables

    variable channel  stdout   ;# Channel of open log file, or stdout.
    variable verbosity 3       ;# Default verbosity level number
    variable verbmode          ;# Array of component verbosity modes:
                                # 0 = silent  (log no entries)
                                # 1 = level   (log based on -verbosity)
                                # 2 = all     (log all entries)
    variable entryCount 0      ;# Number of entries logged.

    #-------------------------------------------------------------------
    # Constructor/Destructor

    constructor {args} {
        # FIRST, get the -logdir option, if any.
        set options(-logdir) [from args -logdir]

        # NEXT, if a -logdir was specified, make sure it
        # exists, and open the first log file.
        if {$options(-logdir) ne ""} {
            file mkdir $options(-logdir)
            $self newlog start
        }

        # NEXT, handle the rest of the options.
        $self configurelist $args
    }

    destructor {
        # Close the log file, if it's open
        $self CloseFile
    }

    #-------------------------------------------------------------------
    # Methods: New Log File

    # newlog ?label?
    #
    # label    A descriptive label
    #
    # Creates a new log file in the -logdir.  The log file will have
    # a name like this:
    #
    #    <logdir>/log<NNNNN>[_<label>].log
    #
    # Returns the -logfile name.

    method newlog {{label ""}} {
        # FIRST, make sure they've got a log directory.
        if {$options(-logdir) eq ""} {
            error "-logdir is unspecified"
        }

        # NEXT, get the next log file number.  We scan the log 
        # directory, and pick the next highest number.
        set num 1

        set matches [glob -nocomplain [file join $options(-logdir)/log*.log]]

        if {[llength $matches] > 0} {
            set last [lindex [lsort $matches] end]
            
            if {[regexp {log([0-9]+)} $last dummy filenum]} {
                scan $filenum %0d num
                
                incr num
            } else {
                $self warning log "Badly named log file: $last"
            } 
        }

        set logNum [format %05d $num]

        # NEXT, get the next logfile name.
        set name "log[format %05d $num]"
    
        if {$label ne ""} {
            append name "_$label"
        }

        append name ".log"

        set fullName [file join $options(-logdir) $name]

        $self OpenFile $fullName

        # NEXT, clear the entry count.
        set entryCount 0

        return $fullName
    }



    #-------------------------------------------------------------------
    # Methods: Logging Messages

    # <level> component message ?context?
    #
    # level     The verbosity level (this is actually the method name)
    # component The component logging the message.
    # message   The message, which is an arbitrary string.
    #
    # Writes a message to the log at the specified level.

    method fatal {component message} {
        $self LogEntry fatal 1 $component $message
    }

    method warning {component message} {
        $self LogEntry warning 2 $component $message
    }

    method normal {component message} {
        $self LogEntry normal 3 $component $message
    }

    method debug1 {component message} {
        $self LogEntry debug1 4 $component $message
    }

    method debug2 {component message} {
        $self LogEntry debug2 5 $component $message
    }

    method debug3 {component message} {
        $self LogEntry debug3 6 $component $message
    }

    method never {component message} {
        # Do nothing.  This method exists because a component can choose the
        # verbosity level of a message based on variable; and setting the
        # variable to "never" allows a particular message to be turned off 
        # completely.
    }

    # LogEntry level component message
    #
    # level     The verbosity level
    # levelnum  The numeric verbosity level
    # component The component which logged the message
    # message   The message text
    #
    # This is the method that actually logs the message (or not, based
    # on the verbosity level).

    method LogEntry {level levelnum component message} {
        # FIRST, Get the component verbosity mode.  If we don't have one, 
        # set it to 1, "level".
        if {[catch {set verbmode($component)} vmode]} {
            set vmode 1
            set verbmode($component) $vmode
        }

        # NEXT, do nothing unless the message is enabled.
        if {($levelnum <= $verbosity && $vmode != 0) || $vmode == 2} {
            # FIRST, increment the entry count; if it exceeds the 
            # -maxentries, open a new log file.
            incr entryCount
            
            if {$options(-maxentries) != 0 &&
                $entryCount > $options(-maxentries)} {
                set entryCount 0

                # We can't do this unless they've specified a -logdir.
                if {$options(-logdir) eq ""} {
                    return
                }

                set newfile [$self newlog]

                # NEXT, call the -overflowcmd, if any.
                if {$options(-overflowcmd) ne ""} {
                    set cmd $options(-overflowcmd)
                    
                    lappend cmd $newfile
                    uplevel \#0 $cmd
                }
            }

            # NEXT, format the entry as a list.
            set entry [list \
                           [Timestamp] \
                           $level \
                           $component \
                           [Flatten $message]]

            # NEXT, if there's a simclock, add the zulu time.
            if {$options(-simclock) ne ""} {
                lappend entry [$options(-simclock) asZulu]
            }

            # NEXT, if there's a context command, retrieve and append 
            # the application context.
            if {[llength $options(-contextcmd)] > 0} {
                if {[catch {uplevel \#0 $options(-contextcmd)} result]} {
                    return -code error "-contextcmd error: $result"
                }
                set entry [concat $entry $result]
            }
  
            # NEXT, output the log entry
            puts $channel $entry

            # NEXT, call the -entrycmd, if any.
            if {$options(-entrycmd) ne ""} {
                set cmd $options(-entrycmd)

                lappend cmd $entry
                uplevel \#0 $cmd
            }
        }

        # Return nothing.
        return
    }

    #-------------------------------------------------------------------
    # Methods: Component Verbosity Modes

    # verbmode component ?mode?
    #
    # component    An application component name
    # mode     silent | level | all
    #
    # Sets/gets the verbosity mode for a specific component.  If silent,
    # no log entries will be written for the component; if all, all entries
    # will be written for the component regardless of -verbosity; if level
    # (the default), -verbosity determines which entries get written.

    method verbmode {component {mode ""}} {
        # FIRST, set the mode if one is given.
        if {$mode ne ""} {
            set num [lsearch -exact $modes $mode]

            if {$num == -1} {
                set choices [join $modes ", "]

                return -code error \
                    "unknown verbmode \"$mode\", should be one of: $choices"
            }

            set verbmode($component) $num
        }

        # NEXT, get the mode number, and convert it to the string.
        if {[catch {set verbmode($component)} num]} {
            set num 1
            set verbmode($component) $num
        }

        return [lindex $modes $num]
    }

    # Returns the known list of components
    method components {} {
        array names verbmode
    }

    #-------------------------------------------------------------------
    # Private Methods

    # OpenFile name
    #
    # name      The new file name
    #
    # Opens the new log file, closing any previous log file; also,
    # sets -logfile.

    method OpenFile {name} {
        # FIRST, close the existing file, if any.
        $self CloseFile

        # NEXT, if the new name is "", we're done; CloseFile updated
        # options(-logfile).
        if {$name eq ""} {
            return
        }

        # NEXT, open the new file.
        if {[catch {open $name w} result]} {
            return -code error $result
        }

        # NEXT, save the channel.
        set options(-logfile) $name
        set channel $result

        # NEXT, make the channel be line-buffering, so that it's
        # written to disk after each line.
        fconfigure $channel -buffering line
    }

    # CloseFile
    #
    # Closes the current log file, if any.

    method CloseFile {} {
        if {$channel ne "stdout"} {
            close $channel
            set channel stdout
            set options(-logfile) ""
        }
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # Timestamp
    #
    # Returns the current time, formatted as YYYY-MM-DDTHH:MM:SS

    proc Timestamp {} {
        clock format [clock seconds] -format "%Y-%m-%dT%T"
    }

    # Flatten string
    #
    # message    A message to flatten
    #
    # Replaces all "\" characters in the input with "\\", and all
    # newline characters with "\n".
    
    proc Flatten {message} {
        string map [list \\ \\\\ \n \\n] $message
    }

    #-----------------------------------------------------------------------
    # Public Typemethods

    # levels
    #
    # Returns a list of the valid verbosity levels

    typemethod levels {} {
        return $levels
    }

    # modes
    #
    # Returns a list of the valid component verbosity modes

    typemethod modes {} {
        return $modes
    }

    # unflatten message
    #
    # message     The message portion of a log entry
    #
    # Replaces newlines in the message.
    
    typemethod unflatten {message} {
        string map [list \\\\ \\ \\n \n] $message
    }
}


