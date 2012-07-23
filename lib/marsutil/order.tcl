#-----------------------------------------------------------------------
# FILE: order.tcl
#
#   Mars Order Processor
#
# PACKAGE:
#   marsutil(n): Mars Utility API
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export order
}

#-----------------------------------------------------------------------
# Mars Order Processing Module
#
# order(n) defines the notion of an order, usually generated by the
# user, that changes the application's state and can potentially be
# undone.  An order has a name and a parameter dictionary.
#
# Insofar as possible, input validation and error-handling are
# automated, so that it's trivially easy to make all orders work the
# same way.
#
# ERROR HANDLING
#
# order(n) throws two kinds of errors when processing an order.
#
# If the -errorcode is REJECT, the order was rejected due to errors
# in the order parameters.  The error return is a dictionary of
# parameter names and error messages.
#
# Otherwise, the error is unexpected, i.e, the order handler, or
# code called by it, threw an error unrelated to validation of the
# order parms.  This usually indicates a bug in the code.
#
# How errors are handled depends on the interface.
#
# ORDER INTERFACES
#
# Orders can be received from different sources: the GUI, a CLI, the
# test suite, or from the application code.  How the order is handled
# can depend on the interface.  order(n) allows the client to define
# a number of "interfaces", each with its own specific behaviors.
# The interface is specified on "order send".
#
# See the "interface" command, below, for the interface options.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# order

# Create the metadata definition namespace immediately.

namespace eval ::marsutil::order::define:: {
    namespace import ::marsutil::dynaform
    namespace import ::marsutil::lshift
    namespace import ::marsutil::identifier
    namespace import ::marsutil::require
}


