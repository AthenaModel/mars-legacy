/***********************************************************************
 *
 * TITLE:
 *	region.cpp
 *
 * AUTHOR:
 *	Jon Stinzel
 *
 * DESCRIPTION:
 *	JNEM: rti(n) RTI Binding for RTI::Region
 *
 *      This module defines the set of Tcl commands that comprise the
 *      bining for the RTI::Region class.
 *
 ***********************************************************************/

#include "tcl_rti.h"


/* RTI::Region Subcommands */
static int rtiRegion_getRangeLowerBound (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);
static int rtiRegion_getRangeUpperBound (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);

static int rtiRegion_setRangeLowerBound (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);
static int rtiRegion_setRangeUpperBound (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);

static int rtiRegion_getSpaceHandle     (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);

static int rtiRegion_getNumberOfExtents (ClientData, Tcl_Interp*, 
                                         int, Tcl_Obj* CONST argv[]);

static int 
rtiRegion_getRangeLowerBoundNotificationLimit (ClientData, Tcl_Interp*, 
                                               int, Tcl_Obj* CONST argv[]);
static int 
rtiRegion_getRangeUpperBoundNotificationLimit (ClientData, Tcl_Interp*, 
                                               int, Tcl_Obj* CONST argv[]);

/*
 * Static Function Prototypes
 */

static int  throwTclError          (Tcl_Interp*, RTI::Exception&);
static int  getRegionFromObj       (Tcl_Interp*, Tcl_Obj*, RTI::Region**);

static SubcommandVector rtiRegionSubTable [] = {

    {"getRangeLowerBound",  rtiRegion_getRangeLowerBound},
    {"getRangeUpperBound",  rtiRegion_getRangeUpperBound},

    {"setRangeLowerBound",  rtiRegion_setRangeLowerBound},
    {"setRangeUpperBound",  rtiRegion_setRangeUpperBound},

    {"getSpaceHandle",      rtiRegion_getSpaceHandle},
    {"getNumberOfExtents",  rtiRegion_getNumberOfExtents},

    {"getRangeLowerBoundNotificationLimit",  
     rtiRegion_getRangeLowerBoundNotificationLimit},

    {"getRangeUpperBoundNotificationLimit",  
     rtiRegion_getRangeUpperBoundNotificationLimit},

    {NULL, NULL}
};

/*
 * Tcl Command Procedures
 *
 * All functions in this section have Tcl "object command" calling
 * conventions.  Consequently, the INPUTS, OUTPUTS, and RETURNS are
 * described in terms of the implemented Tcl command, rather than
 * the actual C code.
 */

/***********************************************************************
 *
 * FUNCTION:
 *	rtiRegion_instanceCmd()
 *
 * INPUTS:
 *	subcommand		The subcommand name
 *      args                    Subcommand arguments
 *
 * RETURNS:
 *	Whatever the subcommand returns.
 *
 * DESCRIPTION:
 *	This is the instance command for RTI::Region objects created
 *      by rti_RTIambassador.  It looks up the subcommand name, and
 *      then passes execution to the subcommand proc.
 */

