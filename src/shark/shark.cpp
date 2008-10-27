/***********************************************************************
 *
 * TITLE:
 *      shark.c
 *
 * AUTHOR:
 *      Will Duquette
 *
 * DESCRIPTION:
 *      JNEM tclsh main module.
 *
 ***********************************************************************/

#include "shark.h"

/*
 * Main Routine
 */

/***********************************************************************
 *
 * FUNCTION:
 *      main()
 *
 * INPUTS:
 *      argc
 *      argv
 *
 * OUTPUTS:
 *      none
 *
 * RETURNS:
 *      0
 *
 * EXTERNAL VARIABLES
 *      none
 *
 * DESCRIPTION:
 *      This is the standard "main" for extended Tcl shells, with a
 *	few tidbits added in.
 */

int 
main(int argc, char** argv)
{
    /* NEXT, initialize Tcl and go. */
    Tcl_Main(argc, argv, Tcl_AppInit);

    return 0;
}

/*
 * Initialization
 */

/***********************************************************************
 *
 * FUNCTION:
 *      Tcl_AppInit()
 *
 * INPUTS:
 *      interp		The Tcl interpreter which is being initialized.
 *
 * OUTPUTS:
 *      none
 *
 * RETURNS:
 *      TCL_ERROR or TCL_OK
 *
 * EXTERNAL VARIABLES
 *      none
 *
 * DESCRIPTION:
 *      Initializes a new Tcl interpreter.
 */

int 
Tcl_AppInit(Tcl_Interp *interp)
{
    /* FIRST, initialize the Tcl interpreter. */
    if (Tcl_Init(interp) == TCL_ERROR) {
	return TCL_ERROR;
    }

    /* NEXT, define the user-specific startup file for interactive
    ** sessions. */
    Tcl_SetVar(interp, "tcl_rcFileName", "~/.sharkrc", TCL_GLOBAL_ONLY);

    return TCL_OK;
}


