/***********************************************************************
 *
 * TITLE:
 *	rti.cpp
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	JNEM: rti(n) RTI Binding.
 *
 *      This module defines the set of Tcl commands that comprise the
 *      RTI binding.  fed_amb.cpp defines the FederateAmbassador code
 *      that links FederateAmbassador callbacks to a Tcl 
 *      FederateAmbassador object.
 *
 ***********************************************************************/

#include "tcl_rti.h"
#include <assert.h>

/*
 * Data Types
 */

/* RTIambassador instance info structure */
struct RtiAmbInfo {
    RTI::RTIambassador rtiAmb;       /* The RTIambassador */
    FedAmb fedAmb;                   /* The FederateAmbassador */
    Tcl_HashTable* regionHash;       /* Hash table of all RTI::Region* */
};

/* 
 * Command Prototypes 
 */

/* Tcl Commands */

static int rti_RTIambassadorCmd              (ClientData, Tcl_Interp*, 
                                              int, Tcl_Obj* CONST argv[]);

/* RTIambassador instance definition */

static void rtiAmb_delete                    (void*);
static int  rtiAmb_instanceCmd               (ClientData, Tcl_Interp*, 
                                              int, Tcl_Obj* CONST argv[]);

/* RTIambassador Subcommands: Federation Management */

