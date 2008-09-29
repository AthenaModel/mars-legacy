#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_man(1) Application
#
#    This module defines app, the application ensemble.
#
#        package require mars_man
#        app init $argv
#
#    This program is a document processor for mars_man(5) man page
#    format.  mars_man(5) man pages are written in "Extended HTML", 
#    i.e., HTML extended with Tcl macros.  It automatically generates
#    tables of contents, etc., and provides easy linking to other
#    man pages.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Export macros
        namespace export \
            cget         \
            contents     \
            cpop         \
            cpush        \
            cset         \
            defitem      \
            deflist      \
            /deflist     \
            defopt       \
            expand       \
            expandFile   \
            exppass      \
            hrule        \
            indexfile    \
            indexlist    \
            iref         \
            itemlist     \
            lb           \
            link         \
            manpage      \
            /manpage     \
            manurl       \
            mktree       \
            nbsp         \
            rb           \
            section      \
            subsection   \
            textToID     \
            xref         \
            xrefset
            
    }

    #-------------------------------------------------------------------
    # Type Variables

    ;# Which expansion pass we're on, pass 1 or pass 2
    typevariable pass 1

    # Mars Version Number
    typevariable version x.y.z 

    # Source directory
    typevariable srcdir "."

    # Destination directory
    typevariable destdir "."

    # Manpage section title
    typevariable sectionTitle ""

    # The relative URL for man pages.
    typevariable manurl ".."

    # An array of additional xref links
    array set xreflinks {}

    # An array: key is module name, value is list of submodules.
    # modules with no parent are under submodule().
    typevariable submodule

    # An array: key is module name, value is description.
    typevariable module

    # Mktree script flag
    typevariable mktreeFlag 0

    # Man Page variables

    typevariable items {}        ;# List of item tags, in order of definition 
    typevariable itemtext        ;# Array, item text by tag
    typevariable sections {}     ;# List of section names, in order of 
                                  # definition.
    typevariable curSection {}   ;# Current section
    typevariable subsections     ;# Array of subsection names by parent 
                                  # section.
    typevariable optsfor         ;# Option data
    typevariable opttext         ;# Option text

    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv         Command line arguments
    #
    # This the main program.

    typemethod init {argv} {
        # FIRST, create and configure the expander
        textutil::expander theExpander

        theExpander lb "<<"
        theExpander rb ">>"

        # NEXT, import the macros
        namespace eval :: { namespace import ::app::* }
        
        while {[string match "-*" [lindex $argv 0]]} {
            set opt [lindex $argv 0]
            set val [lindex $argv 1]
            set argv [lrange $argv 2 end]
            
            switch -exact -- $opt {
                -version {
                    set ::version $val
                }
                -destdir {
                    if {![file exists $val] && [file isdirectory $val]} {
                        puts stderr "Error: '$val' is not a valid directory."
                        exit 1
                    }
                    set ::destdir $val
                }
                -srcdir {
                    if {![file exists $val] && [file isdirectory $val]} {
                        puts stderr "Error: '$val' is not a valid directory."
                        exit 1
                    }
                    set ::srcdir $val
                }
                -section {
                    set ::sectionTitle $val
                }
                default {
                    puts stderr "Unknown option: '$opt'."

                    showhelp
                    exit 1
                }
            }
        }

        if {[llength $argv] != 0} {
            showhelp
            exit 1
        }

        set files [glob -nocomplain $srcdir/*.ehtml]

        if {[llength $files] == 0} {
            showhelp
            exit
        }

        foreach infile $files {
            set manfile [file tail [file root $infile]].html
            set outfile [file join $destdir $manfile]

            if {[catch {expandFile $infile} output]} {
                puts stderr $output
                exit 1
            }

            set f [open $outfile w]
            puts $f $output
            close $f
        }

        # NEXT, output the index
        set outfile [file join $destdir index.html]
        set f [open $outfile w]
        puts $f [indexfile]
        close $f
    }

    #-------------------------------------------------------------------
    # Utility Routines

    # ShowUsage
    #
    # Display command line syntax.

    proc ShowUsage {} {
        puts {Usage: mars_man [options...]

Options:
    -version x.y.z             Project version number
    -srcdir <path>             Source directory.
    -destdir <path>            Destination directory.
    -section <title>           Man page section title

For each file.ehtml in the source directory, produces file.html in the 
destination directory.  Both source and destination default to the
current working directory.
}
    }

    #-------------------------------------------------------------------
    # Macros

    # lb
    #
    # Return the left bracket sequence
    proc lb {} { 
        return "&lt;&lt;" 
    }

    # rb
    #
    # Return the right bracket sequence

    proc rb {} { 
        return "&gt;&gt;" 
    }

    # exppass
    #
    # Return the expansion pass number, 1 or 2

    proc exppass {} { 
        return $pass 
    }

    # cget varname
    #
    # varname    A cset variable name.
    #
    # Get the value of the expansion stack variable

    proc cget {varname} { 
        theExpander cget $varname 
    }

    # cpop cname
    #
    # cname    Name of a pushed expansion stack level
    #
    # Pop an expansion stack level

    proc cpop {cname} { 
        theExpander cpop $cname 
    }

    # cpush cname
    #
    # cname    Name of an expansion stack level
    #
    # Push a stack level; use cset and cget to associated variables
    # with it.

    proc cpush {cname} { 
        theExpander cpush $cname 
    }

    # cset varname value
    #
    # varname    An expansion stack variable
    # value      A value
    #
    # Assigns the value to the expansion stack level.

    proc cset {varname value} { 
        theExpander cset $varname $value 
    }

    # expandFile name
    #
    # name    An input file name
    #
    # Process a file and return the expanded output.

    proc expandFile {name} {
        # Pass 1 -- for indexing
        set f [open $name]
        set input [read $f]
        close $f

        set pass 1
        theExpander expand $input

        set pass 2
        return [theExpander expand $input]
    }

    # Converts a generic string to an ID string.  Leading and trailing
    # whitespace and internal punctuation is removed, internal whitespace
    # is converted to "_", and the text is converted to lower case.
    proc textToID {text} {
        # First, trim any white space and convert to lower case
        set text [string trim [string tolower $text]]
        
        # Next, substitute "_" for internal whitespace, and delete any
        # non-alphanumeric characters (other than "_", of course)
        regsub -all {[ ]+} $text "_" text
        regsub -all {[^a-z0-9_/]} $text "" text
        
        return $text
    }

    #-----------------------------------------------------------------------
    # Simple Macros

    # expand text
    #
    # text   Input text
    #
    # Recursive expansion

    proc expand {text} {
        return [theExpander expand $text]
    }

    # manurl
    #
    # The relative URL for man pages

    proc manurl {} {
        return $manurl
    }

    # nbsp text
    #
    # text    A text string
    #
    # Makes a string nonbreaking, normalizing spaces.
    proc nbsp {text} {
        set text [string trim $text]
        regsub {\s\s+} $text " " text

        return [string map {" " &nbsp;} $text]
    }

    # hrule
    #
    # Horizontal rule

    template proc hrule {} {<p><hr></p>}

    # link url ?anchor?
    #
    # url     The URL to link to
    # anchor  The text to display, if different
    #
    # Creates an HTML link

    template proc link {url {anchor ""}} {
        if {$anchor eq ""} {
            set anchor $url
        }
    } {<a href="$url">$anchor</a>}


    #-----------------------------------------------------------------------
    # Cross-references

    # xrefset id anchor url
    #
    # id        Name to be used in <<xref ...>> macro
    # anchor    The text to be displayed as an anchor
    # url       The URL to link to.
    #
    # Define an ad-hoc cross reference.
    proc xrefset {id anchor url} {
        set xreflinks($id) [list $anchor $url]
        
        # Return nothing, so that this can be used in macros.
        return ""
    }

    # xref id ?anchor?
    #
    # id       The XREF id of the page to link to
    # anchor   The anchor text, if different
    #
    # Links to a section or manpage.

    proc xref {id {anchor ""}} {
        if {[exppass] == 1} {
            return
        }

        set subtopic {}

        if {[info exists xreflinks($id)]} {
            set url [lindex $xreflinks($id) 1]
            set defaultAnchor [lindex $xreflinks($id) 0]
        } elseif {[regexp {^([^()]+)\(([1-9in])\)$} $id dummy name section]} {
            set url "[manurl]/man$section/$name.html"
            set defaultAnchor $id
            set subtopic "#[textToID $anchor]"
        } elseif {[string match "http:*" $id]} {
            set url $id
            set defaultAnchor $id
        } elseif {[lsearch -exact $sections $id] != -1} {
            set url "#[textToID $id]"
            set defaultAnchor $id
        } else {
            puts "Warning: xref: unknown id '$id'"
            return "[lb]xref $id[rb]"
        }
        
        if {$anchor eq ""} {
            set anchor $defaultAnchor
        }

        return "<a href=\"$url$subtopic\">$anchor</a>"
    } 

    #-------------------------------------------------------------------
    # Javascripts
    
    # If included in man page, the mktree script is included
    proc mktree {} {
        set mktreeFlag 1
        
        return
    }

    #-------------------------------------------------------------------
    # Man Page Template

    # manpage nameList description
    #
    # nameList     List of man page names, from ancestor to this page
    # description  One line description of contents
    #
    # Begins a man page.

    template proc manpage {nameList description} {
        set name [lindex $nameList end]

        if {[llength $nameList] > 1} {
            set parent [lindex $nameList 0]
            set parentRef ", submodule of [xref $parent]"
            set titleParentRef ", submodule of $parent"
        } else {
            set parent ""
            set parentRef ""
            set titleParentRef ""
        }

        if {[exppass] == 1} {
            set items {}
            array unset itemtext
            array unset optsfor
            array unset opttext
            set sections {}
            array unset subsections
            set curSection {}
            set module($name) $description
            lappend submodule($parent) $name
        }
    } {
        |<--
        <html>
        <head>
        <title>Mars $version: $name -- $description$titleParentRef</title>
        <style type="text/css" media="screen,print">
        a {
            text-decoration: none;
        }
        body {
            color: black;
            background: white;
            margin-left: 6%;
            margin-right: 6%;
        }
        h2 {
            margin-left: -5%;
        }
        hr {
            margin-left: -5%;
        }
        pre {
            background:     #FFFF99 ;
            border:         1px solid blue;
            padding-top:    2px;
            padding-bottom: 2px;
            padding-left:   4px;
        }
        table {
            margin-top:    4px;
            margin-bottom: 4px;
        }
        th {
            padding-left: 4px;
        }
        td {
            padding-left: 4px;
        }
        
        [tif {$mktreeFlag} {
            |<--
            /* mktree styles */
            ul.mktree  li  { list-style: none; }
            ul.mktree, ul.mktree ul, ul.mktree li { 
                margin-left:10px; padding:0px; }
            ul.mktree li .bullet { padding-left: 10px }
            ul.mktree  li.liOpen   .bullet {cursor : pointer; }
            ul.mktree  li.liClosed .bullet {cursor : pointer; }
            ul.mktree  li.liBullet .bullet {cursor : default; }
            ul.mktree  li.liOpen   ul {display: block; }
            ul.mktree  li.liClosed ul {display: none; }
        }]
        </style>
        
        [tif {$mktreeFlag} {
            |<--
            [readfile [file join $::mars_man::library mktree.js]]
        }]

        </head>

        <body>
        [section NAME]

        $name -- $description$parentRef
        
        [contents]
    }

    # /manpage
    #
    # Terminates a man page

    template proc /manpage {} {
        |<--
        <hr>
        <i>Mars $version Man page generated by mars_man(1) on 
        [clock format [clock seconds]]</i>
        </body>
        </html>
    }

    # section name
    #
    # name    A section name
    #
    # Begins a major section.

    template proc section {name} {
        set name [string toupper $name]
        set id [textToID $name]
        if {[exppass] == 1} {
            lappend sections $name 
        }

        set curSection $name
    } {
        |<--
        <h2><a name="$id">$name</a></h2>
    }

    # subsection name
    #
    # name     A subsection name
    #
    # Begins a subsection of a major section

    template proc subsection {name} {
        set id [textToID $name]
        if {[exppass] == 1} {
            lappend subsections($curSection) $name 
            xrefset $name $name "#$id"
        }
    } {
        |<--
        <h2><a name="$id">$name</a></h2>
    }

    # contents
    #
    # Produces a list of links to the sections and subsections.

    template proc contents {} {
        |<--
        <ul>
        [tforeach name $sections {
            <li><a href="#[textToID $name]">$name</a></li>
            [tif {[info exists subsections($name)]} {
                |<--
                <ul>
                [tforeach subname $subsections($name) {
                    <li><a href="#[textToID $subname]">$subname</a></li>
                }]
                </ul>
            }]
        }]
        </ul>
    }

    # deflist args
    #
    # Begins a definition list. The args don't matter, but can be used
    # as comments.  
    template proc deflist {args} {
        |<--
        <dl>
    }

    # /deflist args
    #
    # Ends a definition list.   The args don't matter, but can be used
    # as comments. 
    template proc /deflist {args} {
        |<--
        </dl>
    }

    # defitem item text
    #
    # item     iref identifier for this item
    # text     Text to display
    #
    # Introduces an item in an item list, and provides the href 
    # anchor.

    template proc defitem {item text} {
        lappend items $item
        set itemtext($item) $text
    } {
        |<--
        <dt><b><tt><a name="[textToID $item]">$text</a></tt></b></dt>
        <dd>
    }

    # itemlist
    #
    # Produces a list of links to the defined items, for use in the
    # synopsis section of the man page.

    template proc itemlist {} {
        |<--
        [tforeach tag $items {
            |<--
            <tt><a href="#[textToID $tag]">$itemtext($tag)</a></tt><br>
            [tif {[info exists optsfor($tag)]} {
                |<--
                [tforeach opt $optsfor($tag) {
                    |<--
                    &nbsp;&nbsp;&nbsp;&nbsp;
                    <tt><a href="#$tag$opt">$opttext($tag$opt)</a></tt><br>
                }]
            }]
        }]<p>
    }

    # iref args
    #
    # args    An item ID, which might be multiple tokens.
    #
    # Creates a link to the item in this page.

    proc iref {args} {
        set tag $args

        if {[exppass] == 1} {
            return
        }

        if {[lsearch -exact $items $tag] != -1} {
            return "<tt><a href=\"#[textToID $tag]\">$tag</a></tt>"
        } else {
            puts stderr "Warning, iref not found: '$tag'"
            return "<tt>$tag</tt>"
        }
    }

    # defopt text
    #
    # text     Text defining an option, e.g., "-foo <i>bar</i>"
    #
    # An item in an item list that defines an option to a command.

    template proc defopt {text} {
        set opt [lindex $text 0]
        set lastItem [lindex $items end]
        set id "$lastItem$opt"
        lappend optsfor($lastItem) $opt
        set opttext($id) $text
    } {
        |<--
        <dt><b><tt><a name="$id">$text</a></tt></b></dt>
        <dd>
    }

    #-------------------------------------------------------------------
    # Index File Template

    # indexfile
    #
    # Template for the index file created for a directory full of 
    # man pages.

    template proc indexfile {} {
        set title "Mars $version Man Pages: $sectionTitle"
    } {
        |<--
        <head>
        <title>$title</title>
        <style>
        body {
            color: black;
            background: white;
            margin-left: 5%;
            margin-right: 5%;
        }
        </style>
        </head>
        <body>
        <h2>$title</h2>
        <hr>

        [indexlist $submodule()]

        <hr>
        <i>Index generated by mars_man(1) on [clock format [clock seconds]]</i>
        </body>
        </html>
    }

    # indexlist modules
    #
    # modules    List of module names
    #
    # Produces a list of links to man pages

    template proc indexlist {modules} {
        |<--
        <ul>
        [tforeach mod [lsort $modules] {
            |<--
            <li>
            [xref $mod]: $module($mod)
            [tif {[info exists submodule($mod)]} {
                |<--
                [indexlist $submodule($mod)]
            }]
            </li>
            
        }]
        </ul>
    }
}