int 
rtiRegion_instanceCmd(ClientData cd, Tcl_Interp* interp, 
                      int objc, Tcl_Obj* CONST objv[])
{
    if (objc < 2) 
    {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg arg ...?");
        return TCL_ERROR;
    } 

    int index = 0;

    if (Tcl_GetIndexFromObjStruct(interp, objv[1], 
                                  rtiRegionSubTable, sizeof(SubcommandVector),
                                  "subcommand",
                                  TCL_EXACT,
                                  &index) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return (*rtiRegionSubTable[index].proc)(cd, interp, objc, objv);
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getRangeLowerBound theExtent theDimension
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *
 * RETURNS:
 *       The lower bound of the specified dimension
 *
 * DESCRIPTION:
 *       Queries the lower bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_getRangeLowerBound(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension");
        return TCL_ERROR;
    }

    long theExtent, theDimension;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }


    RTI::ULong bound;

    /* Determine the bound */
    try 
    {
        bound = region->getRangeLowerBound(theExtent, theDimension);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, bound);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getRangeUpperBound theExtent theDimension
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *
 * RETURNS:
 *       The upper bound of the specified dimension
 *
 * DESCRIPTION:
 *       Queries the upper bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_getRangeUpperBound(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension");
        return TCL_ERROR;
    }

    long theExtent, theDimension;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }


    RTI::ULong bound;

    /* Determine the bound */
    try 
    {
        bound = region->getRangeUpperBound(theExtent, theDimension);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, bound);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region setRangeLowerBound theExtent theDimension theBound
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *       theBound      Value of the lower bound to set
 *
 * RETURNS:
 *       nothing
 *
 * DESCRIPTION:
 *       Sets the lower bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_setRangeLowerBound(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension theBound");
        return TCL_ERROR;
    }

    long theExtent, theDimension, theBound;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[4], &theBound) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    /* Now attempt to set the bound */
    try 
    {
        region->setRangeLowerBound(theExtent, theDimension, theBound);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region setRangeUpperBound theExtent theDimension theBound
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *       theBound      Value of the upper bound to set
 *
 * RETURNS:
 *       nothing
 *
 * DESCRIPTION:
 *       Sets the upper bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_setRangeUpperBound(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension theBound");
        return TCL_ERROR;
    }

    long theExtent, theDimension, theBound;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[4], &theBound) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    /* Now attempt to set the bound */
    try 
    {
        region->setRangeUpperBound(theExtent, theDimension, theBound);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getSpaceHandle
 *
 * INPUTS:
 *      none
 *
 * RETURNS:
 *      The handle of the routing space
 *
 * DESCRIPTION:
 *	Returns the handle to the routing space of which the region
 *      is a subset.
 */

static int 
rtiRegion_getSpaceHandle(ClientData cd, Tcl_Interp *interp, 
                      int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, NULL);
        return TCL_ERROR;
    }

    RTI::SpaceHandle h;

    try 
    {
        h = region->getSpaceHandle();
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getNumberOfExtents
 *
 * INPUTS:
 *      none
 *
 * RETURNS:
 *      The number of extents
 *
 * DESCRIPTION:
 *	Returns the number of extents used to describe the region.
 */

static int 
rtiRegion_getNumberOfExtents (ClientData cd, Tcl_Interp *interp, 
                              int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, NULL);
        return TCL_ERROR;
    }

    RTI::ULong extents;

    try 
    {
        extents = region->getNumberOfExtents();
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, extents);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getRangeLowerBoundNotificationLimit theExtent theDimension
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *
 * RETURNS:
 *       The lower bound of the specified dimension
 *
 * DESCRIPTION:
 *       Queries the lower bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_getRangeLowerBoundNotificationLimit(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension");
        return TCL_ERROR;
    }

    long theExtent, theDimension;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }


    RTI::ULong bound;

    /* Determine the bound */
    try 
    {
        bound = region->getRangeLowerBoundNotificationLimit(theExtent, 
                                                            theDimension);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, bound);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$region getRangeUpperBoundNotificationLimit theExtent theDimension
 *
 * INPUTS:
 *       theExtent     Index of the extent
 *       theDimension  Handle of the dimension
 *
 * RETURNS:
 *       The upper bound of the specified dimension
 *
 * DESCRIPTION:
 *       Queries the upper bound in the specified dimension of the 
 *       subspace described by the specified extent.
 */

static int 
rtiRegion_getRangeUpperBoundNotificationLimit(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RTI::Region* region = (RTI::Region*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theExtent theDimension");
        return TCL_ERROR;
    }

    long theExtent, theDimension;

    /* Get the extent and dimension arguments */
    if (Tcl_GetLongFromObj(interp, objv[2], &theExtent) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[3], &theDimension) != TCL_OK) 
    {
        return TCL_ERROR;
    }


    RTI::ULong bound;

    /* Determine the bound */
    try 
    {
        bound = region->getRangeUpperBoundNotificationLimit(theExtent, 
                                                            theDimension);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    Tcl_SetWideIntObj(result, bound);

    return TCL_OK;
}

/*
 * Utility Routines
 */

/***********************************************************************
 *
 * FUNCTION:
 *	throwTclError()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *	e               An RTI exception
 *
 * RETURNS:
 *	TCL_ERROR
 *
 * DESCRIPTION:
 *	Converts the RTI exception into a Tcl error return.
 *      The exception name is copied to the errorCode, to ease
 *      exception processing.
 */

static int
throwTclError(Tcl_Interp* interp, RTI::Exception& e)
{
    ostringstream err;

    err << &e;

    Tcl_SetResult(interp, (char*)err.str().c_str(), TCL_VOLATILE);
    Tcl_SetErrorCode(interp, e._name, NULL);

    return TCL_ERROR;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getRegionFromObj()
 *
 * INPUTS:
 *	interp		Tcl interpreter
 *	objPtr          The Tcl object value
 *
 * OUTPUTS:
 *	pR		The region pointer buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure.
 *
 * DESCRIPTION:
 *	Attempts to read an RTI::Region* from the object.
 */

static int
getRegionFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, RTI::Region** pR)
{
    long int li = 0;

    /* FIRST, get the region address value as a long */
    if (Tcl_GetLongFromObj(interp, objPtr, &li) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    /* NEXT, make sure the passed address is non-null */
    assert (li != 0);

    *pR = (RTI::Region*) li;

    return TCL_OK;
}