static int rtiAmb_createFederationExecution      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_destroyFederationExecution     (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_federateRestoreComplete        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_federateRestoreNotComplete     (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_federateSaveBegun              (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_federateSaveComplete           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_federateSaveNotComplete        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_joinFederationExecution        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_registerFederationSynchronizationPoint
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_requestFederationRestore       (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_requestFederationSave          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_resignFederationExecution      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_synchronizationPointAchieved   (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);


/* RTIambassador Subcommands: Declaration Management */

static int rtiAmb_publishInteractionClass        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_publishObjectClass             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_subscribeInteractionClass      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_subscribeObjectClassAttributes (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unpublishInteractionClass      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unpublishObjectClass           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unsubscribeInteractionClass    (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unsubscribeObjectClass         (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);


/* RTIambassador subcommands: Object Management */


static int rtiAmb_deleteObjectInstance           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_localDeleteObjectInstance      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_registerObjectInstance         (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_requestClassAttributeValueUpdate 
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_sendInteraction                (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_updateAttributeValues          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

/* RTIambassador subcommands: Ownership Management */

static int rtiAmb_attributeOwnershipAcquisition  (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_attributeOwnershipAcquisitionIfAvailable
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_cancelAttributeOwnershipAcquisition  
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_isAttributeOwnedByFederate     (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);


/* RTIambassador subcommands: Time Management */

static int rtiAmb_disableTimeConstrained         (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_disableTimeRegulation          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_enableTimeConstrained          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_enableTimeRegulation           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_timeAdvanceRequest             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_queryLBTS                      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_queryLookahead                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

/* RTIambassador subcommands: Data Distribution Management */

static int rtiAmb_associateRegionForUpdates      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_createRegion                   (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_deleteRegion                   (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_notifyAboutRegionModification  (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_registerObjectInstanceWithRegion          
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_sendInteractionWithRegion      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_subscribeInteractionClassWithRegion
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_subscribeObjectClassAttributesWithRegion 
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unassociateRegionForUpdates    (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unsubscribeInteractionClassWithRegion
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_unsubscribeObjectClassWithRegion
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

/* RTIambassador subcommands: Ancillary Services */

static int rtiAmb_enableAttributeRelevanceAdvisorySwitch
                                                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getAttributeHandle             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getAttributeName               (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getDimensionHandle             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getDimensionName               (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getInteractionClassHandle      (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getInteractionClassName        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getObjectClass                 (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getObjectClassHandle           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getObjectClassName             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getObjectInstanceHandle        (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getObjectInstanceName          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getParameterHandle             (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getParameterName               (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getRoutingSpaceHandle          (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_getRoutingSpaceName            (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

static int rtiAmb_tick                           (ClientData, Tcl_Interp*, 
                                                  int, Tcl_Obj* CONST argv[]);

/*
 * Static Function Prototypes
 */

static void cleanUpRegions         (Tcl_Interp*, RtiAmbInfo*);

static int  throwTclError          (Tcl_Interp*, RTI::Exception&);
static int  getOClassHandleFromObj (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::ObjectClassHandle*);
static int  getAttrHandleFromObj   (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::ObjectClassHandle,
                                    RTI::AttributeHandle*);

static int  getAttrArrayFromObj    (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::ObjectClassHandle,
                                    RTI::AttributeHandle**);

static int  getAttrSetFromObj      (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::ObjectClassHandle,
                                    RTI::AttributeHandleSet**);

static int  getIClassHandleFromObj (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::InteractionClassHandle*);

static int  getParmHandleFromObj   (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,
                                    RTI::ObjectClassHandle,
                                    RTI::AttributeHandle*);

static int  getSpaceHandleFromObj  (Tcl_Interp*, Tcl_Obj*, RtiAmbInfo*,  
                                    RTI::SpaceHandle*);
static int  getHandleFromObj       (Tcl_Interp*, Tcl_Obj*, RTI::Handle*);
static void setHandleObj           (Tcl_Obj*, RTI::Handle);

static int  getRegionFromObj       (Tcl_Interp*, Tcl_Obj*, 
                                    RtiAmbInfo*, RTI::Region**);
static int  getRegionArrayFromObj  (Tcl_Interp*, Tcl_Obj*, 
                                    RtiAmbInfo*, RTI::Region***);

/*
 * Static Variables
 */

/* RTIambassador dispatch table */

static SubcommandVector rtiAmbSubTable [] = {
    /* Federation Management */
    {"createFederationExecution",     rtiAmb_createFederationExecution},
    {"destroyFederationExecution",    rtiAmb_destroyFederationExecution},
    {"federateRestoreComplete",       rtiAmb_federateRestoreComplete},
    {"federateRestoreNotComplete",    rtiAmb_federateRestoreNotComplete},
    {"federateSaveBegun",             rtiAmb_federateSaveBegun},
    {"federateSaveComplete",          rtiAmb_federateSaveComplete},
    {"federateSaveNotComplete",       rtiAmb_federateSaveNotComplete},
    {"joinFederationExecution",       rtiAmb_joinFederationExecution},
    {"registerFederationSynchronizationPoint",
     rtiAmb_registerFederationSynchronizationPoint},
    {"requestFederationRestore",      rtiAmb_requestFederationRestore},
    {"requestFederationSave",         rtiAmb_requestFederationSave},
    {"resignFederationExecution",     rtiAmb_resignFederationExecution},
    {"synchronizationPointAchieved",  rtiAmb_synchronizationPointAchieved},

    /* Declaration Management */
    {"publishInteractionClass",       rtiAmb_publishInteractionClass},
    {"publishObjectClass",            rtiAmb_publishObjectClass},
    {"subscribeInteractionClass",     rtiAmb_subscribeInteractionClass},
    {"subscribeObjectClassAttributes", 
     rtiAmb_subscribeObjectClassAttributes},
    {"unpublishInteractionClass",     rtiAmb_unpublishInteractionClass},
    {"unpublishObjectClass",          rtiAmb_unpublishObjectClass},
    {"unsubscribeInteractionClass",   rtiAmb_unsubscribeInteractionClass},
    {"unsubscribeObjectClass",        rtiAmb_unsubscribeObjectClass},

    /* Object Management */
    {"deleteObjectInstance",          rtiAmb_deleteObjectInstance},
    {"localDeleteObjectInstance",     rtiAmb_localDeleteObjectInstance},
    {"registerObjectInstance",        rtiAmb_registerObjectInstance},
    {"requestClassAttributeValueUpdate", 
     rtiAmb_requestClassAttributeValueUpdate},
    {"sendInteraction",               rtiAmb_sendInteraction},
    {"updateAttributeValues",         rtiAmb_updateAttributeValues},

    /* Ownership Management */
    {"attributeOwnershipAcquisition", rtiAmb_attributeOwnershipAcquisition},
    {"attributeOwnershipAcquisitionIfAvailable", 
     rtiAmb_attributeOwnershipAcquisitionIfAvailable},
    {"cancelAttributeOwnershipAcquisition", 
     rtiAmb_cancelAttributeOwnershipAcquisition},
    {"isAttributeOwnedByFederate",    rtiAmb_isAttributeOwnedByFederate},

    /* Time Management */
    {"disableTimeConstrained",        rtiAmb_disableTimeConstrained},
    {"disableTimeRegulation",         rtiAmb_disableTimeRegulation},
    {"enableTimeConstrained",         rtiAmb_enableTimeConstrained},
    {"enableTimeRegulation",          rtiAmb_enableTimeRegulation},
    {"timeAdvanceRequest",            rtiAmb_timeAdvanceRequest},
    {"queryLBTS",                     rtiAmb_queryLBTS},
    {"queryLookahead",                rtiAmb_queryLookahead},

    /* Data Distribution Management */
    {"associateRegionForUpdates",     rtiAmb_associateRegionForUpdates},
    {"createRegion",                  rtiAmb_createRegion},
    {"deleteRegion",                  rtiAmb_deleteRegion},
    {"notifyAboutRegionModification", rtiAmb_notifyAboutRegionModification},
    {"registerObjectInstanceWithRegion", 
     rtiAmb_registerObjectInstanceWithRegion},
    {"sendInteractionWithRegion",     rtiAmb_sendInteractionWithRegion},
    {"subscribeInteractionClassWithRegion",     
     rtiAmb_subscribeInteractionClassWithRegion},
    {"subscribeObjectClassAttributesWithRegion", 
     rtiAmb_subscribeObjectClassAttributesWithRegion},
    {"unassociateRegionForUpdates",   rtiAmb_unassociateRegionForUpdates},
    {"unsubscribeInteractionClassWithRegion",   
     rtiAmb_unsubscribeInteractionClassWithRegion},
    {"unsubscribeObjectClassWithRegion",        
     rtiAmb_unsubscribeObjectClassWithRegion},

    /* Ancillary Services */
    {"enableAttributeRelevanceAdvisorySwitch",
     rtiAmb_enableAttributeRelevanceAdvisorySwitch},
    {"getAttributeHandle",            rtiAmb_getAttributeHandle},
    {"getAttributeName",              rtiAmb_getAttributeName},
    {"getDimensionHandle",            rtiAmb_getDimensionHandle},
    {"getDimensionName",              rtiAmb_getDimensionName},
    {"getInteractionClassHandle",     rtiAmb_getInteractionClassHandle},
    {"getInteractionClassName",       rtiAmb_getInteractionClassName},
    {"getObjectClass",                rtiAmb_getObjectClass},
    {"getObjectClassHandle",          rtiAmb_getObjectClassHandle},
    {"getObjectClassName",            rtiAmb_getObjectClassName},
    {"getObjectInstanceHandle",       rtiAmb_getObjectInstanceHandle},
    {"getObjectInstanceName",         rtiAmb_getObjectInstanceName},
    {"getParameterHandle",            rtiAmb_getParameterHandle},
    {"getParameterName",              rtiAmb_getParameterName},
    {"getRoutingSpaceHandle",         rtiAmb_getRoutingSpaceHandle},
    {"getRoutingSpaceName",           rtiAmb_getRoutingSpaceName},
    {"tick",                          rtiAmb_tick},

    {NULL, NULL}
};

/*
 * Package Initialization
 */

/***********************************************************************
 *
 * FUNCTION:
 *	Rti_Init()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *
 * RETURNS:
 *	TCL_OK
 *
 * DESCRIPTION:
 *	Initializes the RTI binding.
 */

int
Rti_Init(Tcl_Interp *interp)
{
    /* Define the commands. */
    Tcl_CreateObjCommand(interp, "::rti::RTIambassador", 
                         rti_RTIambassadorCmd, NULL, NULL);

    /* Provide the package. */
    if (Tcl_PkgProvide(interp, "Rti", "1.0") != TCL_OK)
    {
        return TCL_ERROR;
    }

    return TCL_OK;
}

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
 *	rti_RTIambassadorCmd()
 *
 * INPUTS:
 *	name		The name of the new RTIambassador command
 *
 * RETURNS:
 *	The name
 *
 * DESCRIPTION:
 *	Creates a new RTIambassador object called "name", and returns 
 *      it.
 */

static int 
rti_RTIambassadorCmd(ClientData cd, Tcl_Interp *interp, 
                     int objc, Tcl_Obj* CONST objv[])
{
    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 1, objv, "name");
        return TCL_ERROR;
    }

    char* name = Tcl_GetStringFromObj(objv[1], NULL);

    RtiAmbInfo* rai = new RtiAmbInfo();

    /* Initialize the region hash table */
    rai->regionHash = (Tcl_HashTable*) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(rai->regionHash, TCL_STRING_KEYS);

    Tcl_CreateObjCommand(interp, name, rtiAmb_instanceCmd, rai,
                         rtiAmb_delete);

    Tcl_SetResult(interp, name, TCL_VOLATILE);
    return TCL_OK;
}

/*
 * RTIambassador Instance Functions
 */

/***********************************************************************
 *
 * FUNCTION:
 *	rtiAmb_delete()
 *
 * INPUTS:
 *	amb		An RTI::RTIambassador to delete.
 *
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Deletes an RTIambassador object.
 */

static void
rtiAmb_delete(void* amb)
{
    delete (RtiAmbInfo*)amb;
}

/***********************************************************************
 *
 * FUNCTION:
 *	rtiAmb_instanceCmd()
 *
 * INPUTS:
 *	subcommand		The subcommand name
 *      args                    Subcommand arguments
 *
 * RETURNS:
 *	Whatever the subcommand returns.
 *
 * DESCRIPTION:
 *	This is the instance command for RTIambassador objects created
 *      by rti_RTIambassador.  It looks up the subcommand name, and
 *      then passes execution to the subcommand proc.
 */

static int 
rtiAmb_instanceCmd(ClientData cd, Tcl_Interp* interp, 
                   int objc, Tcl_Obj* CONST objv[])
{
    if (objc < 2) 
    {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg arg ...?");
        return TCL_ERROR;
    } 

    int index = 0;

    if (Tcl_GetIndexFromObjStruct(interp, objv[1], 
                                  rtiAmbSubTable, sizeof(SubcommandVector),
                                  "subcommand",
                                  TCL_EXACT,
                                  &index) != TCL_OK)
    {
        return TCL_ERROR;
    }

    return (*rtiAmbSubTable[index].proc)(cd, interp, objc, objv);
}


/*
 * RTIambassador Subcommand Procedures
 *
 * Most functions in this section are subcommands of the RTIambassador
 * object created by rti_RTIambassador.  As such they have Tcl Object
 * Command calling conventions; consequently, the function header
 * for each will be written in terms of the Tcl command it implements.
 *
 * See the RTI specification for details on what each subcommand actually
 * does; the semantics are intended to be identical, except as noted.
 */

/* Federation Management */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra createFederationExecution executionName FED
 *
 * INPUTS:
 *	executionName       The federation name
 *      FED                 The FED file name
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements  createFederationExecution subcommand.
 */

static int 
rtiAmb_createFederationExecution(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "executionName FED");
        return TCL_ERROR;
    }

    char* executionName = Tcl_GetStringFromObj(objv[2], NULL);
    char* fed = Tcl_GetStringFromObj(objv[3], NULL);

    try 
    {
        rai->rtiAmb.createFederationExecution(executionName, fed);
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
 *	$ra destroyFederationExecution executionName
 *
 * INPUTS:
 *	executionName       The federation name
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements destroyFederationExecution subcommand.
 */


static int 
rtiAmb_destroyFederationExecution(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "executionName");
        return TCL_ERROR;
    }

    char* executionName = Tcl_GetStringFromObj(objv[2], NULL);

    try 
    {
        rai->rtiAmb.destroyFederationExecution(executionName);
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
 *	$ra federateRestoreComplete
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements federateRestoreComplete subcommand.
 */

static int 
rtiAmb_federateRestoreComplete(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.federateRestoreComplete();
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
 *	$ra federateRestoreNotComplete
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements federateRestoreNotComplete subcommand.
 */

static int 
rtiAmb_federateRestoreNotComplete(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.federateRestoreNotComplete();
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
 *	$ra federateSaveBegun
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements federateSaveBegun subcommand.
 */

static int 
rtiAmb_federateSaveBegun(ClientData cd, Tcl_Interp *interp, 
                         int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.federateSaveBegun();
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
 *	$ra federateSaveComplete
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements federateSaveComplete subcommand.
 */

static int 
rtiAmb_federateSaveComplete(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.federateSaveComplete();
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
 *	$ra federateSaveNotComplete
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements federateSaveNotComplete subcommand.
 */

static int 
rtiAmb_federateSaveNotComplete(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.federateSaveNotComplete();
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
 *	$ra joinFederationExecution yourName executionName fedAmbCmd
 *
 * INPUTS:
 *      federateName        The name of this federate
 *	executionName       The federation name
 *      fedAmbCmd           The name of the Tcl FederateAmbassador
 *                          object.
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements joinFederationExecution subcommand.  
 *
 *      A SharkFederateAmbassador object was created along with the
 *      RTIambassador; the caller provides instead the name of a Tcl
 *      command which will receive the FederateAmbassador calls as
 *      subcommands.
 *
 *      TBD: Ideally, the command should be a list to which the
 *      additional arguments are added.
 */

static int 
rtiAmb_joinFederationExecution(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "yourName executionName fedAmbCmd");
        return TCL_ERROR;
    }

    char* yourName      = Tcl_GetStringFromObj(objv[2], NULL);
    char* executionName = Tcl_GetStringFromObj(objv[3], NULL);
    char* fedAmbCmd     = Tcl_GetStringFromObj(objv[4], NULL);

    try 
    {
        rai->rtiAmb.joinFederationExecution(yourName,
                                            executionName, 
                                            &rai->fedAmb);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    rai->fedAmb.setFaName(interp, fedAmbCmd, &rai->rtiAmb);
    rai->fedAmb.clearCache();

    Tcl_InitHashTable(rai->regionHash, TCL_STRING_KEYS);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra registerFederationSynchronizationPoint label ?options...?
 *
 * INPUTS:
 *      label   	The sync point's name
 *      -tag            The "tag" string
 *
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Registers a new synchronization point with the RTI.  The
 *      -tag defaults to "".  
 *
 *      TBD: At some point we might want to support -syncset.
 */

static int 
rtiAmb_registerFederationSynchronizationPoint(ClientData cd, 
                                              Tcl_Interp *interp, 
                                              int objc, Tcl_Obj* CONST objv[])
{
    const char* options[] = {
        "-tag",
        NULL
    };
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "label ?-tag theTag?");
        return TCL_ERROR;
    }

    /* Get label */
    char* label = Tcl_GetStringFromObj(objv[2], NULL);

    /* Process the options */
    char* tag = "";

    for (int i = 3; i < objc; i += 2)
    {
        int index;

        if (Tcl_GetIndexFromObj(interp, objv[i], options, "option",
                                TCL_EXACT, &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (i + 1 >= objc)
        {
            Tcl_SetResult(interp, "Missing option value", TCL_STATIC);

            return TCL_ERROR;
        }

        switch (index) 
        {
        case 0: /* -tag */
            tag = Tcl_GetStringFromObj(objv[i+1], NULL);
            break;
        default:
            Tcl_SetResult(interp, "Software Failure: invalid option index",
                          TCL_STATIC);
            return TCL_ERROR;
        }
    }

    try 
    {
        rai->rtiAmb.registerFederationSynchronizationPoint(label, tag);
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
 *	$ra requestFederationRestore label
 *
 * INPUTS:
 *      label               The name of the checkpoint
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements requestFederationRestore subcommand.  
 */

static int 
rtiAmb_requestFederationRestore(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "label");
        return TCL_ERROR;
    }

    char* label = Tcl_GetStringFromObj(objv[2], NULL);

    try 
    {
        rai->rtiAmb.requestFederationRestore(label);
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
 *	$ra requestFederationSave label ?theTime?
 *
 * INPUTS:
 *      label               The name of the checkpoint
 *      theTime             The time as of which to save
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements requestFederationSave subcommand.  
 */

static int 
rtiAmb_requestFederationSave(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3 && objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "label ?theTime?");
        return TCL_ERROR;
    }

    char* label = Tcl_GetStringFromObj(objv[2], NULL);
   
    bool gotTime = false;
    double t;

    if (objc == 4) {
        if (Tcl_GetDoubleFromObj(interp, objv[3], &t) != TCL_OK)
        {
            return TCL_ERROR;
        }

        gotTime = true;
    }

    try 
    {
        if (gotTime)
        {
            rai->rtiAmb.requestFederationSave(label, RTIfedTime(t));
        }
        else
        {
            rai->rtiAmb.requestFederationSave(label);
        }
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
 *	$ra resignFederationExecution theAction
 *
 * INPUTS:
 *      theAction           Action to take; see array, below.
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements resignFederationExecution subcommand.  
 */

static int 
rtiAmb_resignFederationExecution(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    const char* actions[] = {
        "RELEASE_ATTRIBUTES",
        "DELETE_OBJECTS",
        "DELETE_OBJECTS_AND_RELEASE_ATTRIBUTES",
        "NO_ACTION",
        NULL
    };

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theAction");
        return TCL_ERROR;
    }

    int index = 0;

    if (Tcl_GetIndexFromObj(interp, objv[2], actions, "action",
                            TCL_EXACT, &index) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* The RTI::ResignAction enum begins at 1. */
    RTI::ResignAction theAction = (RTI::ResignAction)(index + 1);
    
    try 
    {
        rai->rtiAmb.resignFederationExecution(theAction);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Clean up all RTI::Region Tcl commands */
    cleanUpRegions(interp, rai);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	cleanUpRegions
 *
 * INPUTS:
 *      rai             RtiAmbInfo, the state for this ambassador
 *
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Deletes all Tcl commands representing RTI::Region objects
 *      and cleans up the regions hash table.  The deletion of the
 *      objects themselves is done by resignFederationExecution().
 *      The hash table will be re-initialized when joining the federation.
 */

static void
cleanUpRegions(Tcl_Interp* interp, RtiAmbInfo* rai)
{
    Tcl_HashEntry*  entryPtr  = NULL; 
    Tcl_HashSearch* searchPtr = (Tcl_HashSearch*) ckalloc(sizeof(Tcl_HashSearch));
    Tcl_CmdInfo*    infoPtr   = (Tcl_CmdInfo*) ckalloc(sizeof(Tcl_CmdInfo));
    char* cmdName;

    entryPtr = Tcl_FirstHashEntry(rai->regionHash, searchPtr);

    while (entryPtr != NULL)
    {
        cmdName = Tcl_GetHashKey(rai->regionHash, entryPtr);

        /* Only delete the command if the user hasn't already done so */
        if (Tcl_GetCommandInfo(interp, cmdName, infoPtr) == 1)
        {
            Tcl_DeleteCommand(interp, cmdName);
        }

        entryPtr = Tcl_NextHashEntry(searchPtr);
    }

    Tcl_DeleteHashTable(rai->regionHash);
    ckfree((char*) searchPtr);
    ckfree((char*) infoPtr);
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra synchronizationPointAchieved label
 *
 * INPUTS:
 *      label   	The sync point's name
 *
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	This federate is saying that it has achieved the synchronization 
 *      point with the RTI.
 */

static int 
rtiAmb_synchronizationPointAchieved(ClientData cd, Tcl_Interp *interp, 
                                    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "label");
        return TCL_ERROR;
    }

    /* Get label */
    char* label = Tcl_GetStringFromObj(objv[2], NULL);

    try 
    {
        rai->rtiAmb.synchronizationPointAchieved(label);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    return TCL_OK;
}

/* Declaration Management */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra publishInteractionClass theClass
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's intent to send interactions of this
 *      class.
 */

static int 
rtiAmb_publishInteractionClass(ClientData cd, Tcl_Interp *interp, 
                               int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle theClass;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        /* Publish the class */
        rai->rtiAmb.publishInteractionClass(theClass);
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
 *	$ra publishObjectClass theClass attributeList
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *      attributeList   A list of attribute names or handles.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's intent to publish objects of this
 *      class.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_publishObjectClass(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass attributeList");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try
    {
        /* Publish the class */
        rai->rtiAmb.publishObjectClass(theClass, *attrs);
    }
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete attrs;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra subscribeInteractionClass theClass
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's desire to receive interactions of this
 *      class.
 */

static int 
rtiAmb_subscribeInteractionClass(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle h;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        rai->rtiAmb.subscribeInteractionClass(h);
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
 *	$ra subscribeObjectClassAttributes theClass attributeList
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *      attributeList   A list of attribute names or handles.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's desire to receive objects of this
 *      class.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_subscribeObjectClassAttributes(ClientData cd, Tcl_Interp *interp, 
                                      int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass attributeList");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try
    {
        rai->rtiAmb.subscribeObjectClassAttributes(theClass, *attrs);
    }
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete attrs;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra unpublishInteractionClass theClass
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's intent to no longer send 
 *	interactions of this class.
 */

static int 
rtiAmb_unpublishInteractionClass(ClientData cd, Tcl_Interp *interp, 
                               int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle theClass;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        rai->rtiAmb.unpublishInteractionClass(theClass);
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
 *	$ra unpublishObjectClass theClass
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's intent to no longer publish objects 
 *      of this class.
 */

static int 
rtiAmb_unpublishObjectClass(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        rai->rtiAmb.unpublishObjectClass(theClass);
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
 *	$ra unsubscribeInteractionClass theClass
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's desire to no longer receive 
 * 	interactions of this class.
 */

static int 
rtiAmb_unsubscribeInteractionClass(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle theClass;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        rai->rtiAmb.unsubscribeInteractionClass(theClass);
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
 *	$ra unsubscribeObjectClass theClass
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's intent to no longer subscribe to 
 * 	objects of this class.
 */

static int 
rtiAmb_unsubscribeObjectClass(ClientData cd, Tcl_Interp *interp, 
                              int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try
    {
        rai->rtiAmb.unsubscribeObjectClass(theClass);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }
    
    return TCL_OK;
}

/* Object Management */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra deleteObjectInstance objectHandle ?options...?
 *
 * INPUTS:
 *      objectHandle	The object handle
 *      -time           The timestamp
 *      -tag            The "tag" string
 *
 * RETURNS:
 *	The object handle
 *
 * DESCRIPTION:
 *	Deletes an object given its handle.
 */

static int 
rtiAmb_deleteObjectInstance(ClientData cd, Tcl_Interp *interp, 
                            int objc, Tcl_Obj* CONST objv[])
{
    const char* options[] = {
        "-time",
        "-tag",
        NULL
    };
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "objectHandle ?-time fedTime? ?-tag theTag?");
        return TCL_ERROR;
    }

    /* Get objectHandle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Process the options */
    char* tag = "";

    bool gotTime = false;
    double t = 0.0;

    for (int i = 3; i < objc; i += 2)
    {
        int index;

        if (Tcl_GetIndexFromObj(interp, objv[i], options, "option",
                                TCL_EXACT, &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (i + 1 >= objc)
        {
            Tcl_SetResult(interp, "Missing option value", TCL_STATIC);

            return TCL_ERROR;
        }

        switch (index) 
        {
        case 0: /* -time */
            if (Tcl_GetDoubleFromObj(interp, objv[i+1], &t) != TCL_OK)
            {
                return TCL_ERROR;
            }
            gotTime = true;

            break;
        case 1: /* -tag */
            tag = Tcl_GetStringFromObj(objv[i+1], NULL);
            break;
        default:
            Tcl_SetResult(interp, "Software Failure: invalid option index",
                          TCL_STATIC);
            return TCL_ERROR;
        }
    }

    try 
    {
        if (gotTime)
        {
            rai->rtiAmb.deleteObjectInstance(h, RTIfedTime(t), tag);
        }
        else
        {
            rai->rtiAmb.deleteObjectInstance(h, tag);
        }
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
 *	$ra localDeleteObjectInstance objectHandle
 *
 * INPUTS:
 *      objectHandle	The object handle
 *
 * RETURNS:
 *      Nothing
 *
 * DESCRIPTION:
 *	Deletes a discovered object given its handle.
 */

static int 
rtiAmb_localDeleteObjectInstance(ClientData cd, Tcl_Interp *interp, 
                            int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "objectHandle");
        return TCL_ERROR;
    }

    /* Get objectHandle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.localDeleteObjectInstance(h);
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
 *	$ra registerObjectInstance theClass ?theObject?
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *      theObject	The object name.
 *
 * RETURNS:
 *	The object handle
 *
 * DESCRIPTION:
 *	Registers a new object with the RTI; if the object name isn't
 *      given, RTI will generate one.
 */

static int 
rtiAmb_registerObjectInstance(ClientData cd, Tcl_Interp *interp, 
                              int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3 && objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass ?theObject?");
        return TCL_ERROR;
    }

    /* Get theClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        RTI::ObjectHandle h;
        char* theName = NULL;

        if (objc == 4) 
        {
            theName = Tcl_GetStringFromObj(objv[3], NULL);

            h = rai->rtiAmb.registerObjectInstance(theClass, theName);
        } 
        else 
        {
            h = rai->rtiAmb.registerObjectInstance(theClass);

            theName = rai->rtiAmb.getObjectInstanceName(h);
            delete[] theName;
        }

        /* TBD: use setHandleResult() for all such */
        Tcl_Obj* result = Tcl_GetObjResult(interp);
        setHandleObj(result, h);
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
 *	$ra requestClassAttributeValueUpdate theClass theAttributes
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *      theAttributes   A list of attribute names or handles.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Requests an update of the specified attributes for all objects
 *      of this class.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_requestClassAttributeValueUpdate(ClientData cd, Tcl_Interp *interp, 
                                        int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass theAttributes");
        return TCL_ERROR;
    }

    /* Get theClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try
    {
        rai->rtiAmb.requestClassAttributeValueUpdate(theClass, *attrs);
    }
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete attrs;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra sendInteraction theInteraction theParameters ?options...?
 *
 * INPUTS:
 *      theInteraction	The interaction handle or name.
 *      theParameters   A dictionary whose keys are parameter names or
 *                      handles and whose values are parameter values.
 *      -time           The timestamp.
 *      -tag            The "tag" string; defaults to ""
 *
 * RETURNS:
 *	If -time is given, returns the EventRetractionHandle; otherwise
 *      returns nothing.
 *
 * DESCRIPTION:
 *	Sends an interaction with the specified parameters.
 */

static int 
rtiAmb_sendInteraction(ClientData cd, Tcl_Interp *interp, 
                       int objc, Tcl_Obj* CONST objv[])
{
    const char* options[] = {
        "-time",
        "-tag",
        NULL
    };
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
              "theInteraction theParameters ?-time fedTime? ?-tag theTag?");
        return TCL_ERROR;
    }

    /* Get the interaction handle */
    RTI::InteractionClassHandle h;

    if (getIClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Process the options */
    char* tag = "";

    bool gotTime = false;
    double t = 0.0;

    for (int i = 4; i < objc; i += 2)
    {
        int index;

        if (Tcl_GetIndexFromObj(interp, objv[i], options, "option",
                                TCL_EXACT, &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (i + 1 >= objc)
        {
            Tcl_SetResult(interp, "Missing option value", TCL_STATIC);

            return TCL_ERROR;
        }

        switch (index) 
        {
        case 0: /* -time */
            if (Tcl_GetDoubleFromObj(interp, objv[i+1], &t) != TCL_OK)
            {
                return TCL_ERROR;
            }
            gotTime = true;

            break;
        case 1: /* -tag */
            tag = Tcl_GetStringFromObj(objv[i+1], NULL);
            break;
        default:
            Tcl_SetResult(interp, "Software Failure: invalid option index",
                          TCL_STATIC);
            return TCL_ERROR;
        }
    }
    
    /* NEXT, get the elements of the parameter/value list. */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objv[3], &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc == 0) 
    {
        Tcl_SetResult(interp, 
                      "theParameters has no elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    if (listc % 2 != 0)
    {
        Tcl_SetResult(interp, 
                      "theParameters must have an even number of elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    /* NEXT, create a set big enough to whole them all. */
    RTI::ParameterHandleValuePairSet* parms = 
        RTI::ParameterSetFactory::create(listc / 2);

    for (int i = 0; i < listc; i += 2)
    {
        RTI::ParameterHandle ph;

        if (getParmHandleFromObj(interp, listv[i], rai, h, &ph) != TCL_OK)
        {
            delete parms;
            return TCL_ERROR;
        }

        int count;
        char* bytes = (char*)Tcl_GetByteArrayFromObj(listv[i+1], &count);

        parms->add(ph, bytes, count);
    }

    /* NEXT, send the interaction. */

    int code = TCL_OK;

    try 
    {
        if (gotTime)
        {
            RTI::EventRetractionHandle erh =
                rai->rtiAmb.sendInteraction(h, *parms, RTIfedTime(t), tag);

            /* Return the erh. */
            Tcl_Obj* result = Tcl_GetObjResult(interp);
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.theSerialNumber));
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.sendingFederate));
        }
        else
        {
            rai->rtiAmb.sendInteraction(h, *parms, tag);
        }
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete parms;

    return code;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra updateAttributeValues theObject theAttributes ?options...?
 *
 * INPUTS:
 *      theObject	The object handle.
 *      theAttributes   A dictionary whose keys are attribute names or
 *                      handles and whose values are attribute values.
 *      -time           The timestamp.
 *      -tag            The "tag" string; defaults to ""
 *
 * RETURNS:
 *	If -time is given, returns the EventRetractionHandle; otherwise
 *      returns nothing.
 *
 * DESCRIPTION:
 *	Updates the specified object attributes.
 */

static int 
rtiAmb_updateAttributeValues(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    const char* options[] = {
        "-time",
        "-tag",
        NULL
    };
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
              "theObject theAttributes ?-time fedTime? ?-tag theTag?");
        return TCL_ERROR;
    }

    /* Get the object handle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the class handle */
    RTI::ObjectClassHandle ch;

    try 
    {
        ch = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Process the options. */
    /* TBD: this could be shared with other commands. */
    char* tag = "";

    bool gotTime = false;
    double t = 0.0;

    for (int i = 4; i < objc; i += 2)
    {
        int index;

        if (Tcl_GetIndexFromObj(interp, objv[i], options, "option",
                                TCL_EXACT, &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (i + 1 >= objc)
        {
            Tcl_SetResult(interp, "Missing option value", TCL_STATIC);

            return TCL_ERROR;
        }

        switch (index) 
        {
        case 0: /* -time */
            if (Tcl_GetDoubleFromObj(interp, objv[i+1], &t) != TCL_OK)
            {
                return TCL_ERROR;
            }
            gotTime = true;

            break;
        case 1: /* -tag */
            tag = Tcl_GetStringFromObj(objv[i+1], NULL);
            break;
        default:
            Tcl_SetResult(interp, "Software Failure: invalid option index",
                          TCL_STATIC);
            return TCL_ERROR;
        }
    }

    /* NEXT, get the elements of the attribute/value list. */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objv[3], &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc == 0) 
    {
        Tcl_SetResult(interp, 
                      "theAttributes has no elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    if (listc % 2 != 0)
    {
        Tcl_SetResult(interp, 
                      "theAttributes must have an even number of elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    /* NEXT, create a set big enough to whole them all. */
    RTI::AttributeHandleValuePairSet* attrs = 
        RTI::AttributeSetFactory::create(listc / 2);

    for (int i = 0; i < listc; i += 2)
    {
        RTI::AttributeHandle ah;

        if (getAttrHandleFromObj(interp, listv[i], rai, ch, &ah) != TCL_OK)
        {
            delete attrs;
            return TCL_ERROR;
        }

        int count;
        char* bytes = (char*)Tcl_GetByteArrayFromObj(listv[i+1], &count);

        attrs->add(ah, bytes, count);
    }

    /* NEXT, update the attributes. */

    int code = TCL_OK;

    try 
    {
        if (gotTime)
        {
            RTI::EventRetractionHandle erh =
                rai->rtiAmb.updateAttributeValues(h, *attrs, 
                                                  RTIfedTime(t), tag);

            /* Return the erh. */
            Tcl_Obj* result = Tcl_GetObjResult(interp);
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.theSerialNumber));
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.sendingFederate));
        }
        else
        {
            rai->rtiAmb.updateAttributeValues(h, *attrs, tag);
        }
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete attrs;

    return code;
}

/* Ownership Management Services */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra attributeOwnershipAcquisition theObject desiredAttributes \
 *           ?theTag?
 *
 * INPUTS:
 *	theObject		An object instance handle
 *      desiredAttributes	A list of attribute names or handles.
 *      theTag                  The "tag" string; defaults to ""
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Requests ownership of the specified attributes for this object.
 *      of this class from the owning federate.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_attributeOwnershipAcquisition(ClientData cd, Tcl_Interp *interp, 
                                     int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 4 || objc > 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
                         "theObject desiredAttributes ?theTag?");
        return TCL_ERROR;
    }

    /* Get the object handle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the object's class */
    RTI::ObjectClassHandle theClass;

    try 
    {
        theClass = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the tag. */
    char* tag = "";

    if (objc == 5) 
    {
        tag = Tcl_GetStringFromObj(objv[4], NULL);
    }

    /* NEXT, request ownership of the attributes. */

    int code = TCL_OK;

    try 
    {
        rai->rtiAmb.attributeOwnershipAcquisition(h, *attrs, tag);
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete attrs;

    return code;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra attributeOwnershipAcquisitionIfAvailable theObject \
 *           desiredAttributes
 *
 * INPUTS:
 *	theObject		An object instance handle
 *      desiredAttributes	A list of attribute names or handles.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Requests ownership of the specified attributes for this object.
 *      of this class, if they are currently unowned.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_attributeOwnershipAcquisitionIfAvailable(ClientData cd, 
                                                Tcl_Interp *interp, 
                                                int objc, 
                                                Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theObject desiredAttributes");
        return TCL_ERROR;
    }

    /* Get the object handle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the object's class */
    RTI::ObjectClassHandle theClass;

    try 
    {
        theClass = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, request ownership of the attributes. */

    int code = TCL_OK;

    try 
    {
        rai->rtiAmb.attributeOwnershipAcquisitionIfAvailable(h, *attrs);
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete attrs;

    return code;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra cancelAttributeOwnershipAcquisition theObject theAttributes
 *
 * INPUTS:
 *	theObject	An object instance handle
 *      theAttributes	A list of attribute names or handles.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Cancels a request for ownership of the specified attributes 
 *      for this object.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_cancelAttributeOwnershipAcquisition(ClientData cd, Tcl_Interp *interp, 
                                           int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theObject theAttributes");
        return TCL_ERROR;
    }

    /* Get the object handle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the object's class */
    RTI::ObjectClassHandle theClass;

    try 
    {
        theClass = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[3], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, request ownership of the attributes. */

    int code = TCL_OK;

    try 
    {
        rai->rtiAmb.cancelAttributeOwnershipAcquisition(h, *attrs);
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete attrs;

    return code;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra isAttributeOwnedByFederate theObject theAttribute
 *
 * INPUTS:
 *	theObject	An object instance handle
 *      theAttribute	An attribute name or handle.
 *
 * RETURNS:
 *	1 if the attribute is owned by this federate, and 0 otherwise.
 *
 * DESCRIPTION:
 *	Queries whether this federate owns theAttribute of theObject.
 *
 *      The C++ method expects an AttributeHandle.  This command
 *      will also accept an attribute name, which is converted
 *      into an AttributeHandle.
 */

static int 
rtiAmb_isAttributeOwnedByFederate(ClientData cd, Tcl_Interp *interp, 
                                  int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theObject theAttribute");
        return TCL_ERROR;
    }

    /* Get the object handle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get theClass */
    RTI::ObjectClassHandle theClass;

    try 
    {
        theClass = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Get theHandle */
    RTI::AttributeHandle theAttribute;

    if (getAttrHandleFromObj(interp, objv[3], rai, theClass, 
                             &theAttribute) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Do we own it? */
    RTI::Boolean flag;

    try
    {
        flag = rai->rtiAmb.isAttributeOwnedByFederate(h, theAttribute);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Return the flag. */
    Tcl_Obj* result = Tcl_GetObjResult(interp);

    if (flag) 
    {
        Tcl_SetIntObj(result, 1);
    }
    else
    {
        Tcl_SetIntObj(result, 0);
    }

    return TCL_OK;
}


/* Time Management Services */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra disableTimeConstrained
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Disables the switch
 */

static int 
rtiAmb_disableTimeConstrained(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.disableTimeConstrained();
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
 *	$ra disableTimeRegulation
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Disables the switch
 */

static int 
rtiAmb_disableTimeRegulation(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.disableTimeRegulation();
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
 *	$ra enableTimeConstrained
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Enables the switch
 */

static int 
rtiAmb_enableTimeConstrained(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.enableTimeConstrained();
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
 *	$ra enableTimeRegulation theFederateTime theLookahead
 *
 * INPUTS:
 *	theFederateTime		The federate's current time
 *      theLookahead            The federate's lookahead.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Enables time regulation for this federate; both arguments
 *      are doubles.
 */

static int 
rtiAmb_enableTimeRegulation(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theFederateTime theLookahead");
        return TCL_ERROR;
    }

    /* theFederateTime */
    double fedTime;

    if (Tcl_GetDoubleFromObj(interp, objv[2], &fedTime) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* theLookahead */
    double lookahead;

    if (Tcl_GetDoubleFromObj(interp, objv[3], &lookahead) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.enableTimeRegulation(RTIfedTime(fedTime),
                                         RTIfedTime(lookahead));
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
 *	$ra timeAdvanceRequest theTime
 *
 * INPUTS:
 *	theTime		The time to advance to
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Requests a time advance to the theTime.
 */

static int 
rtiAmb_timeAdvanceRequest(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 3, objv, "theTime");
        return TCL_ERROR;
    }

    /* theFederateTime */
    double fedTime;

    if (Tcl_GetDoubleFromObj(interp, objv[2], &fedTime) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.timeAdvanceRequest(RTIfedTime(fedTime));
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
 *	$ra queryLBTS
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	The LBTS (a double value)
 *
 * DESCRIPTION:
 *	Returns the current LBTS time value.
 *
 *      The RTI spec has this method updating a variable passed in
 *      by reference; simply returning the value is more general.
 */

static int 
rtiAmb_queryLBTS(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        RTIfedTime lbts(0.0);

        rai->rtiAmb.queryLBTS(lbts);
        
        Tcl_Obj* result = Tcl_GetObjResult(interp);
        Tcl_SetDoubleObj(result, lbts.getTime());

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
 *	$ra queryLookahead
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	The lookahead (a double value)
 *
 * DESCRIPTION:
 *	Returns the current lookahead value.
 *
 *      The RTI spec has this method updating a variable passed in
 *      by reference; simply returning the value is more general.
 */

static int 
rtiAmb_queryLookahead(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        RTIfedTime lookahead(0.0);

        rai->rtiAmb.queryLookahead(lookahead);
        
        Tcl_Obj* result = Tcl_GetObjResult(interp);
        Tcl_SetDoubleObj(result, lookahead.getTime());

    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    return TCL_OK;
}

/* Data Distribution Management (DDM) */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra associateRegionForUpdates theRegion theObject theAttributes
 *
 * INPUTS:
 *      theRegion         A the Tcl name of the region to associate
 *	theObject         Handle of the object instance
 *      theAttributes     A list of attribute names or handles.
 * 
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Associates attributes of a given object to a specific region.
 *
 */

static int 
rtiAmb_associateRegionForUpdates(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theRegion theObject theAttributes");
        return TCL_ERROR;
    }

    /* Get theRegion */
    RTI::Region* theRegion = 0;

    if (getRegionFromObj(interp, objv[2], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get objectHandle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[3], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the object's class */
    RTI::ObjectClassHandle theClass;

    try 
    {
        theClass = rai->rtiAmb.getObjectClass(h);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Get the attribute list. */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[4], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try
    {
        /* Associate object with the region*/
        rai->rtiAmb.associateRegionForUpdates(*theRegion, h, *attrs);
    }
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete attrs;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra createRegion theSpace numberOfExtents
 *
 * INPUTS:
 *	theSpace              Routing space handle or name
 *      numberOfExtents       Number of extents to define region with
 * 
 * RETURNS:
 *	A pointer to the new region
 *
 * DESCRIPTION:
 *	Creates a DDM region.
 */

static int 
rtiAmb_createRegion(ClientData cd, Tcl_Interp *interp, 
                    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theSpace numberOfExtents");
        return TCL_ERROR;
    }
    
    /* Get the handle */
    RTI::SpaceHandle theSpace;

    if (getSpaceHandleFromObj(interp, objv[2], rai, &theSpace) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the number of extents to define this region */
    long numberOfExtents;
    
    if (Tcl_GetLongFromObj(interp, objv[3], &numberOfExtents) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    try 
    {
        static int regionNum = 0;
        RTI::Region* region = NULL;
        char  nameStr[32];
        Tcl_HashEntry* entryPtr = NULL;
        Tcl_CmdInfo*    infoPtr = (Tcl_CmdInfo*) ckalloc(sizeof(Tcl_CmdInfo));
        int newInt;

        region = rai->rtiAmb.createRegion(theSpace, numberOfExtents);

        /* Ensure a unique name is created for the region */
        do
        {
            sprintf(nameStr, "::RTI::region%d", ++regionNum);
        }
        while (Tcl_GetCommandInfo(interp, nameStr, infoPtr) != 0);

        /* Hash the new region */
        entryPtr = Tcl_CreateHashEntry(rai->regionHash, nameStr, &newInt);
        Tcl_SetHashValue(entryPtr, region);
        
        /* Create a new Tcl object command for the user and return it */
        Tcl_CreateObjCommand(interp, nameStr, rtiRegion_instanceCmd, 
                             region, NULL);

        Tcl_SetResult(interp, nameStr, TCL_VOLATILE);

        ckfree((char*) infoPtr);
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
 *	$ra deleteRegion theRegion
 *
 * INPUTS:
 *	theRegion       The Tcl name of the region to delete
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Removes the DDM region specified as well as all references to it.
 */

static int 
rtiAmb_deleteRegion(ClientData cd, Tcl_Interp *interp, 
                    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theRegion");
        return TCL_ERROR;
    }

    /* Get theRegion */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[2], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Attempt to delete the region */
    try 
    {
        rai->rtiAmb.deleteRegion(theRegion);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    /* Remove it's entry in the hash table */
    Tcl_HashEntry* entryPtr = NULL;
    char* cmdName = Tcl_GetString(objv[2]);

    if ((entryPtr = Tcl_FindHashEntry(rai->regionHash, cmdName)) != NULL)
    {
        Tcl_DeleteHashEntry(entryPtr);
    }

    Tcl_CmdInfo* infoPtr = (Tcl_CmdInfo*) ckalloc(sizeof(Tcl_CmdInfo));

    /* Delete the Tcl command */
    if (Tcl_GetCommandInfo(interp, cmdName, infoPtr) == 1)
    {
        Tcl_DeleteCommand(interp, cmdName);
    }

    ckfree((char*) infoPtr);
    
    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra notifyAboutRegionModification theRegion
 *
 * INPUTS:
 *	theRegion       The Tcl name of the region that was modified
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Commits changes made to a region object by notifying the LRC.
 */

static int 
rtiAmb_notifyAboutRegionModification(ClientData cd, Tcl_Interp *interp, 
                                     int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theRegion");
        return TCL_ERROR;
    }

    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[2], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Notify about region change and return */
    try 
    {
        rai->rtiAmb.notifyAboutRegionModification(*theRegion);
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
 *	$ra registerObjectInstanceWithRegion theClass ?theObject?
 *                           theAttributes theRegions theNumberOfHandles
 *
 * INPUTS:
 *	theClass	   An object class name or handle
 *      theObject	   The object name.
 *      theAttributes      Array of attribute names
 *      theRegions         Array of regions to associate with the attributes
 *      theNumberOfHandles Number of items in the attr. & region arrays
 *
 * RETURNS:
 *	The object handle
 *
 * DESCRIPTION:
 *	Registers a new object with the RTI; if the object name isn't
 *      given, RTI will generate one.  Simultaneously with registration,
 *      the object's attributes will be associated with the DDM regions
 *      as specified.
 */

static int 
rtiAmb_registerObjectInstanceWithRegion(ClientData cd, Tcl_Interp *interp, 
                                        int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 6 && objc != 7) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
        "theClass ?theObject? theAttributes theRegions theNumberOfHandles");
        return TCL_ERROR;
    }

    /* Get theClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the object name if present */
    int   gotName = 0;
    char* theName = NULL;

    if (objc == 7)
    {
        theName = Tcl_GetStringFromObj(objv[3], NULL);
        gotName = 1;
    }

    /* Get the number of attribute-region pairs */
    long int numHandles = 0;

    if (Tcl_GetLongFromObj(interp, objv[5+gotName], &numHandles) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    /* Create an array of attribute handles */
    RTI::AttributeHandle *attrs = NULL;

    if (getAttrArrayFromObj(interp, objv[3+gotName], rai, theClass, &attrs) 
        != TCL_OK) 
    {
        return TCL_ERROR;
    }
    
    /* Create an array of regions */
    RTI::Region **regions = NULL;

    if (getRegionArrayFromObj(interp, objv[4+gotName], rai, &regions) 
        != TCL_OK) 
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try 
    {
        RTI::ObjectHandle h;

        if (gotName) 
        {
            h = rai->rtiAmb.registerObjectInstanceWithRegion(theClass, 
                                                             theName,
                                                             attrs,
                                                             regions,
                                                             numHandles);
        } 
        else 
        {
            h = rai->rtiAmb.registerObjectInstanceWithRegion(theClass,
                                                             attrs,
                                                             regions,
                                                             numHandles);
            
            theName = rai->rtiAmb.getObjectInstanceName(h);
            delete[] theName;
        }

        /* TBD: use setHandleResult() for all such */
        Tcl_Obj* result = Tcl_GetObjResult(interp);
        setHandleObj(result, h);
    } 
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete[] attrs;
    delete[] regions;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra sendInteractionWithRegion theInteraction theParameters \
 *                                    theRegion ?options...?
 *
 * INPUTS:
 *      theInteraction	The interaction handle or name.
 *      theParameters   A dictionary whose keys are parameter names or
 *                      handles and whose values are parameter values.
 *      theRegion       Region of relevance.
 *      -time           The timestamp.
 *      -tag            The "tag" string; defaults to ""
 *
 * RETURNS:
 *	If -time is given, returns the EventRetractionHandle; otherwise
 *      returns nothing.
 *
 * DESCRIPTION:
 *	Sends an interaction with the specified parameters associated with
 *      a particular region.
 */

static int 
rtiAmb_sendInteractionWithRegion(
    ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj* CONST objv[])
{
    // JLS: Much of this is common with rtiAmb_sendInteraction
    // Consider a sub-function helper

    const char* options[] = {
        "-time",
        "-tag",
        NULL
    };
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc < 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, 
       "theInteraction theParameters theRegion ?-time fedTime? ?-tag theTag?");
        return TCL_ERROR;
    }

    /* Get the interaction handle */
    RTI::InteractionClassHandle h;

    if (getIClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Process the options */
    char* tag = "";

    bool gotTime = false;
    double t = 0.0;

    for (int i = 5; i < objc; i += 2)
    {
        int index;

        if (Tcl_GetIndexFromObj(interp, objv[i], options, "option",
                                TCL_EXACT, &index) != TCL_OK)
        {
            return TCL_ERROR;
        }

        if (i + 1 >= objc)
        {
            Tcl_SetResult(interp, "Missing option value", TCL_STATIC);

            return TCL_ERROR;
        }

        switch (index) 
        {
        case 0: /* -time */
            if (Tcl_GetDoubleFromObj(interp, objv[i+1], &t) != TCL_OK)
            {
                return TCL_ERROR;
            }
            gotTime = true;

            break;
        case 1: /* -tag */
            tag = Tcl_GetStringFromObj(objv[i+1], NULL);
            break;
        default:
            Tcl_SetResult(interp, "Software Failure: invalid option index",
                          TCL_STATIC);
            return TCL_ERROR;
        }
    }
    
    /* NEXT, get the elements of the parameter/value list. */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objv[3], &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    if (listc == 0) 
    {
        Tcl_SetResult(interp, 
                      "theParameters has no elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    if (listc % 2 != 0)
    {
        Tcl_SetResult(interp, 
                      "theParameters must have an even number of elements.",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    /* NEXT, create a set big enough to hold them all. */
    RTI::ParameterHandleValuePairSet* parms = 
        RTI::ParameterSetFactory::create(listc / 2);

    for (int i = 0; i < listc; i += 2)
    {
        RTI::ParameterHandle ph;

        if (getParmHandleFromObj(interp, listv[i], rai, h, &ph) != TCL_OK)
        {
            delete parms;
            return TCL_ERROR;
        }

        int count;
        char* bytes = (char*)Tcl_GetByteArrayFromObj(listv[i+1], &count);

        parms->add(ph, bytes, count);
    }

    /* NEXT, get the region */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[4], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, send the interaction. */

    int code = TCL_OK;

    try 
    {
        if (gotTime)
        {
            RTI::EventRetractionHandle erh =
                rai->rtiAmb.sendInteractionWithRegion(h, *parms, 
                                                      RTIfedTime(t), tag,
                                                      *theRegion);

            /* Return the erh. */
            Tcl_Obj* result = Tcl_GetObjResult(interp);
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.theSerialNumber));
            Tcl_ListObjAppendElement(interp, result,
                                     Tcl_NewWideIntObj(erh.sendingFederate));
        }
        else
        {
            rai->rtiAmb.sendInteractionWithRegion(h, *parms, tag, *theRegion);
        }
    }
    catch (RTI::Exception& e)
    {
        code = throwTclError(interp, e);
    }

    delete parms;

    return code;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra subscribeInteractionClassWithRegion theClass theRegion
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *	theRegion       The Tcl name of the region
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's desire to receive interactions of this
 *      class in the specified region.
 */

static int 
rtiAmb_subscribeInteractionClassWithRegion(
    ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass theRegion");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle h;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, get the region */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[3], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, attempt the subscription */
    try
    {
        rai->rtiAmb.subscribeInteractionClassWithRegion(h, *theRegion);
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
 *	$ra subscribeObjectClassAttributesWithRegion \
 *                                     theClass theRegion attributeList
 *
 * INPUTS:
 *	theClass	An object class name or handle
 *      theRegion       The Tcl name of the region of interest
 *      attributeList   A list of attribute names or handles.
 *	
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Declares the application's desire to receive objects of this
 *      class in the specified region.
 *
 *      The C++ method expects an AttributeHandleSet.  This command
 *      expects a list of attribute names or handles, which is converted
 *      into an AttributeHandleSet.
 */

static int 
rtiAmb_subscribeObjectClassAttributesWithRegion(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 5) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass theRegion attributeList");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the region */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[3], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the set of attributes */
    RTI::AttributeHandleSet* attrs = 0;

    if (getAttrSetFromObj(interp, objv[4], rai, theClass, &attrs) != TCL_OK)
    {
        return TCL_ERROR;
    }

    int returnCode = TCL_OK;

    try
    {
        rai->rtiAmb.subscribeObjectClassAttributesWithRegion(theClass, 
                                                             *theRegion,
                                                             *attrs);
    }
    catch (RTI::Exception& e)
    {
        returnCode = throwTclError(interp, e);
    }

    delete attrs;

    return returnCode;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra unassociateRegionForUpdates theRegion theObject
 *
 * INPUTS:
 *      theRegion         The Tcl name of the region to associate
 *	theObject         Handle of the object instance
 * 
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Removes the association between theRegion and any attributes of
 *      theObject that have been associated with the region.  The
 *      affected attributes revert to the default region.
 */

static int 
rtiAmb_unassociateRegionForUpdates(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theRegion theObject");
        return TCL_ERROR;
    }

    /* Get theRegion */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[2], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get objectHandle */
    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[3], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Cancel association of object attributes within the region*/
    try
    {
        rai->rtiAmb.unassociateRegionForUpdates(*theRegion, h);
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
 *	$ra unsubscribeInteractionClassWithRegion theClass theRegion
 *
 * INPUTS:
 *	theClass	An interaction class name or handle
 *	theRegion       The Tcl name of the region
 *	
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Withdraws the application's interest in receiving interactions
 *      of the specified type in the specified region.
 */

static int 
rtiAmb_unsubscribeInteractionClassWithRegion(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass theRegion");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle theClass;
    
    if (getIClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, get the region */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[3], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, attempt to cancel the subscription */
    try
    {
        rai->rtiAmb.unsubscribeInteractionClassWithRegion(theClass,*theRegion);
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
 *	$ra unsubscribeObjectClassWithRegion theClass theRegion
 * 
 * INPUTS:
 *	theClass	An object class name or handle
 *      theRegion       The Tcl name of the region
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Withdraws the application's interest in receiving objects
 *      of the specified type in the specified region.	
 */

static int 
rtiAmb_unsubscribeObjectClassWithRegion(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theClass theRegion");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle theClass;
    
    if (getOClassHandleFromObj(interp, objv[2], rai, &theClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the region */
    RTI::Region* theRegion = NULL;

    if (getRegionFromObj(interp, objv[3], rai, &theRegion) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, attempt to cancel the subscription */
    try
    {
        rai->rtiAmb.unsubscribeObjectClassWithRegion(theClass, *theRegion);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    return TCL_OK;
}

/* Ancillary Services */

/***********************************************************************
 *
 * FUNCTION:
 *	$ra enableAttributeRelevancyAdvisorySwitch
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Enables the switch
 */

static int 
rtiAmb_enableAttributeRelevanceAdvisorySwitch(
    ClientData cd, Tcl_Interp *interp, 
    int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }

    try 
    {
        rai->rtiAmb.enableAttributeRelevanceAdvisorySwitch();
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
 *	$ra getAttributeHandle theName whichClass
 *
 * INPUTS:
 *	theName		An attribute name or handle
 *      whichClass      An object class name or handle
 *
 * RETURNS:
 *	The attribute handle
 *
 * DESCRIPTION:
 *	Returns an object attribute handle given its name.
 */

static int 
rtiAmb_getAttributeHandle(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName whichClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle whichClass;
    
    if (getOClassHandleFromObj(interp, objv[3], rai, &whichClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the handle */

    RTI::AttributeHandle h;

    if (getAttrHandleFromObj(interp, objv[2], rai, whichClass, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getAttributeName theHandle whichClass
 *
 * INPUTS:
 *	theHandle	The attribute handle
 *      whichClass      The object class handle
 *
 * RETURNS:
 *	The attribute name
 *
 * DESCRIPTION:
 *	Returns an attribute's name given its handle.
 */

static int 
rtiAmb_getAttributeName(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle whichClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::ObjectClassHandle whichClass;
    
    if (getOClassHandleFromObj(interp, objv[3], rai, &whichClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get theHandle */
    RTI::AttributeHandle h;

    if (getAttrHandleFromObj(interp, objv[2], rai, whichClass, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        char* name =
            rai->rtiAmb.getAttributeName(h, whichClass);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getDimensionHandle theName whichSpace
 *
 * INPUTS:
 *	theName		A DDM routing space dimension name
 *      whichSpace      A DDM routing space handle or name
 *
 * RETURNS:
 *	The dimension handle
 *
 * DESCRIPTION:
 *	Returns a dimension's handle given its name.
 */

static int 
rtiAmb_getDimensionHandle(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName whichSpace");
        return TCL_ERROR;
    }

    /* Get whichSpace */
    RTI::SpaceHandle whichSpace;
    
    if (getSpaceHandleFromObj(interp, objv[3], rai, &whichSpace) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get theHandle */
    RTI::DimensionHandle h;
    char* theName = Tcl_GetStringFromObj(objv[2], NULL);

    try
    {
        h = rai->rtiAmb.getDimensionHandle(theName, whichSpace);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getDimensionName theHandle whichSpace
 *
 * INPUTS:
 *	theHandle	A DDM routing space dimension handle
 *      whichSpace      A DDM routing space handle or name
 *
 * RETURNS:
 *	The dimension name
 *
 * DESCRIPTION:
 *	Returns a dimension's name given its handle.
 */

static int 
rtiAmb_getDimensionName(ClientData cd, Tcl_Interp *interp, 
                        int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle whichSpace");
        return TCL_ERROR;
    }

    /* Get whichSpace */
    RTI::SpaceHandle whichSpace;
    
    if (getSpaceHandleFromObj(interp, objv[3], rai, &whichSpace) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get theHandle */
    RTI::Handle theHandle;

    if (getHandleFromObj(interp, objv[2], &theHandle) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        char* name =
            rai->rtiAmb.getDimensionName(theHandle, whichSpace);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getInteractionClassHandle theName
 *
 * INPUTS:
 *	theName		An interaction class name or handle
 *
 * RETURNS:
 *	The class handle
 *
 * DESCRIPTION:
 *	Returns an interaction class's handle given its name or handle.
 *      If the input is a handle, it is returned unchanged; it is
 *      *not* validated.
 */

static int 
rtiAmb_getInteractionClassHandle(ClientData cd, Tcl_Interp *interp, 
                                 int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName");
        return TCL_ERROR;
    }

    RTI::InteractionClassHandle h;

    if (getIClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getInteractionClassName theHandle
 *
 * INPUTS:
 *	theHandle	An object class handle or name.
 *
 * RETURNS:
 *	The class name
 *
 * DESCRIPTION:
 *	Returns an interaction class's name given its handle.
 *      If given a name, the name is converted to a handle and
 *      then back to a name.
 */

static int 
rtiAmb_getInteractionClassName(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle");
        return TCL_ERROR;
    }

    RTI::InteractionClassHandle theHandle;

    if (getIClassHandleFromObj(interp, objv[2], rai, &theHandle) != TCL_OK)
    {
        return TCL_ERROR;
    }


    try 
    {
        char* name =
            rai->rtiAmb.getInteractionClassName(theHandle);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getObjectClass theObject
 *
 * INPUTS:
 *	theObject	An object handle
 *
 * RETURNS:
 *	The class handle
 *
 * DESCRIPTION:
 *	Returns an object class's handle given an object handle.
 */

static int 
rtiAmb_getObjectClass(ClientData cd, Tcl_Interp *interp, 
                      int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theObject");
        return TCL_ERROR;
    }

    RTI::ObjectHandle h;

    if (getHandleFromObj(interp, objv[2], &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    RTI::ObjectClassHandle ch;

    try 
    {
        ch = rai->rtiAmb.getObjectClass(h);
        Tcl_Obj* result = Tcl_GetObjResult(interp);
        setHandleObj(result, ch);
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
 *	$ra getObjectClassHandle theName
 *
 * INPUTS:
 *	theName		An object class name or handle
 *
 * RETURNS:
 *	The class handle
 *
 * DESCRIPTION:
 *	Returns an object class's handle given its name.  If the input
 *      is a handle, it is returned unchanged; it is *not*
 *      validated.
 */

static int 
rtiAmb_getObjectClassHandle(ClientData cd, Tcl_Interp *interp, 
                            int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName");
        return TCL_ERROR;
    }

    RTI::ObjectClassHandle h;

    if (getOClassHandleFromObj(interp, objv[2], rai, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getObjectClassName theHandle
 *
 * INPUTS:
 *	theHandle	An object class handle or name
 *
 * RETURNS:
 *	The class name
 *
 * DESCRIPTION:
 *	Returns an object class's name given its handle.  If the input
 *      is a name, it is converted to a handle and then back to a name,
 *      thus validating it.
 */

static int 
rtiAmb_getObjectClassName(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle");
        return TCL_ERROR;
    }

    RTI::ObjectClassHandle theHandle;

    if (getOClassHandleFromObj(interp, objv[2], rai, &theHandle) != TCL_OK)
    {
        return TCL_ERROR;
    }


    try 
    {
        char* name =
            rai->rtiAmb.getObjectClassName(theHandle);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getObjectInstanceHandle theName
 *
 * INPUTS:
 *	theName		An object name or handle
 *
 * RETURNS:
 *	The object handle
 *
 * DESCRIPTION:
 *	Returns an object's handle given its name.
 */

static int 
rtiAmb_getObjectInstanceHandle(ClientData cd, Tcl_Interp *interp, 
                            int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName");
        return TCL_ERROR;
    }

    RTI::ObjectHandle h;
    char* theName = Tcl_GetStringFromObj(objv[2], NULL);

    try 
    {
        h = rai->rtiAmb.getObjectInstanceHandle(theName);
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getObjectInstanceName theHandle
 *
 * INPUTS:
 *	theHandle	An object handle or name
 *
 * RETURNS:
 *	The object name
 *
 * DESCRIPTION:
 *	Returns an object's name given its handle.
 */

static int 
rtiAmb_getObjectInstanceName(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle");
        return TCL_ERROR;
    }

    RTI::ObjectHandle theHandle;

    if (getHandleFromObj(interp, objv[2], &theHandle) != TCL_OK)
    {
        return TCL_ERROR;
    }


    try 
    {
        char* name =
            rai->rtiAmb.getObjectInstanceName(theHandle);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getParameterHandle theName whichClass
 *
 * INPUTS:
 *	theName		A parameter name or handle
 *      whichClass      An interaction class name or handle
 *
 * RETURNS:
 *	The parameter handle
 *
 * DESCRIPTION:
 *	Returns an interaction parameter handle given its name.
 */

static int 
rtiAmb_getParameterHandle(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName whichClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle whichClass;
    
    if (getIClassHandleFromObj(interp, objv[3], rai, &whichClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get the handle */

    RTI::ParameterHandle h;

    if (getParmHandleFromObj(interp, objv[2], rai, whichClass, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getParameterName theHandle whichClass
 *
 * INPUTS:
 *	theHandle	The parameter handle
 *      whichClass      The interaction class handle or name
 *
 * RETURNS:
 *	The parameter name
 *
 * DESCRIPTION:
 *	Returns a parameter's name given its handle.
 */

static int 
rtiAmb_getParameterName(ClientData cd, Tcl_Interp *interp, 
                        int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle whichClass");
        return TCL_ERROR;
    }

    /* Get whichClass */
    RTI::InteractionClassHandle whichClass;
    
    if (getIClassHandleFromObj(interp, objv[3], rai, &whichClass) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* Get theHandle */
    RTI::ParameterHandle h;

    if (getParmHandleFromObj(interp, objv[2], rai, whichClass, &h) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        char* name =
            rai->rtiAmb.getParameterName(h, whichClass);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra getRoutingSpaceHandle theName
 *
 * INPUTS:
 *	theName		A DDM routing space name
 *
 * RETURNS:
 *	The routing space handle
 *
 * DESCRIPTION:
 *	Returns a routing space handle given its name.
 */

static int 
rtiAmb_getRoutingSpaceHandle(ClientData cd, Tcl_Interp *interp, 
                             int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theName");
        return TCL_ERROR;
    }

    RTI::SpaceHandle h;
    char* theName = Tcl_GetStringFromObj(objv[2], NULL);

    try
    {
        h = rai->rtiAmb.getRoutingSpaceHandle(theName);
    }
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

    Tcl_Obj* result = Tcl_GetObjResult(interp);
    setHandleObj(result, h);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	$ra getRoutingSpaceName theHandle
 *
 * INPUTS:
 *	theHandle	The routing space handle
 *
 * RETURNS:
 *	The routing space name
 *
 * DESCRIPTION:
 *	Returns a routing space name given its handle.
 */

static int 
rtiAmb_getRoutingSpaceName(ClientData cd, Tcl_Interp *interp, 
                          int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 3) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "theHandle");
        return TCL_ERROR;
    }

    RTI::SpaceHandle theHandle;

    if (getSpaceHandleFromObj(interp, objv[2], rai, &theHandle) != TCL_OK)
    {
        return TCL_ERROR;
    }

    try 
    {
        char* name =
            rai->rtiAmb.getRoutingSpaceName(theHandle);

        Tcl_SetResult(interp, name, TCL_VOLATILE);

        delete[] name; 
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
 *	$ra tick ?minimum maximum?
 *
 * INPUTS:
 *	minimum		Minimum tick time, in decimal seconds.
 *      maximum         Maximum tick time, in decimal seconds.
 *
 * RETURNS:
 *      nothing	
 *
 * DESCRIPTION:
 *	Implements destroyFederationExecution subcommand.
 */

static int 
rtiAmb_tick(ClientData cd, Tcl_Interp *interp, 
            int objc, Tcl_Obj* CONST objv[])
{
    RtiAmbInfo* rai = (RtiAmbInfo*)cd;

    if (objc != 2 && objc != 4) 
    {
        Tcl_WrongNumArgs(interp, 2, objv, "?minimum maximum?");
        return TCL_ERROR;
    }

    try 
    {
        /* FIRST, do the tick. */
        if (objc == 2) 
        {
            rai->rtiAmb.tick();
        }
        else
        {
            double min;
            double max; 

            if (Tcl_GetDoubleFromObj(interp, objv[2], &min) != TCL_OK)
            {
                return TCL_ERROR;
            }

            if (Tcl_GetDoubleFromObj(interp, objv[3], &max) != TCL_OK)
            {
                return TCL_ERROR;
            }

            rai->rtiAmb.tick(min, max);
        }

        /* NEXT, evaluate the queued commands. */
        rai->fedAmb.evalQueue();
    } 
    catch (RTI::Exception& e)
    {
        return throwTclError(interp, e);
    }

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
 *	getOClassHandleFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Acquires an ObjectClassHandle from objPtr.  The value may
 *      be a handle or a class name.
 */

static int
getOClassHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                      RtiAmbInfo* rai,
                      RTI::ObjectClassHandle* pH)
{
    /* FIRST, see if it's a handle. */
    if (getHandleFromObj(interp, objPtr, pH) == TCL_OK) 
    {
        return TCL_OK;
    }

    /* NEXT, clear the error. */
    Tcl_ResetResult(interp);

    /* NEXT, it's not a handle; see if it's a name. */
    char* theName = Tcl_GetStringFromObj(objPtr, NULL);

    try 
    {
        *pH = rai->rtiAmb.getObjectClassHandle(theName);
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
 *	getAttrHandleFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *      whichClass      The class handle
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Acquires an AttributeHandle from objPtr.  The value may
 *      be a handle or an attribute name.
 */

static int
getAttrHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                     RtiAmbInfo* rai,
                     RTI::ObjectClassHandle whichClass,
                     RTI::AttributeHandle* pH)
{
    /* FIRST, see if it's a handle. */
    if (getHandleFromObj(interp, objPtr, pH) == TCL_OK) 
    {
        return TCL_OK;
    }

    /* NEXT, clear the error. */
    Tcl_ResetResult(interp);

    /* NEXT, it's not a handle; see if it's a name. */
    char* theName = Tcl_GetStringFromObj(objPtr, NULL);

    try 
    {
        *pH = rai->rtiAmb.getAttributeHandle(theName, whichClass);
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
 *	getAttrArrayFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value; List of attr names or handles
 *      rai             RtiAmbInfo, the state for this ambassador
 *      whichClass      The class handle
 *
 * OUTPUTS:
 *	pArray		The attribute handle array
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Fills in an array of attribute handles using values from objPtr.  
 *      The value of objPtr should be a list of attribute handles or names or both.
 *
 *      The array pArray will be dimensioned by the number of attributes provided.
 *      On successful return, the caller must delete the array.
 */

static int
getAttrArrayFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                    RtiAmbInfo* rai,
                    RTI::ObjectClassHandle whichClass,
                    RTI::AttributeHandle** pArray)
{
    /* FIRST, Get the attribute list */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objPtr, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, create an array */
    RTI::AttributeHandle* attrs = new RTI::AttributeHandle[listc];

    /* NEXT, fill it in */
    for (int i = 0; i < listc; i++)
    {
        RTI::AttributeHandle h;

        if (getAttrHandleFromObj(interp, listv[i], rai, 
                                 whichClass, &h) != TCL_OK) {
            delete[] attrs;
            return TCL_ERROR;
        }

        attrs[i] = h;
    }

    *pArray = attrs;

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getAttrSetFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *      whichClass      The class handle
 *
 * OUTPUTS:
 *	pSet		The handle set buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Acquires an AttributeHandleSet from objPtr.  The value should
 *      be a list of attribute handles or names or both.
 *
 *      On successful return, the caller must "delete" the handle set.
 */

static int
getAttrSetFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                  RtiAmbInfo* rai,
                  RTI::ObjectClassHandle whichClass,
                  RTI::AttributeHandleSet** pSet)
{
    /* FIRST, Get the attribute list */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objPtr, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, create an empty handle set. */
    RTI::AttributeHandleSet* attrs =
        RTI::AttributeHandleSetFactory::create(listc);

    for (int i = 0; i < listc; i++)
    {
        RTI::AttributeHandle h;

        if (getAttrHandleFromObj(interp, listv[i], rai, 
                                 whichClass, &h) != TCL_OK) {
            delete attrs;
            return TCL_ERROR;
        }

        attrs->add(h);
    }

    *pSet = attrs;

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getIClassHandleFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Acquires an InteractionClassHandle from objPtr.  The value may
 *      be a handle or a class name.
 */

static int
getIClassHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                       RtiAmbInfo* rai,
                       RTI::InteractionClassHandle* pH)
{
    /* FIRST, see if it's a handle. */
    if (getHandleFromObj(interp, objPtr, pH) == TCL_OK) 
    {
        return TCL_OK;
    }

    /* NEXT, clear the error. */
    Tcl_ResetResult(interp);

    /* NEXT, it's not a handle; see if it's a name. */
    char* theName = Tcl_GetStringFromObj(objPtr, NULL);

    try 
    {
        *pH = rai->rtiAmb.getInteractionClassHandle(theName);
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
 *	getParmHandleFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *      whichClass      The interaction class handle
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Acquires a ParameterHandle from objPtr.  The value may
 *      be a handle or an attribute name.
 */

static int
getParmHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                     RtiAmbInfo* rai,
                     RTI::InteractionClassHandle whichClass,
                     RTI::ParameterHandle* pH)
{
    /* FIRST, see if it's a handle. */
    if (getHandleFromObj(interp, objPtr, pH) == TCL_OK) 
    {
        return TCL_OK;
    }

    /* NEXT, clear the error. */
    Tcl_ResetResult(interp);

    /* NEXT, it's not a handle; see if it's a name. */
    char* theName = Tcl_GetStringFromObj(objPtr, NULL);

    try 
    {
        *pH = rai->rtiAmb.getParameterHandle(theName, whichClass);
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
 *	getRegionFromObj()
 *
 * INPUTS:
 *	interp		Tcl interpreter
 *	objPtr          The Tcl command representation of the region
 *      rai             RtiAmbInfo, the state for this ambassador
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
getRegionFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                 RtiAmbInfo* rai, RTI::Region** pR)
{
    long int li = 0;
    Tcl_HashEntry* entryPtr;

    /* Is the region known? */
    if ((entryPtr = 
         Tcl_FindHashEntry(rai->regionHash, Tcl_GetString(objPtr))) == NULL)
    {
        return TCL_ERROR;
    }

    *pR = (RTI::Region*) Tcl_GetHashValue(entryPtr);

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getRegionArrayFromObj()
 *
 * INPUTS:
 *	interp          Tcl interpreter
 *	objPtr		The Tcl object value; List of region commands
 *      rai             RtiAmbInfo, the state for this ambassador
 *
 * OUTPUTS:
 *	pArray		The region pointer array
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure
 *
 * DESCRIPTION:
 *	Fills in an array of region pointers using values from objPtr.  
 *      The value of objPtr should be a list of region names previously
 *      obtained from createRegion.
 *
 *      The array pArray will be dimensioned by the number of regions provided.
 *      On successful return, the caller must delete the array.
 */

static int
getRegionArrayFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                      RtiAmbInfo* rai, RTI::Region*** pArray)
{
    /* FIRST, Get the attribute list */
    int listc;
    Tcl_Obj** listv;

    if (Tcl_ListObjGetElements(interp, objPtr, &listc, &listv) != TCL_OK)
    {
        return TCL_ERROR;
    }

    /* NEXT, create an array to hold the region pointers */
    RTI::Region** regions = new RTI::Region*[listc];

    /* NEXT, fill it in */
    for (int i = 0; i < listc; i++)

    {
        if (getRegionFromObj(interp, listv[i], rai, &regions[i]) != TCL_OK) 
        {
            return TCL_ERROR;
        }
    }

    *pArray = regions;

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	getSpaceHandleFromObj()
 *
 * INPUTS:
 *	interp		Tcl interpreter
 *	objPtr          The Tcl object value
 *      rai             RtiAmbInfo, the state for this ambassador
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure.
 *
 * DESCRIPTION:
 *	Attempts to read an RTI::SpaceHandle from the object.  The objPtr
 *      can be a handle or a name        
 */

static int
getSpaceHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, 
                      RtiAmbInfo* rai, RTI::SpaceHandle* pH)
{
    RTI::Handle h;

    /* FIRST, see if it's a handle. */
    if (getHandleFromObj(interp, objPtr, &h) == TCL_OK) 
    {
        *pH = h;
        return TCL_OK;
    }

    /* NEXT, clear the error. */
    Tcl_ResetResult(interp);

    /* NEXT, it's not a handle; see if it's a name. */
    char* theName = Tcl_GetStringFromObj(objPtr, NULL);

    try 
    {
        *pH = rai->rtiAmb.getRoutingSpaceHandle(theName);
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
 *	getHandleFromObj()
 *
 * INPUTS:
 *	interp		Tcl interpreter
 *	objPtr          The Tcl object value
 *
 * OUTPUTS:
 *	pH		The handle buffer
 *
 * RETURNS:
 *	TCL_OK on success, TCL_ERROR on failure.
 *
 * DESCRIPTION:
 *	Attempts to read an RTI::Handle from the object.
 */

static int
getHandleFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, RTI::Handle* pH)
{
    Tcl_WideInt wi = 0;

    if (Tcl_GetWideIntFromObj(interp, objPtr, &wi) != TCL_OK) 
    {
        return TCL_ERROR;
    }

    *pH = (RTI::Handle)wi;

    return TCL_OK;
}

/***********************************************************************
 *
 * FUNCTION:
 *	setHandleObj()
 *
 * INPUTS:
 *	objPtr          The Tcl object value
 *      h               The handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Sets an object to contain a handle.
 */

static void
setHandleObj(Tcl_Obj* objPtr, RTI::Handle h)
{
    Tcl_SetWideIntObj(objPtr, h);
}


