/***********************************************************************
 *
 * TITLE:
 *	version.c
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	JNEM: libVersion Tcl Commands
 *
 ***********************************************************************/

#include <stdio.h>

#include "version.h"


/*
 * Static Function Prototypes
 */

static int version_versionCmd  (ClientData, Tcl_Interp*, int, 
                                Tcl_Obj* CONST argv[]);

static int version_exitCmd     (ClientData, Tcl_Interp*, int, 
                                Tcl_Obj* CONST argv[]);

/*
 * Public Function Definitions
 */

/***********************************************************************
 *
 * FUNCTION:
 *	Version_Init()
 *
 * INPUTS:
 *	interp		A Tcl interpreter
 *
 * RETURNS:
 *	TCL_OK
 *
 * DESCRIPTION:
 *	Initializes the extension's Tcl commands
 */

int
Version_Init(Tcl_Interp *interp)
{
    /* Define the commands. */
    Tcl_CreateObjCommand(interp, "version", version_versionCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "exit",    version_exitCmd, NULL, NULL);

    return TCL_OK;
}


/*
 * Command Procedures
 *
 * The functions in this section are all Tcl command definitions,
 * with the standard calling sequence.  Rather than repeat the same
 * description over again, the header comment for each will 
 * describe the implemented Tcl command, along with any notable
 * details about the implementation.
 */

/***********************************************************************
 *
 * FUNCTION:
 *	version
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	The JNEM version number.
 *
 * DESCRIPTION:
 *	The JNEM version number has the form "x.y.z", where x, y, and z
 *	are integers.  If shark(1) is the product of an engineering build
 *      rather than an official build, it will return exactly the string 
 *      "x.y.z".
 */

static int 
version_versionCmd(ClientData cd, Tcl_Interp *interp, 
                int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
        return TCL_ERROR;
    }

    Tcl_SetResult(interp, JNEM_VERSION, TCL_STATIC);
    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	exit
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	The standard Tcl exit command unloads all shared object libraries
 *      before calling exit().  If the shared object library has 
 *      registered an atexit() handler, the application will then dump
 *      core on exit().  As the RTI registers an atexit() handler,
 *      this is the behavior we see.
 *
 *      This exit command replaces the original exit command, and
 *      simply calls exit() directly.  This is a stopgap until the
 *      "load -keeploaded" option is available.
 */

static int 
version_exitCmd(ClientData cd, Tcl_Interp *interp, 
                int objc, Tcl_Obj* CONST objv[])
{
    exit(0);
    return TCL_OK;
}

