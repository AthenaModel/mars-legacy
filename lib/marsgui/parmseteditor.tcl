#-----------------------------------------------------------------------
# TITLE:
#    parmseteditor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    gui(n): parmset(n) parameter set editor
#
#    The parmseteditor(n) widget is used to browse or edit parmset(n)
#    objects.  It's based on the Tktreectrl widget.
#
#    To Be Done:
#
#    * Implement the basic "string" editor, using an entry widget.
#      * Can a widget be part of an item?  If so, when selecting an
#        item we could just change the state and initialize the item.
#      * Consider defining a family of "editor" widgets with the
#        same operations, for use with parmseteditor.
#
#-----------------------------------------------------------------------

namespace eval ::gui:: {
    namespace export parmseteditor
}

#-----------------------------------------------------------------------
# parmseteditor

snit::widget ::gui::parmseteditor {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Add defaults to the option database
        option add *Parmseteditor.width       400
        option add *Parmseteditor.height      200
        option add *Parmseteditor.borderWidth 0
        option add *Parmseteditor.background  white

        # Allow the widget to use marsutil(n)
        namespace import ::marsutil::* 
    }

    #-------------------------------------------------------------------
    # Instance Variables

    # Array of information about the items in the editor.
    #
    # id-$name          The item's treectrl item ID, given the 
    #                   parameter/prefix name.
    #
    # name-$id          The item's name given its item ID.
    #
    # type-$id          The item's type (parm|prefix) given its ID
    #
    # differs-$id       The item's "differs" value.  For parms, this
    #                   is 1 if the parm value differs from the default.
    #                   For prefixes, this is the number of parms with
    #                   that prefix for which differs is 1.

    variable info

    # ID of the item currently being edited, or 0 if no item is being 
    # edited.
    variable editedItem 0

    #-------------------------------------------------------------------
    # Components

    component ps            ;# The parmset(n) being edited.
    component tree          ;# The tktreectrl widget
    component stringEditor  ;# entry widget, for editing strings.
    component stringEditorFrame

    #-------------------------------------------------------------------
    # Options

    delegate option -width  to tree
    delegate option -height to tree
    delegate option -background to tree
    delegate option -borderwidth to hull
    delegate option -relief to hull

    # -state
    #
    # Determines whether the editor is editable or readonly.

    option -state \
        -type {snit::enum -values {normal readonly}} \
        -default normal

    # -msgcmd cmd
    # 
    # Specifies a log command for reporting messages.    
    option -msgcmd -default ""

    # -parmset
    #
    # Sets the parmset to be edited.

    option -parmset \
        -configuremethod ConfigureParmSet

    method ConfigureParmSet {opt val} {
        set options($opt) $val
        set ps $val

        $self refresh
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create and layout the tree and scrollbar
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 0 -weight 1

        install tree using treectrl $win.tree \
            -borderwidth    0                 \
            -usetheme       1                 \
            -showroot       0                 \
            -showheader     0                 \
            -selectmode     single            \
            -itemwidthequal 1                 \
            -yscrollcommand [list $win.yscroll set]

        scrollbar $win.yscroll \
            -orient vertical   \
            -command [list $win.tree yview]

        grid $tree        -row 0 -column 0 -sticky nsew
        grid $win.yscroll -row 0 -column 1 -sticky ns

        # NEXT, define the tree's columns, styles, and elements.

        # Define new states
        $tree state define differs
        $tree state define readonly

        # Create the tree column.
        $tree column create
        $tree configure -treecolumn first

        $tree element create nameText text
        $tree element create nameRect rect \
            -fill {gray {active} \#99FFFF {differs} white {}}
        $tree style create nameStyle
        $tree style elements nameStyle {nameRect nameText}
        $tree style layout nameStyle nameText \
            -ipadx   2 \
            -pady    1 \
            -ipady   {2 1} \
            -iexpand e
        $tree style layout nameStyle nameRect -union {nameText}

        # Create the value column
        $tree column create \
            -tag      values  \
            -expand   yes     \
            -minwidth 100     \
            -maxwidth 400     \
            -squeeze  yes

        $tree style create valueStyle

        $tree element create valueText text \
            -font codefont

        $tree element create valueRect rect \
            -fill {gray {active} \#99FFFF {differs} white {}}
            
        $tree style elements valueStyle {valueRect valueText}

        $tree style layout valueStyle valueText \
            -iexpand e     \
            -ipadx   4     \
            -padx    10    \
            -pady    {1 2} \
            -ipady   {2 2}
        
        $tree style layout valueStyle valueRect \
            -union valueText

        # Next, define the editorStyle, used when we're editing.
        $tree style create editStyle

        $tree element create editWindow window
        $tree element create editRect rect \
            -fill {gray {}}

        $tree style elements editStyle {editRect editWindow}
        
        $tree style layout editStyle editWindow \
            -sticky nsw    \
            -iexpand nse   \
            -padx    10    \
            -pady    {1 2} \
            -ipadx   2 
        

        $tree style layout editStyle editRect \
            -union {editWindow}

        # Define the default column styles
        $tree configure -defaultstyle [list nameStyle valueStyle]

        # Bindings
        bind $tree <Return>    [mymethod ReturnOnTree]
        bind $tree <Double-1>  [mymethod DoubleClickOnTree %x %y]

        # NEXT, create the editors
        install stringEditor using entry $win.tree.stringEditor \
            -font codefont \
            -foreground black \
            -background white \
            -highlightthickness 0 \
            -width 30

        bind $stringEditor <Return> [mymethod SaveChangedValue]
        bind $stringEditor <Escape> [mymethod DisableEditing]

        # NEXT, configure the creation options
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # ReturnOnTree
    #
    # Entering return while the treectrl has the focus should enable
    # editing of the active item--if it's a parameter.

    method ReturnOnTree {} {
        # FIRST, if the -state is readonly, do nothing; editing is
        # not allowed.
        if {$options(-state) eq "readonly"} {
            return
        }

        # NEXT, Get the active item.
        set item [$tree item id active]

        # NEXT, if no item is active, or if the active item is a prefix,
        # there's nothing to do.
        if {$item eq "" || $info(type-$item) eq "prefix"} {
            return
        }

        # NEXT, edit the specified item.
        $self EditItem $item
    }

    # DoubleClickOnTree x y
    #
    # Double clicking on the tree control should enable editing of the
    # specified item.

    method DoubleClickOnTree {x y} {
        # FIRST, if the -state is readonly, do nothing; editing is
        # not allowed.
        if {$options(-state) eq "readonly"} {
            return
        }

        # NEXT, Get the item they clicked on
        set data [$tree identify $x $y]

        if {[lindex $data 0] ne "item" ||
            [lindex $data 2] ne "column"} {
            # They must have clicked on a particular column of a
            # particular item.
            return
        }

        set item [lindex $data 1]

        # NEXT, if item is a prefix, there's nothing to do.
        if {$info(type-$item) eq "prefix"} {
            return
        }

        # NEXT, edit the specified item.
        $self EditItem $item
    }

    # EditItem item
    #
    # item    The ID of the item to edit.
    #
    # Displays the editor widget for the item.
    
    method EditItem {item} {
        # FIRST, remember that we're editing this item.
        set editedItem $item
        
        # FIRST, load the parameter value into the editor
        $stringEditor delete 0 end
        $stringEditor insert 0 [$ps get $info(name-$item)]

        # NEXT, make the editor visible.
        $tree item style set $item values editStyle
        $tree item element configure $item values editWindow \
            -window $stringEditor

        # NEXT, select the entire string
        $stringEditor select range 0 end

        # NEXT, give the editor the focus; also, confine pointer
        # and keyboard events to the editor, until they are done editing.
        $stringEditor icursor end
        focus $stringEditor

        # Wait for visibility before grabbing; otherwise, we get a
        # "window not viewable" bgerror when double-clicking on an item.
        tkwait visibility $stringEditor
        grab set $stringEditor
    }

    # SaveChangedValue
    #
    # Attempts to save the active item's value.  Returns 1 on
    # success, and 0 on failure.  Also on failure, displays the
    # relevant error message, and makes sure the item is visible.

    method SaveChangedValue {} {
        # FIRST, if no item is active, just return.
        if {$editedItem == 0} {
            return 1
        }

        # NEXT, get the item's value.  Has it changed?
        set newValue [$stringEditor get]
        set oldValue [$ps get $info(name-$editedItem)]

        if {$newValue != $oldValue} {
            # FIRST, validate the value.  Do this by getting the
            # parameter's type and validating explicitly.  This would
            # be done implicitly if we simply tried to set the parameter,
            # but then we'd get a longer error message containing the
            # parameter name.  We don't need that; the widget itself
            # indicates the error context.  If we explicitly validate
            # using the parameter's type, we get a better error message
            # to display to the user.
            set ptype [$ps type $info(name-$editedItem)]

            if {[catch {$ptype validate $newValue} result]} {
                # FIRST, we failed; make sure the item is visible.
                # TBD: Display the error message (or pass it to a handler)
                set parent [$tree item parent $editedItem]

                while {$parent != 0} {
                    $tree item expand $parent
                    set parent [$tree item parent $parent]
                }

                $tree see $editedItem
                focus $stringEditor

                $stringEditor configure -background yellow
                
                callwith $options(-msgcmd) $result
                
                return 0
            }

            # The type is OK; save the value
            $ps set $info(name-$editedItem) $newValue
        }

        
        # NEXT, either the value hasn't changed or we succeeded in
        # saving it.  Disable editing, setting the focus back to the
        # tree.
        $self DisableEditing

        return 1
    }

    # DisableEditing
    #
    # Disables editing, returning the focus to the tree.  If the edited
    # value wasn't saved, it's thrown away.

    method DisableEditing {} {
        # FIRST, if no item is active, just return.
        if {$editedItem == 0} {
            return
        }

        # NEXT, Disable editing, and set the focus back to the
        # tree.
        $tree item element configure $editedItem values editWindow \
            -window ""
        $tree item style set $editedItem values valueStyle

        $self SetItemText $editedItem [$ps get $info(name-$editedItem)]

        grab release $stringEditor
        $stringEditor configure -background white

        focus $tree

        # NEXT, we're no longer editing an item.
        set editedItem 0
    }



    #-------------------------------------------------------------------
    # Public Methods

    # refresh
    #
    # Verifies that all of the parmset's data types are known to the
    # editor, and refreshes the display.  Call this explicitly if the
    # parmset is updated programmatically.  Note that the display
    # is refreshed automatically if -parmset is modified.

    method refresh {} {
        assert {$options(-parmset) ne ""}

        # FIRST, delete all items from the tree
        $tree item delete all

        # NEXT, verify that all of the parmsets types are registered.
        # TBD: Not needed until we provide different kinds of parameter
        # editor.

        # NEXT, populate the tree.
        set entries [$self GetParmEntries]

        foreach {entryType name} $entries {
            if {$entryType eq "prefix"} {
                $self DefinePrefix $name
            } elseif {$entryType eq "parm"} {
                $self DefineParm $name
            } else {
                error "invalid entry type: $entryType"
            }
        }

        $tree activate 1
    }

    # GetParmEntries
    #
    # Returns a list of parameter/prefix names.  It's a tagged list,
    #
    #    parm|prefix <name> ....
    #
    # TBD: Consider adding this to parmset(n) as a public method.

    method GetParmEntries {} {
        set entries {}

        foreach parm [$ps names] {
            set namelist [split $parm "."]

            set count [llength $namelist]

            # FIRST, add the prefixes if we haven't seen them before.
            for {set i 0} {$i < $count - 1} {incr i} {
                set prefix [join [lrange $namelist 0 $i] "."]

                # Add the prefix if necessary
                if {![info exists prefixes($prefix)]} {
                    lappend entries prefix $prefix
                    set prefixes($prefix) 1
                }
            }

            # NEXT, add the parameter itself
            lappend entries parm $parm
        }

        return $entries
    }

    # DefinePrefix name
    #
    # name    A parameter prefix name
    #
    # Adds the prefix with the specified name to the tree

    method DefinePrefix {name} {
        # FIRST, get the parent, if any
        set parentName [ParmParent $name]

        if {$parentName eq ""} {
            set parent root
        } else {
            set parent $info(id-$parentName)
        }

        # NEXT, create the item
        set item [$tree item create -parent $parent -button yes]
        set info(id-$name) $item
        set info(name-$item) $name
        set info(type-$item) prefix

        # NEXT, it should be collapsed initially.
        $tree item collapse $item

        # NEXT, set its label
        $tree item element configure $item tree nameText \
            -text [ParmTail $name]

        $tree item style set $item values ""
    }

    # DefineParm name
    #
    # name      A parameter name
    #
    # Adds the parameter to the tree.

    method DefineParm {name} {
        # FIRST, get the parent, if any
        set parentName [ParmParent $name]

        if {$parentName eq ""} {
            set parent root
        } else {
            set parent $info(id-$parentName)
        }

        # NEXT, create the item
        set item [$tree item create -parent $parent -button no]
        set info(id-$name) $item
        set info(name-$item) $name
        set info(type-$item) parm

        # NEXT, set its label
        $tree item element configure $item tree nameText \
            -text [ParmTail $name]

        set value [$ps get $name]

        $self SetItemText $item $value
    }

    # SetItemText item value
    #
    # item         An item's ID
    # value        A new value text string for the item

    method SetItemText {item value} {
        # FIRST, does the item's value differ from the
        # default?
        set defvalue [$ps getdefault $info(name-$item)]
        set info(differs-$item) 0

        if {$defvalue ne $value} {
            set info(differs-$item) 1
        } else {
            set info(differs-$item) 0
        }

        # NEXT, display the value.
        if {$value eq ""} {
            set value " "
        }

        $tree item element configure $item values valueText \
            -text $value

        # NEXT, mark the item as being different or not.
        if {$info(differs-$item)} {
            $tree item state set $item differs
        } else {
            $tree item state set $item !differs
        }

        # NEXT, compute the differs value for the ancestors, and mark
        # them accordingly.
        set parent [$tree item parent $item]

        while {$parent != 0} {
            set info(differs-$parent) 0

            foreach i [$tree item children $parent] {
                incr info(differs-$parent) $info(differs-$i)
            }

            if {$info(differs-$parent)} {
                $tree item state set $parent differs
            } else {
                $tree item state set $parent !differs
            }

            set parent [$tree item parent $parent]
        }
    }


    #-------------------------------------------------------------------
    # Utility Procs
    #
    # TBD: Perhaps these should be typemethods of parmset(n).

    # ParmParent parm
    #
    # parm      A parameter or prefix name.
    #
    # Given a parameter or prefix name, returns the parent prefix, or
    # or "" if none.

    proc ParmParent {parm} {
        join [lrange [split $parm "."] 0 end-1] "."
    }

    # ParmTail parm
    #
    # Given a parameter or prefix name, returns the final element
    # in the name, i.e., the text following the final "." or 
    # the entire name if there are no periods in the name.

    proc ParmTail {parm} {
        lindex [split $parm "."] end
    }
} 