snit::type ::marsutil::order {
    # Make it an ensemble
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    # db: this points at the -rdb.
    typecomponent rdb

    # orderdialog: this points at orderdialog(n), to enable the 
    # "order enter" command.
    typecomponent orderdialog

    #-------------------------------------------------------------------
    # Order Definition metadata

    # Order handler name by order name
    
    typevariable handler -array {}

    # orders: array of order definition data.
    #
    # names               List of order names
    # metadata-$name      Metadata script for the named order.
    # title-$name         The order's title
    # opts-$name          Option definition dictionary
    # parms-$name         List of the names of the order's parameters
    # tags-$name-$parm    Tags associated with the named order parameter.
   
    typevariable orders -array {
        names {}
    }

    #-------------------------------------------------------------------
    # Other Type Variables


    # info -- array of scalars
    #
    # initialized  - 0 or 1.  Indicates whether "order init" has been
    #                called or not.
    # logcmd       - logger(n), or ""
    # ordercmd     - CIF handler, or ""
    # subject      - notifier(n) subject; defaults to $type
    # usedTable    - Name of RDB table that lists used entity names.
    # state        - Application's current order state.
    # nullMode     - 0 or 1.  While in null mode, the orders don't 
    #                actually get executed; "order send" returns after 
    #                saving the parms.

    typevariable info -array {
        initialized 0
    }

    # infoDefaults -- Dictionary of default values for the info
    # array.

    typevariable infoDefaults {
        initialized  0
        logcmd       ""
        ordercmd     ""
        subject      ::marsutil::order
        usedTable    ""
        state        ""
        nullMode     0
    }

    # intf -- Array of interface option dictionaries by interface name
    #
    # -checkstate  - Flag; if true, order -sendstates will be checked.
    # -errorcmd    - Command to call on unexpected order errors.
    # -rejectcmd   - Command to call to format error result for rejected
    #                orders.  Defaults to none.
    # -trace       - Flag; trace orders with -ordercmd or not
    # -transaction - Flag; if yes, wrap order handler in rdb transaction
    
    typevariable intf -array { }

    # intfDefaults -- Dictionary of default interface options
    typevariable intfDefaults {
        -checkstate  no
        -errorcmd    {}
        -rejectcmd   {}
        -trace       no
        -transaction yes
    }

    #-------------------------------------------------------------------
    # Transient Variables

    # The following variables are used while defining an order:

    # deftrans: Array of transient order definition data
    #
    # order     The name of the order currently being defined.
    
    typevariable deftrans -array {}
    
    # The following variables are used while processing an order, and
    # are cleared before every new order.

    # trans: Array of transient data
    #
    # sender    - The sending interface
    # idict     - The sending interface's option dictionary
    # errors    - Dictionary of parameter names and error messages
    # level     - Error level: NONE or REJECT
    # undo      - Undo script for this order
    # checking  - 1 if in "order check" and 0 otherwise.

    typevariable trans -array {}

    # Parms: array of order parameter values, by parameter name.
    # This array is aliased into every order handler.
    typevariable parms -array {}


    #-------------------------------------------------------------------
    # Delegated Typemethods

    delegate typemethod enter to orderdialog
    delegate typemethod puck  to orderdialog

    #-------------------------------------------------------------------
    # Initialization

    # init ?options...?
    #
    # Initializes the module, executing the definition scripts for
    # each order.

    typemethod init {args} {
        # FIRST, we can only initialize once.
        if {$info(initialized)} {
            return
        }

        # NEXT, get the default info() values
        array set info $infoDefaults

        # NEXT, get the option values
        if {[llength $args] > 0} {
            $type configure {*}$args
        }

        require {$rdb ne ""} "-rdb is \"\""

        # NEXT, evaluate all of the existing definition scripts.
        foreach name $orders(names) {
            DefineOrder $name
        }

        # NEXT, save components
        set orderdialog ::marsgui::orderdialog

        # NEXT, create default interfaces
        set intf(app) $intfDefaults
        set intf(gui) $intfDefaults

        # NEXT, Order processing is up.
        set info(initialized) 1


        $type Log detail "init complete"
    }

    # cget ?option?
    #
    # option  - An option name
    #
    # Passed a single option name, returns the module's option value.
    # Otherwise, returns a dictionary of all of the module option values.

    typemethod cget {{option ""}} {
        # FIRST, query an option.
        if {$option eq ""} {
            return [dict create \
                        -logcmd       $info(logcmd)       \
                        -ordercmd     $info(ordercmd)     \
                        -rdb          $rdb                \
                        -subject      $info(subject)      \
                        -usedtable    $info(usedTable)]
        }

        switch -exact -- $option {
            -logcmd       { return $info(logcmd)                }
            -ordercmd     { return $info(ordercmd)              }
            -rdb          { return $rdb                         }
            -subject      { return $info(subject)               }
            -usedtable    { return $info(usedTable)             }
            default       { error "Unknown option: \"$option\"" }
         }
    }
    

    # configure ?option value...?
    #
    # args  - Module options and values.
    #
    # Sets multiple module options and values.

    typemethod configure {args} {
        # FIRST, set the option values.
        while {[llength $args] > 0} {
            set option [lshift args]

            if {[llength $args] == 0} {
                error "Option $option: no value given"
            }

            # Some options can only be set by order init.
            if {$info(initialized) && $option in {
                -rdb
            }} {
                error "Option $option is readonly after initialization"
            }

            switch -exact -- $option {
                -logcmd       { set info(logcmd)       [lshift args] }
                -ordercmd     { set info(ordercmd)     [lshift args] }
                -rdb          { set rdb                [lshift args] }
                -subject      { set info(subject)      [lshift args] }
                -usedtable    { set info(usedTable)    [lshift args] }
                default       { error "Unknown option: \"$option\""  }
            }
        }

        return
    }

    # initialized
    #
    # Returns 1 if the module has been initialized, and 0 otherwise.

    typemethod initialized {} {
        return $info(initialized)
    }

    # reset
    #
    # Resets all order metadata, and uninitializes the module.
    # After reset, any order definitions will need to be redone.
    #
    # This command exists for use in order.test.
    #
    # TBD: Possibly, this should delete the related dynaforms as well.

    typemethod reset {} {
        array unset handler
        array unset orders
        array unset intf
        array unset info
        array unset deftrans
        array unset trans
        array unset parms

        set rdb ""
        array set info $infoDefaults
        set orders(names) {}
    }

    #-------------------------------------------------------------------
    # Interface configuration

    # interface names
    #
    # Returns the defined interface names
    
    typemethod {interface names} {} {
        return [array names intf]
    }

    # interface add name ?options...?
    #
    # name    - The new interface name
    # options - Interface options and values
    # 
    # Creates a new interface, and sets the options.


    typemethod {interface add} {name args} {
        require {![info exists intf($name)]} \
            "Interface is already defined: \"$name\""

        # FIRST, create the interface with default options
        set intf($name) $intfDefaults

        # NEXT, configure the remaining
        $type interface configure $name {*}$args

        return
    }

    # interface configure name ?options...?
    #
    # name    - An existing interface name
    # options - Interface options and values.
    #
    # Configures interface options.

    typemethod {interface configure} {name args} {
        require {[info exists intf($name)]} \
            "Invalid interface name: \"$name\""

        while {[llength $args] > 0} {
            set option [lshift args]

            switch -exact -- $option {
                -checkstate  -
                -trace       -
                -transaction { 
                    dict set intf($name) $option \
                        [snit::boolean validate [lshift args]]
                }

                -errorcmd  -
                -rejectcmd {
                    dict set intf($name) $option [lshift args]
                }

                default { 
                    error "Unknown option: \"$option\"" 
                }
            }
        }

        return
    }

    # interface cget name ?option?
    #
    # name     - Interface name
    # option   - Interface option
    #
    # Returns the value of the option, or a dictionary of all options.

    typemethod {interface cget} {name {option ""}} {
        require {[info exists intf($name)]} \
            "Invalid interface name: \"$name\""

        if {$option eq ""} {
            return $intf($name)
        } else {
            return [dict get $intf($name) $option]
        }
    }


    #-------------------------------------------------------------------
    # Order Definition

    # define name metadata body
    #
    # name     - The name of the order
    # metadata - The order's metadata script 
    # body     - The body of the order
    #
    # Defines a proc within the ::marsutil::orders namespace 
    # with access to the ::marsutil::order helper routines.  This 
    # allows orders to be defined outside the ::marsutil::order 
    # namespace.

    typemethod define {name metadata body} {
        # FIRST, save the metadata
        order DefMeta $name $metadata

        # NEXT, define the namespace and set up the namespace path
        namespace eval ::marsutil::orders:: \
            [list namespace path ::marsutil::order::]

        # NEXT, save the handler name
        set handler($name) ::marsutil::orders::$name

        # NEXT, define the handler
        proc $handler($name) {} [tsubst {
        |<--
            namespace upvar $type ${type}::parms parms

            $body
        }]
    }

    # DefMeta name script
    #
    # name     An order name
    # script   A definition script
    #
    # Specifies the metadata definition script for the existing orders.
    # The script is saved, to be executed at "order init"; if the
    # module is already initialized, then the script is executed
    # immediately.

    typemethod DefMeta {name script} {
        # FIRST, save the script
        if {$name ni $orders(names)} {
            lappend orders(names) $name
        }

        set orders(metadata-$name) $script

        # NEXT, execute it if the module is already initialized.
        if {[$type initialized]} {
            DefineOrder $name
        }
    }

    # DefineOrder name
    #
    # name      Order name
    #
    # Executes the definition script for this order

    proc DefineOrder {name} {
        ::marsutil::order Log detail "define $name"

        # FIRST, initialize the data values
        set orders(title-$name) ""
        set orders(opts-$name) {
            -dynaform       {}
            -narrativecmd   {}
            -sendstates     *
            -monitor        1
        }
        set orders(parms-$name) ""
        array unset orders tags-$name-*

        # NEXT, set the current order name
        set deftrans(order) $name

        # NEXT, execute the metadata
        if {[catch {
            namespace eval ::marsutil::order::define $orders(metadata-$name)
        } result]} {
            error "Metadata error for order $name:\n$result"
        }

        # NEXT, check constraints
        if {$orders(title-$name) eq ""} {
            set orders(title-$name) $name
        }
    }

    #-------------------------------------------------------------------
    # Definition Script Procs
    #
    # These procs are defined in the ::marsutil::order::define:: 
    # namespace, which is where definition scripts are evaluated.

    # title titleText
    #
    # titleText    Human-readable order title
    #
    # Sets the order's title text

    proc define::title {titleText} {
        set orders(title-$deftrans(order)) $titleText
    }
    
    # options option...
    #
    # -narrativecmd cmd
    #     Specifies a command that should return a human-readable
    #     description of the order's effect.  The command will be
    #     called with two additional arguments, the order name and
    #     the parm dict.  If no -narrativecmd is given, the order's
    #     narrative is simply its title.
    #
    # -sendstates states     
    #     States in which the order can be sent.  If clear, the order 
    #     cannot be sent.
    #
    # -monitor flag
    #     If yes (the default) perform row monitoring when the order
    #     is sent.  If not, don't.
    #
    # Sets the order's options.

    proc define::options {args} {
        # FIRST, get the option dictionary
        set odict $orders(opts-$deftrans(order))

        # FIRST, validate and save the options
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -narrativecmd   -
                -sendstates     { 
                    dict set odict $opt [lshift args] 
                }

                -monitor { 
                    dict set odict $opt \
                        [snit::boolean validate [lshift args]]
                }

                default {
                    error "Unknown option: $opt"
                }
            }
        }

        # NEXT, save the accumulated options
        set orders(opts-$deftrans(order)) $odict
    }


    # form spec
    #
    # spec  - dynaform(n) specification script
    #
    # Sets the order's form specification.

    proc define::form {spec} {
        # FIRST, make things easier.
        set order $deftrans(order)

        # NEXT, remember that we have a dynaform; it will be named after
        # the order.
        dict set orders(opts-$order) -dynaform $order

        # NEXT, create the dynaform.
        dynaform define $order $spec

        # NEXT, Save the field data.
        set orders(parms-$order) [dynaform fields $order]

        # TBD: Somewhere, verify that the field names are valid.

        # NEXT, initialize the tags list for each parameter.
        # Tags are defined using the [parmtags] metadata command.

        foreach name $orders(parms-$order) {
            set orders(tags-$order-$name) [list]
        }
    }

    # parmtags parm tag...
    #
    # field  - A previously defined parm.
    # tag    - A tag to tag the field with.
    #
    # Sets the -tags option for a previously defined parameter.

    proc define::parmtags {parm args} {
        # FIRST, make things easier.
        set order $deftrans(order)

        # NEXT, it's an error if the parameter doesn't exist.
        require {$parm in $orders(parms-$order)} \
            "Unknown parameter: \"$parm\""

        # NEXT, save the tags.
        set orders(tags-$order-$parm) $args
    }

    #-------------------------------------------------------------------
    # Order Queries
    #
    # These commands are used to query the existing orders and their
    # metadata.

    # names
    #
    # Returns the names of the currently defined orders
    
    typemethod names {} {
        return $orders(names)
    }

    # validate name
    #
    # name    An order name
    #
    # Validates the name as an order name

    typemethod validate {name} {
        if {![order exists $name]} {
            return -code error -errorcode INVALID \
                "order does not exist: \"$name\""
        }

        return $name
    }


    # exists name
    #
    # name     An order name
    #
    # Returns 1 if there's an order with this name, and 0 otherwise

    typemethod exists {name} {
        return [info exists handler($name)]
    }

    # title name
    #
    # name     The name of an order
    #
    # Returns the order's title

    typemethod title {name} {
        require {[order exists $name]} "Order is undefined: \"$name\""
        return $orders(title-$name)
    }
    
    # options name ?opt?
    # 
    # name     The name of an order
    # opt      The name of an order option
    #
    # Returns the order's option dictionary, or the value of the
    # specified option.

    typemethod options {name {opt ""}} {
        require {[order exists $name]} "Order is undefined: \"$name\""

        if {$opt eq ""} {
            return $orders(opts-$name)
        } else {
            return [dict get $orders(opts-$name) $opt]
        }
    }

    
    # narrative name pdict
    #
    # name     The name of an order
    # pdict    The parameter dictionary for the order
    #
    # Returns the order's narrative.

    typemethod narrative {name pdict} {
        set cmd [order options $name -narrativecmd]

        if {$cmd eq ""} {
            return [order title $name]
        } else {
            return [{*}$cmd $name $pdict]
        }
    }
    
    # parms name
    #
    # name     The name of an order
    #
    # Returns a list of the parameter names

    typemethod parms {name} {
        require {[order exists $name]} "Order is undefined: \"$name\""

        return $orders(parms-$name)
    }


    # tags order parm
    #
    # order     The name of an order
    # parm      The name of a parameter
    #
    # Returns a list of the tags associated with this parameter.

    typemethod tags {order parm {opt ""}} {
        require {[order exists $order]} "Order is undefined: \"$order\""
        require {[info exists orders(tags-$order-$parm)]} \
            "Parm is undefined: \"$parm\""

        return $orders(tags-$order-$parm)
    }

    #-------------------------------------------------------------------
    # State Management

    # state ?state?
    #
    # state    A new order state
    #
    # Sets/queries the current order state, which determines which
    # orders are valid/invalid.  Each order is associated with a list
    # of states in which is valid, or is valid in all states.  This
    # module doesn't care what the states are, particularly; it has no
    # logic associated with specific states.  Thus, the application
    # can pick whatever states make sense.

    typemethod state {{state ""}} {
        if {$state ne ""} {
            set info(state) $state
            notifier send $info(subject) <State> $state
        }

        return $info(state)
    }

    # cansend name
    #
    # name    An order name
    #
    # Returns 1 if the order can be sent in the current state,
    # and 0 otherwise.

    typemethod cansend {name} {
        set states [$type options $name -sendstates]
        expr {$states eq "*" || $info(state) in $states}
    }

    # available name
    #
    # name    An order name
    #
    # Returns 1 if the order can be sent in the current state.

    typemethod available {name} {
        return [order cansend $name]
    }


    #-------------------------------------------------------------------
    # Sending Orders

    # send interface name parmdict
    # send interface name parm value ?parm value...?
    #
    # interface       gui|cli|raw|test|app
    # name            The order's name
    # parmdict        The order's parameter dictionary
    # parm,value...   The parameter dictionary passed as separate args.
    #
    # Processes the order, handling errors in the appropriate way for the
    # interface.

    typemethod send {interface name args} {
        # FIRST, get the parmdict.
        if {[llength $args] > 1} {
            set parmdict $args
        } else {
            set parmdict [lindex $args 0]
        }

        # NEXT, log the order
        $type Log normal [list $name from '$interface': $parmdict]

        # NEXT, get the interface dict.
        if {![info exists intf($interface)]} {
            error "Interface is undefined: \"$interface\""
        }

        # NEXT, do we have an order handler?
        require {[info exists handler($name)]} "Order is undefined: \"$name\""

        # NEXT, get some data about the interface
        set trans(sender) $interface
        set trans(idict)  $intf($interface)

        # NEXT, we're not just checking.
        set trans(checking) 0

        # NEXT, save the order parameters in the parms array, saving
        # the order name.
        set validParms [order parms $name]

        array unset parms

        dict for {parm value} $parmdict {
            if {$parm ni $validParms} {
                reject * "Unknown parameter: \"$parm\""
                returnOnError
            }

            set parms($parm) $value
        }

        set parms(_order) $name

        # NEXT, in null mode we're done.
        if {$info(nullMode)} {
            return
        }

        # NEXT, set up the error messages and call the order handler,
        # rolling back the database automatically on error.
        set trans(errors) [dict create]
        set trans(level)  NONE
        set trans(undo)   {}

        if {[catch {
            # FIRST, check the state.  Note that if the interface is
            # "app", this doesn't matter; the app is in control
            
            if {[dict get $trans(idict) -checkstate]} {
                if {![$type cansend $name]} {
                    set states [$type options $name -sendstates]
                    
                    reject * "
                        Order state is $info(state), but order is valid
                        only in these states: [join $states {, }]
                    "

                    returnOnError
                }
            }
            
            # NEXT, call the handler, monitoring database updates
            # and notifying the application on change.
            if {[dict get $trans(idict) -transaction]} {
                set montype "transaction"
            } else {
                set montype "script"
            }

            if {[order options $name -monitor]} {
                $rdb monitor $montype {
                    $handler($name)
                }
            } else {
                # No monitoring
                if {$montype eq "transaction"} {
                    $rdb transaction {
                        $handler($name)
                    }
                } else {
                    $handler($name)
                }
            }
        } result opts]} {
            # FIRST, get the error info
            set einfo [dict get $opts -errorinfo]
            set ecode [dict get $opts -errorcode]

            # NEXT, handle the result 
            if {$ecode eq "REJECT"} {
                set rejectcmd [dict get $trans(idict) -rejectcmd]

                if {$rejectcmd ne ""} {
                    set result [{*}$rejectcmd $result]
                }

                $type Log warning $result                    
                return {*}$opts $result
            }

            if {$ecode eq "CANCEL"} {
                $type Log warning $result                    
                return "Order was cancelled."
            }

            set errorcmd [dict get $trans(idict) -errorcmd]
            
            if {$errorcmd ne ""} {
                {*}$errorcmd $name $result $einfo
            } else {
                error \
                    "Unexpected error in $name:\n$result" $einfo
            }
        }

        # NEXT, Trace the order.
        if {[dict get $trans(idict) -trace]} {
            callwith $info(ordercmd) \
                $interface $name $parmdict $trans(undo)
        }

        # NEXT, notify the app that the order has been accepted.
        notifier send $info(subject) <Accepted> $name $parmdict

        # NEXT, return the result, if any.
        return $result
    }


    # check name parmdict
    # check name parm value ?parm value...?
    #
    # name            The order's name
    # parmdict        The order's parameter dictionary
    # parm,value...   The parameter dictionary passed as separate args.
    #
    # Checks the order, throwing a REJECT error if invalid.

    typemethod check {name args} {
        # FIRST, get the parmdict.
        if {[llength $args] > 1} {
            set parmdict $args
        } else {
            set parmdict [lindex $args 0]
        }

        # NEXT, do we have an order handler?
        require {[info exists handler($name)]} "Undefined order: $name"

        # NEXT, save the interface.
        set trans(sender) app

        # NEXT, we're checking.
        set trans(checking) 1

        # NEXT, save the order parameters in the parms array, saving
        # the order name.
        set validParms [order parms $name]

        array unset parms

        dict for {parm value} $parmdict {
            require {$parm in $validParms} "Unknown parameter: \"$parm\""

            set parms($parm) $value
        }

        set parms(_order) $name

        # NEXT, set up the error messages and call the order handler,
        # rolling back the database automatically on error.
        set trans(errors) [dict create]
        set trans(level)  NONE
        set trans(undo)   {}

        # NEXT, call the handler
        set code [catch { $handler($name) } result opts]

        if {$code == 0} {
            return -code error \
                "order $name responds improperly on validity check"
        } else {
            set ecode [dict get $opts -errorcode]

            if {$ecode ne "CHECKED"} {
                return {*}$opts $result
            }
        }

        return
    }


    # nullmode flag
    #
    # flag      A boolean flag
    #
    # Turns nullmode on and off.  This is used for testing commands
    # that send orders.

    typemethod nullmode {flag} {
        set info(nullMode) $flag
    }


    # lastparms
    #
    # Returns a dictionary of the most recent order parms, with one
    # additional parm, _order.

    typemethod lastparms {} {
        array get parms
    }

    # fill order parmdict
    #
    # order      - An order name
    # parmdict   - A parameter dictionary for the order
    #
    # Returns a parmdict with default values inserted for missing parms.
    # A parameter is presumed to be missing if it has no key or if its
    # value is "".  This is for use in command-line entry of orders.
    
    typemethod fill {order parmdict} {
        require {[order exists $order]} "Undefined order: $order"

        # FIRST, if it's a dynaform-based order, delegate this; 
        # form-structure matters.
        set df [dict get $orders(opts-$order) -dynaform]

        if {$df ne ""} {
            return [dynaform fill $df $parmdict]
        }

        # NEXT, there are no parms to fill.
        return $parmdict
    }

    # prune order parmdict
    #
    # order      - An order name
    # parmdict   - A parameter dictionary for the order
    #
    # Returns a parmdict pruned of all parameters with default values.
    # Unknown parameters are also pruned.  This is for use in producing order
    # scripts minus extraneous data.
    
    typemethod prune {order parmdict} {
        require {[order exists $order]} "Undefined order: $order"

        # FIRST, if it's a dynaform-based order, delegate this; 
        # form-structure matters.
        set df [dict get $orders(opts-$order) -dynaform]

        if {$df ne ""} {
            return [dynaform prune $df $parmdict]
        }

        # NEXT, there are no parms to prune.
        return [dict create]
    }

    #-------------------------------------------------------------------
    # Procs for use in order handlers

    # sender
    #
    # Returns the name of the sending interface

    proc sender {} {
        return $trans(sender)
    }

    # prepare parm options...
    #
    # Prepares the parameter for processing, as determined by the
    # options.

    proc prepare {parm args} {
        # FIRST, make sure that the parameter exists.
        if {![info exists parms($parm)]} {
            set parms($parm) ""
        }

        # NEXT, trim the data.
        set parms($parm) [string trim $parms($parm)]


        # NEXT, process the options, so long as there's no explicit
        # error.

        while {![dict exists $trans(errors) $parm] && [llength $args] > 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -toupper {
                    set parms($parm) [string toupper $parms($parm)]
                }
                -tolower {
                    set parms($parm) [string tolower $parms($parm)]
                }
                -normalize {
                    set parms($parm) [normalize $parms($parm)]
                }
                -required { 
                    if {$parms($parm) eq ""} {
                        reject $parm "required value"
                    }
                }
                -oldvalue {
                    set oldvalue [lshift args]

                    if {$parms($parm) eq $oldvalue} {
                        set parms($parm) ""
                    }
                }
                -oldnum {
                    set oldvalue [lshift args]

                    if {$parms($parm) == $oldvalue} {
                        set parms($parm) ""
                    }
                }
                -unused {
                    require {$info(usedTable) ne ""} "No -usedtable specified."

                    if {$parms($parm) eq ""} {
                        continue
                    }

                    set name $parms($parm)
                    if {[$rdb exists "
                        SELECT id FROM $info(usedTable) 
                        WHERE id=\$name
                    "]} {
                        reject $parm "An entity with this ID already exists"
                    }
                }
                -type {
                    set parmtype [lshift args]

                    validate $parm { 
                        set parms($parm) [{*}$parmtype validate $parms($parm)]
                    }
                }
                -listof {
                    set parmtype [lshift args]

                    validate $parm {
                        set newvalue [list]

                        foreach val $parms($parm) {
                            lappend newvalue [{*}$parmtype validate $val]
                        }

                        set parms($parm) $newvalue
                    }
                }
                -selector {
                    set frm [order options $parms(_order) -dynaform]

                    if {$frm eq ""} {
                        error "Not a dynaform selector: \"$parm\""
                    }

                    set cases [dynaform cases $frm $parm]

                    validate $parm {
                        if {$parms($parm) ni $cases} {
                            reject $parm \
                                "invalid value \"$parms($parm)\", should be one of: [join $cases {, }]"
                        }
                    }
                }
                -xform {
                    set cmd [lshift args]

                    validate $parm {
                        set parms($parm) [{*}$cmd $parms($parm)]
                    }
                }
                default { 
                    error "unknown option: \"$opt\"" 
                }
            }
        }

    }

    # reject parm msg
    #
    # parm   A parameter name, or "*"
    # msg    An error message
    #
    # There's an out-and-out error in the order.  Add the message to
    # the error dictionary, and set the trans(level) to REJECT.

    proc reject {parm msg} {
        dict set trans(errors) $parm [normalize $msg]
        set trans(level) REJECT
    }

    # valid parm
    #
    # parm    Parameter name
    #
    # Returns 1 if parm's value is not known to be invalid, and
    # 0 otherwise.  A parm's value is invalid if it's the 
    # empty string (a missing value) or if it's been explicitly
    # flagged as invalid.

    proc valid {parm} {
        if {$parms($parm) eq "" || [dict exists $trans(errors) $parm]} {
            return 0
        }

        return 1
    }

    # validate parm script
    #
    # parm    A parameter to validate
    # script  A script to validate it.
    #
    # Executes the script in the caller's context.  If the script
    # throws an error, and the error code is INVALID, the value
    # is rejected.  Any other error is rethrown as an unexpected
    # error.
    #
    # If the parameter is already known to be invalid, the code is skipped.
    # Further, if the parameter is the empty string, the code is skipped,
    # as presumably it's an optional parameter.

    proc validate {parm script} {
        if {![valid $parm]} {
            return
        }

        if {[catch {
            uplevel 1 $script
        } result opts]} {
            if {[lindex [dict get $opts -errorcode] 0] eq "INVALID"} {
                reject $parm $result
            } else {
                return {*}$opts $result
            }
        }
    }

    # returnOnError ?-final?
    #
    # Handles accumulated errors.

    proc returnOnError {{flag ""}} {
        # FIRST, Were there any errors?
        if {[dict size $trans(errors)] == 0} {
            # If this is the -final check, and we're just checking,
            # escape out of the order.
            if {$flag eq "-final" && $trans(checking)} {
                return -code error -errorcode CHECKED
            } else {
                # Just return normally.
                return
            }
        }

        # FINALLY, throw the accumulated errors at the specified
        # error level; this will terminate order processing.
        
        return -code error -errorcode $trans(level) $trans(errors)
    }

    # cancel
    #
    # Use this in the rare case where the user can interactively 
    # cancel an order that's in progress.

    proc cancel {} {
        return -code error -errorcode CANCEL \
            "The order was cancelled by the user."
    }

    # setundo script
    #
    # script    An undo script
    #
    # Sets the undo script for the current order.

    proc setundo {script} {
        set trans(undo) $script
        return
    }

    #-------------------------------------------------------------------
    # Utility Typemethods

    # Log level text
    #
    # level - The log level
    # text  - The text of the log message
    #
    # Writes the log text to the -logcmd, if any.
    
    typemethod Log {level text} {
        callwith $info(logcmd) $level order $text
    }
}


