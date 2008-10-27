#-----------------------------------------------------------------------
# TITLE:
#    orders2.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Orders Screen prototype
#
#-----------------------------------------------------------------------

package require Tk 8.4
package require gui

#-----------------------------------------------------------------------
# Main routine

proc main {} {
    global db

    # FIRST, define the concerns and factions
    marsutil::enum concerns {
        RD "Religious Dominance"
        SE "Security"
        QL "Quality of Life"
        IS "Infrastructure"
        TA "Territorial Autonomy"
    }

    marsutil::enum factions {
        SHIA "Iraqi Shias"
        SUNN "Iraqi Sunnis"
        KURD "Iraqi Kurds"
    }

    # NEXT, create the treenotebook
    ::gui::treenotebook .tn \
        -treewidth 15 \
        -raisecmd Raise

    .tn add magic \
        -text "Magic"
    
    .tn add magic-event \
        -parent magic \
        -text "Magic Event"

    .tn opentree magic

    pack .tn -fill both -expand 1

    LayoutMagic .tn
    LayoutMagicEvent .tn

    .tn compute_size

    .tn raise magic
}

proc Raise {win page} {
    puts "raise $win $page"
}

proc LayoutMagic {tn} {
    set page [$tn getframe magic]

    label $page.title \
        -text "Magic Orders" \
        -font {Helvetica 40}

    pack $page.title -fill both -expand 1 -padx 10

    return 
}

proc LayoutMagicEvent {tn} {
    set page [$tn getframe magic-event]

    frame $page.frm \
        -borderwidth 0 \
        -relief flat

    set frm $page.frm

    label $frm.title \
        -text "Magic Event" \
        -font {Helvetica 40}

    grid $frm.title -row 0 -column 0 -columnspan 2 -pady 10 -padx 10

    
    grid columnconfigure $frm 0 -weight 0
    grid columnconfigure $frm 1 -weight 1

    # Start Time
    label $frm.timelabel \
        -text "Start Time:"

    grid $frm.timelabel -row 2 -column 0 -sticky w

    entry $frm.time \
        -width 12

    grid $frm.time -row 2 -column 1 -sticky ew

    # Concern
    label $frm.concernlabel \
        -text "Concern:"

    grid $frm.concernlabel -row 3 -column 0 -sticky w

    entry $frm.concern \
        -width 12

    grid $frm.concern -row 3 -column 1 -sticky ew
    
    # Target
    label $frm.targetlabel \
        -text "Target:"

    grid $frm.targetlabel -row 4 -column 0 -sticky w

    entry $frm.target \
        -width 12

    grid $frm.target -row 4 -column 1 -sticky ew

    # Magnitude
    label $frm.maglabel \
        -text "Magnitude:"

    grid $frm.maglabel -row 5 -column 0 -sticky w

    entry $frm.mag \
        -width 12

    grid $frm.mag -row 5 -column 1 -sticky ew

    # Tau
    label $frm.taulabel \
        -text "Tau:"

    grid $frm.taulabel -row 6 -column 0 -sticky w

    entry $frm.tau \
        -width 12

    grid $frm.tau -row 6 -column 1 -sticky ew

    set bar [frame $page.bar \
                 -borderwidth 0 \
                 -relief flat]

    button $bar.clear \
        -text "Clear"

    button $bar.send \
        -text "Send"

    grid $bar.clear $bar.send

    # Pack page contents
    pack $bar -side bottom -fill x -padx 4 -pady 5
    pack $frm -fill both -padx 4

    

    return 
}

#-----------------------------------------------------------------------
# Execute the main program and enter the event loop.

main
