#-----------------------------------------------------------------------
# TITLE:
#    treenotebook.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    JNEM gui(n) package: Tree Notebook widget
#
#    A Tree Notebook is a BWidget PagesManager controlled by a BWidget
#    Tree widget.  Each node in the tree has an associated page in the
#    PagesManager; selecting a node displays the associated page.
#
#    The caller creates a Tree Notebook, then adds nodes to the tree,
#    which creates and returns a frame for each page.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::gui:: {
    namespace export treenotebook
}


#-----------------------------------------------------------------------
# The treenotebook Widget Type

snit::widget ::gui::treenotebook {
    widgetclass TreeNotebook

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        option add *TreeNotebook.treebackground white
        option add *TreeNotebook.treeforeground black
    }

    #-------------------------------------------------------------------
    # Components

    component tree      ;# The tree of nodes
    component pager     ;# The page manager

    #-------------------------------------------------------------------
    # Options

    # Delegated to tree
    
    delegate option -treewidth      to tree as -width
    delegate option -treebackground to tree as -background
    delegate option -treeforeground to tree as -linesfill
    delegate option -treelines      to tree as -showlines

    # -raisecmd cmd
    #
    # cmd      A command prefix
    #
    # This command is called when a page is about to be raised.  The
    # treenotebook's window name and the page's logical name are lappended
    # to $cmd.

    option -raisecmd -default {}

    #-------------------------------------------------------------------
    # Instance variables

    # TBD

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create a tree widget.
        frame $win.treepane \
            -borderwidth 3 \
            -relief ridge

        install tree using Tree $win.treepane.tree \
            -borderwidth 0 \
            -deltay 16 \
            -takefocus 1 \
            -selectcommand [mymethod SelectHandler] \
            -yscrollcommand [list $win.treepane.yscroll set]

        scrollbar $win.treepane.yscroll \
            -orient vertical \
            -takefocus 0 \
            -command [list $tree yview]

        pack $win.treepane.yscroll -side right -fill y
        pack $tree -side left -padx 2 -pady 2 -fill both -expand 1

        # NEXT, create the pager
        frame $win.pagerpane \
            -borderwidth 1 \
            -relief raised

        install pager using PagesManager $win.pagerpane.pager
        pack $pager -fill both -expand 1
            

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, pack everything.
        pack $win.treepane -side left -fill y -expand 0
        pack $win.pagerpane -side left -fill both -expand 1
    }

    #-------------------------------------------------------------------
    # Private Methods

    # SelectHandler w pages
    #
    # w      The tree widget
    # pages  A list of selected pages
    #
    # This is called by the tree widget when a node is selected.  In 
    # our case, we want to raise the relevant page in the PagesManager
    # when its node is selected--unless they've selected more than one.

    method SelectHandler {w pages} {
        if {[llength $pages] == 1} {
            # FIRST, get the page name
            set page [lindex $pages 0]

            # NEXT, call the -raisecmd
            if {[llength $options(-raisecmd)] > 0} {
                set cmd $options(-raisecmd)
                
                lappend cmd $win $page

                uplevel \#0 $cmd
            }
            
            # NEXT, make the page visible
            $pager raise [lindex $pages 0]
        }
    }
    

    #-------------------------------------------------------------------
    # Public Methods

    # Methods delegated to the pager
    delegate method compute_size to pager
    delegate method getframe     to pager
    delegate method pages        to pager

    # Methods delegated to the tree
    delegate method closetree to tree
    delegate method opentree  to tree
    delegate method parent    to tree
    delegate method children  to tree as nodes

    # add page ?options...?
    #
    # page       The logical name of the page.
    #
    # options    -parent    Logical name of parent; defaults to "root"
    #            -text      Displayed name of page; defaults to $page
    #            -image     Displayed image; defaults to {}.
    #
    # Adds a page to the notebook and includes it in the tree.  Returns
    # the name of the page's frame, which can also be retrieved using
    # getframe.

    method add {page args} {
        # FIRST, get the default option values 
        set opt(-parent) root
        set opt(-text)   $page
        set opt(-image)  {}

        # NEXT, save the caller's options
        array set opt $args

        # NEXT, insert the tree node and add the page.
        $tree insert end $opt(-parent) $page \
            -text  $opt(-text) \
            -fill [$tree cget -linesfill]

        if {$opt(-image) ne ""} {
            $tree itemconfigure $page -image $opt(-image)
        } else {
            $tree itemconfigure $page -padx 0
        }

        return [$pager add $page]
    }

    # raise page
    #
    # page        The name of a page in the notebook.
    #
    # Selects the named page in the tree, making sure it's visible,
    # and displays the associated page in the pager.
    #
    # Note that the page is actually raised by SelectHandler, which
    # is registered as the tree's -selectcommand.

    method raise {page} {
        $tree see $page
        $tree selection set [list $page]
    }
}

