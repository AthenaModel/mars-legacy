#----------------------------------------------------------------------
# TITLE:
#   template.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION
#   The template(n) module contains a number of routines for the 
#   creation and use of text templates. A template is a Tcl command 
#   that, given zero or more arguments, returns text based on the 
#   arguments and a template string which references the arguments.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::paxutil:: {
    namespace export tsubst
    namespace export template
    namespace export tforeach
    namespace export tif
    namespace export swallow
    namespace export defval
}

#-----------------------------------------------------------------------
# Public commands

#-----------------------------------------------------------------------
# NAME
#   tsubst tstring
#
# INPUTS
#   tstring   - A template string
#
# RETURNS
#   A subst'd string
#
# DESCRIPTION
#   tstring is a template string.  
#   If the first non-whitespace token is anything but "|<--", then
#   tsubst simply calls subst to substitute variables, backslashes,
#   and command calls.  Otherwise, the "|" in "|<--" marks the leftmost
#   column of the template string.  That column is remembered, and all
#   text up to and including the "\n" at the end of the line that
#   begins "|<--" is deleted.  Then, the excess whitespace is trimmed 
#   from the beginning of each successive line.  Finally, subst is
#   called on the modified template, and the result is returned.

proc ::paxutil::tsubst {tstring} {
    # If the string begins with the indent mark, process it.
    if {[regexp {^(\s*)\|<--[^\n]*\n(.*)$} $tstring dummy leader body]} {

        # Determine the indent from the position of the indent mark.
        if {![regexp {\n([^\n]*)$} $leader dummy indent]} {
            set indent $leader
        }

        # Remove the ident spaces from the beginning of each indented
        # line, and update the template string.
        regsub -all -line "^$indent" $body "" tstring
    }

    # Process and return the template string.
    return [uplevel 1 [list subst $tstring]]
}

#-----------------------------------------------------------------------
# NAME
#   template name arglist ?initbody? template
#
# INPUTS
#   name        - The template command's name
#   arglist     - The template command's argument list
#   initbody    - Optionally, some code to execute before evaluating
#                 the template.
#   template    - The actual "subst" template string.
#
# DESCRIPTION
#   Defines a template command called "name" in the caller's
#   context.  The template takes the arguments listed in
#   "arglist", which follows the normal Tcl proc rules.  When
#   called, the template command does a "subst" on the "template"
#   string and returns the result.  If given, "initbody" is
#   executed before the substitution; it can define variables to
#   be used in the template string, including declaring
#   global variables.

proc ::paxutil::template {name arglist initbody {template ""}} {
    # FIRST, have we an initbody?
    if {"" == $template} {
        set template $initbody
        set initbody ""
    }

    # NEXT, define the body of the new proc so that the initbody, 
    # if any, is executed and then the substitution is 
    set body "$initbody\n    tsubst [list $template]\n"

    # NEXT, define
    uplevel 1 [list proc $name $arglist $body]
}


#-----------------------------------------------------------------------
# NAME
#   tforeach vars items ?initbody? template
#
# INPUTS
#   vars       - A list of index variable names
#   items      - A list of items to iterate over
#   initbody   - Initializations to perform before each substitution.
#   template   - A template string.
#
# RETURNS
#   A substituted string.
#
# DESCRIPTION
#   Iterates vars over items in the manner of "foreach".  On each
#   iteration, does a subst on the template, accumulating the
#   result.  The subst is done in the caller's context; the index
#   variables are available as well.

proc ::paxutil::tforeach {vars items initbody {template ""}} {
    # FIRST, have we an initbody?
    if {"" == $template} {
        set template $initbody
        set initbody ""
    }

    # NEXT, define the variables.
    foreach var $vars {
        upvar $var $var
    }

    set results ""

    foreach $vars $items {
        if {"" != $initbody} {
            uplevel $initbody
        }
        set result [uplevel [list tsubst $template]]
        append results $result
    } 

    return $results
}


#-----------------------------------------------------------------------
# NAME
#   tif condition thenbody else ?elsebody?
#
# INPUTS
#   condition   - A boolean expression
#   thenbody    - Template to subst if condition is true
#   elsebody    - Template to subst if condition is false;
#                   defaults to ""
#
# RETURNS
#   A substituted string, or "".
#
# DESCRIPTION
#   Calls subst in the caller's context on either thenbody or
#   elsebody, depending on whether condition is true or not.

proc ::paxutil::tif {condition thenbody {"else" "else"} {elsebody ""}} {
    # FIRST, evaluate the condition
    set flag [uplevel 1 [list expr $condition]]

    # NEXT, evaluate one or the other
    if {$flag} {
        uplevel 1 [list tsubst $thenbody]
    } else {
        uplevel 1 [list tsubst $elsebody]
    }
}


#-----------------------------------------------------------------------
# NAME
#   swallow body
#
# INPUTS
#   body    - A Tcl script.
#
# DESCRIPTION
#   Evaluates its body in the caller's context, but always returns
#   the empty string.

proc ::paxutil::swallow {body} {
    uplevel 1 $body
    return
}


#-----------------------------------------------------------------------
# NAME
#   defval aString defaultValue
#
# INPUTS
#   aString       - Some string
#   defaultValue  - Its default value
#
# RETURNS
#   A string or its default
#
# DESCRIPTION
#   If the string is not empty, returns it; otherwise, returns
#   the default value.

proc ::paxutil::defval {aString defaultValue} {
    if {"" != $aString} {
        return $aString
    } else {
        return $defaultValue
    }
}

#-------------------------------------------------------------------
# snit::macros

#-----------------------------------------------------------------------
# NAME
#   Macro: template name arglist ?initbody? template
#
# INPUTS
#   proctype    - proc, method, typemethod
#   name        - The template command's name
#   arglist     - The template command's argument list
#   initbody    - Optionally, some code to execute before evaluating
#                 the template.
#   template    - The actual "subst" template string.
#
# DESCRIPTION
#   Defines a proc, method, or typemethod which is a template.

snit::macro template {proctype name arglist initbody {template ""}} {
    # FIRST, have we an initbody?
    if {"" == $template} {
        set template $initbody
        set initbody ""
    }

    # NEXT, define the body of the new proc so that the initbody, 
    # if any, is executed and then the substitution is 
    set body "$initbody\n    ::paxutil::tsubst [list $template]\n"

    # NEXT, define
    uplevel 1 [list $proctype $name $arglist $body]
}


