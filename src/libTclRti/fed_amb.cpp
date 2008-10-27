/***********************************************************************
 *
 * TITLE:
 *	fed_amb.cpp
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	JNEM: shark(1) module, RTI FedAmb definition.
 *
 *      Most of the methods defined in this module are standard
 *      FederateAmbassador methods; see the RTI spec for the semantics
 *      of each.
 *
 *
 ***********************************************************************/

#include "tcl_rti.h"

/*
 * Data Types
 */

/*
 * Static Function Prototypes
 */

static Tcl_Obj*    saveName(const char*);
static void        bgerror(Tcl_Interp*, Tcl_Obj*);
static int         getHandleFromObj(Tcl_Interp*, Tcl_Obj*, RTI::Handle*);

/*
 * Tcl Option String Objects
 */

static Tcl_Obj* optTime = saveName("-time");
static Tcl_Obj* optTag  = saveName("-tag");
static Tcl_Obj* optErh  = saveName("-erh");

/*
 * Tcl FedAmb method name objects.
 */

static Tcl_Obj* oSynchronizationPointRegistrationSucceeded =
    saveName("synchronizationPointRegistrationSucceeded");

static Tcl_Obj* oSynchronizationPointRegistrationFailed =
    saveName("synchronizationPointRegistrationFailed");

static Tcl_Obj* oAnnounceSynchronizationPoint =
    saveName("announceSynchronizationPoint");

static Tcl_Obj* oFederationSynchronized =
    saveName("federationSynchronized");

static Tcl_Obj* oInitiateFederateSave =
    saveName("initiateFederateSave");

static Tcl_Obj* oFederationSaved =
    saveName("federationSaved");

static Tcl_Obj* oFederationNotSaved =
    saveName("federationNotSaved");

static Tcl_Obj* oRequestFederationRestoreSucceeded =
    saveName("requestFederationRestoreSucceeded");

static Tcl_Obj* oRequestFederationRestoreFailed =
    saveName("requestFederationRestoreFailed");

static Tcl_Obj* oFederationRestoreBegun =
    saveName("federationRestoreBegun");

static Tcl_Obj* oInitiateFederateRestore =
    saveName("initiateFederateRestore");

static Tcl_Obj* oFederationRestored =
    saveName("federationRestored");

static Tcl_Obj* oFederationNotRestored =
    saveName("federationNotRestored");

static Tcl_Obj* oStartRegistrationForObjectClass =
    saveName("startRegistrationForObjectClass");

static Tcl_Obj* oStopRegistrationForObjectClass =
    saveName("stopRegistrationForObjectClass");

static Tcl_Obj* oTurnInteractionsOn =
    saveName("turnInteractionsOn");

static Tcl_Obj* oTurnInteractionsOff =
    saveName("turnInteractionsOff");

static Tcl_Obj* oDiscoverObjectInstance =
    saveName("discoverObjectInstance");

static Tcl_Obj* oReflectAttributeValues =
    saveName("reflectAttributeValues");

static Tcl_Obj* oReceiveInteraction =
    saveName("receiveInteraction");

static Tcl_Obj* oRemoveObjectInstance =
    saveName("removeObjectInstance");

static Tcl_Obj* oAttributesInScope =
    saveName("attributesInScope");

static Tcl_Obj* oAttributesOutOfScope =
    saveName("attributesOutOfScope");

static Tcl_Obj* oProvideAttributeValueUpdate =
    saveName("provideAttributeValueUpdate");

static Tcl_Obj* oTurnUpdatesOnForObjectInstance =
    saveName("turnUpdatesOnForObjectInstance");

static Tcl_Obj* oTurnUpdatesOffForObjectInstance =
    saveName("turnUpdatesOffForObjectInstance");

static Tcl_Obj* oRequestAttributeOwnershipAssumption =
    saveName("requestAttributeOwnershipAssumption");

static Tcl_Obj* oAttributeOwnershipAcquisitionNotification =
    saveName("attributeOwnershipAcquisitionNotification");

static Tcl_Obj* oAttributeOwnershipDivestitureNotification =
    saveName("attributeOwnershipDivestitureNotification");

static Tcl_Obj* oAttributeOwnershipUnavailable =
    saveName("attributeOwnershipUnavailable");

static Tcl_Obj* oRequestAttributeOwnershipRelease =
    saveName("requestAttributeOwnershipRelease");

static Tcl_Obj* oConfirmAttributeOwnershipAcquisitionCancellation =
    saveName("confirmAttributeOwnershipAcquisitionCancellation");

static Tcl_Obj* oInformAttributeOwnership =
    saveName("informAttributeOwnership");

static Tcl_Obj* oAttributeIsNotOwned =
    saveName("attributeIsNotOwned");

static Tcl_Obj* oAttributeOwnedByRTI =
    saveName("attributeOwnedByRTI");

static Tcl_Obj* oTimeRegulationEnabled =
    saveName("timeRegulationEnabled");

static Tcl_Obj* oTimeConstrainedEnabled =
    saveName("timeConstrainedEnabled");

static Tcl_Obj* oTimeAdvanceGrant =
    saveName("timeAdvanceGrant");

static Tcl_Obj* oRequestRetraction =
    saveName("requestRetraction");

/*
 * Other Tcl string objects
 */

static Tcl_Obj* oBgerror = 
    saveName("bgerror");

static Tcl_Obj* oErrorInfo = 
    saveName("::errorInfo");


/*
 * Constructor and Destructor
 */

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::FedAmb()
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	Nothing
 *
 * DESCRIPTION:
 *	Constructor
 */

FedAmb::FedAmb() 
    : faCmd(NULL), faObj(NULL), methodQueue(NULL)
{ 

    methodQueue = Tcl_NewObj();
    Tcl_IncrRefCount(methodQueue);

    /* Initialize the hash tables of object, interaction, attribute 
       and parameter names. */
    objClassNameHash = (Tcl_HashTable*) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(objClassNameHash, 2);

    intClassNameHash = (Tcl_HashTable*) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(intClassNameHash, 2);

    objAttrNameHash = (Tcl_HashTable*) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(objAttrNameHash, 2);

    intParmNameHash = (Tcl_HashTable*) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(intParmNameHash, 2);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::~FedAmb()
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Destructor
 */

FedAmb::~FedAmb()
    throw(RTI::FederateInternalError) 
{ 
    if (faObj)
    {
        Tcl_DecrRefCount(faObj);
        Tcl_Free(faCmd); 
    }

    if (methodQueue)
    {
        Tcl_DecrRefCount(methodQueue);
    }
}

/*
 * Static Data Members
 */

/*
 * FedAmb Instance Methods
 */

/* Utility Methods */


/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::setFaName()
 *
 * INPUTS:
 *	theInterp	The Tcl interpreter
 *      theFaName       The name of the FederateAmbassador object
 *                      (a Tcl command name)
 *      theRtiAmb       The RTIambassador, to be used for looking up names.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Saves the Tcl interpreter and the object name, for callbacks.
 */

void
FedAmb::setFaName(
    Tcl_Interp* theInterp,
    const char* theFaName,
    RTI::RTIambassador* theRtiAmb)
{
    interp = theInterp;
    faCmd = Tcl_Alloc(strlen(theFaName) + 1);
    strcpy(faCmd, theFaName);

    faObj = saveName(theFaName);

    rtiAmb = theRtiAmb;
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::evalQueue()
 *
 * INPUTS:
 *	none
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Evaluates all queued commands; bgerror is called for any
 *      error returns.
 */

void
FedAmb::evalQueue()
    throw()
{
    /* FIRST, get the method queue as an array. */
    int listc;
    Tcl_Obj** listv;

    int code = Tcl_ListObjGetElements(interp, 
                                      methodQueue,
                                      &listc,
                                      &listv);
    assert(code == TCL_OK);

    if (listc == 0) 
    {
        return;
    }

    /* NEXT, call each one */
    for (int i = 0; i < listc; i++)
    {
        /* FIRST, get the command as an array. */
        int cmdc;
        Tcl_Obj** cmdv;

        code = Tcl_ListObjGetElements(interp, listv[i], &cmdc, &cmdv);
        assert(code == TCL_OK);


        /* NEXT, execute the command. */
        int code = Tcl_EvalObjv(interp, cmdc, cmdv, 
                                TCL_EVAL_GLOBAL | TCL_EVAL_DIRECT);

        if (code != TCL_OK)
        {
            bgerror(interp, NULL);
        }
    }

    /* NEXT, release our reference to the method queue, and 
    ** create a new one. */
    Tcl_DecrRefCount(methodQueue);
    methodQueue = Tcl_NewObj();
    Tcl_IncrRefCount(methodQueue);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qm()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method.
 */

void
FedAmb::qm(
    Tcl_Obj* method)
    throw()
{
    Tcl_Obj* objv[2];

    objv[0] = faObj;
    objv[1] = method;

    Tcl_Obj* command = Tcl_NewListObj(2, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWith0()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      o               Tcl_Obj with argument 
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with the Tcl_Obj as an argument.
 */

void
FedAmb::qmWithO(
    Tcl_Obj* method,
    Tcl_Obj* o)
    throw()
{
    Tcl_Obj* objv[3];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = o;

    Tcl_Obj* command = Tcl_NewListObj(3, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWithS()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      s               A character string.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with the string.
 */

void
FedAmb::qmWithS(
    Tcl_Obj* method,
    const char* s)
    throw()
{
    Tcl_Obj* objv[3];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = Tcl_NewStringObj(s, -1);

    Tcl_Obj* command = Tcl_NewListObj(3, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWithSS()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      s1              A character string.
 *      s2              A character string.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with two strings.
 */

void
FedAmb::qmWithSS(
    Tcl_Obj* method,
    const char* s1,
    const char* s2)
    throw()
{
    Tcl_Obj* objv[4];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = Tcl_NewStringObj(s1, -1);
    objv[3] = Tcl_NewStringObj(s2, -1);

    Tcl_Obj* command = Tcl_NewListObj(4, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWithSH()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      s               A character string.
 *      h		A handle
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with a string and a handle.
 */

void
FedAmb::qmWithSH(
    Tcl_Obj* method,
    const char* s,
    RTI::Handle h)
    throw()
{
    Tcl_Obj* objv[4];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = Tcl_NewStringObj(s, -1);
    objv[3] = Tcl_NewWideIntObj(h);

    Tcl_Obj* command = Tcl_NewListObj(4, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWithHAs()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      h		An object instance handle
 *      ahs             The attribute handle set 
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with the handle and the attributes.
 */

void
FedAmb::qmWithHAs(
    Tcl_Obj* method,
    RTI::ObjectHandle h,
    const RTI::AttributeHandleSet& ahs)
    throw()
{
    Tcl_Obj* objv[4];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = Tcl_NewWideIntObj(h);
    objv[3] = Tcl_NewObj();

    RTI::ObjectClassHandle ch = 
        rtiAmb->getObjectClass(h);

    for (RTI::ULong i = 0; i < ahs.size(); i++)
    {
        char* nameStr = rtiAmb->getAttributeName(ahs.getHandle(i), ch);
        
        Tcl_Obj* nameObj = Tcl_NewStringObj(nameStr, -1);
        Tcl_ListObjAppendElement(interp, objv[3], nameObj);

        delete[] nameStr;
    }

    Tcl_Obj* command = Tcl_NewListObj(4, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}


/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::qmWithT()
 *
 * INPUTS:
 *	method		Tcl_Obj set to method name
 *      t               The time
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Queues the method with the time.
 */

void
FedAmb::qmWithT(
    Tcl_Obj* method,
    const RTI::FedTime& t)
    throw()
{
    Tcl_Obj* objv[3];

    objv[0] = faObj;
    objv[1] = method;
    objv[2] = Tcl_NewDoubleObj(((RTIfedTime)t).getTime());

    Tcl_Obj* command = Tcl_NewListObj(3, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::clearCache()
 *
 * INPUTS:
 *	None
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Clears all names that have been stored as Tcl_Objs in 
 *      hash tables and re-initializes the hash tables.
 */

void
FedAmb::clearCache()
{
    Tcl_HashEntry*  entryPtr;
    Tcl_HashSearch* searchPtr = 
        (Tcl_HashSearch*) ckalloc(sizeof(Tcl_HashSearch));
    Tcl_HashTable* tables[] = 
        {intClassNameHash, intParmNameHash, objAttrNameHash, objClassNameHash};

    /* Clear and re-initialize each hash table, one at a time. */
    for (int i = 0; i < 4; i++) 
    {
        entryPtr = Tcl_FirstHashEntry(tables[i], searchPtr);
        while (entryPtr)
        {
            /* Each entry is a pointer to a Tcl_Obj.
               Decrementing the reference count will allow it to be freed. */
            Tcl_DecrRefCount((Tcl_Obj*) Tcl_GetHashValue(entryPtr));
            entryPtr = Tcl_NextHashEntry(searchPtr);
        }
        Tcl_DeleteHashTable(tables[i]);
        Tcl_InitHashTable(tables[i], 2);
    }
    
    ckfree((char*) searchPtr);
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::getAttributeTclObj
 *
 * INPUTS:
 *     theAttribute   The handle of the attribute
 *     theObject      The handle of the object class
 *
 * RETURNS:
 *	A pointer to a Tcl_Obj containing the attribute name.
 *
 * DESCRIPTION:
 *      This is a wrapper for RTIambassador::getAttributeName().  This is
 *      provided for performance reasons.  By hashing the name as a Tcl_Obj,
 *      time needed for memory allocation/deallocation is saved.
 */

Tcl_Obj*
FedAmb::getAttributeTclObj(
    RTI::AttributeHandle    theAttribute,
    RTI::ObjectClassHandle  theObject)
{
    Tcl_Obj*       nameObj;
    Tcl_HashEntry* entryPtr;
    int key[] = {theAttribute, theObject};

    /* If the entry doesn't yet exist, create it.  Otherwise return it. */
    if ((entryPtr = Tcl_FindHashEntry(objAttrNameHash, (char*) key)) == NULL)
    {
        int newInt;
        entryPtr = 
            Tcl_CreateHashEntry(objAttrNameHash, (char*) key, &newInt);

        char* nameStr = 
            rtiAmb->getAttributeName(theAttribute, theObject);
        
        nameObj = Tcl_NewStringObj(nameStr, -1);
        Tcl_IncrRefCount(nameObj);
        Tcl_SetHashValue(entryPtr, nameObj);

        delete[] nameStr;
    } 
    else
    {
        nameObj = (Tcl_Obj*) Tcl_GetHashValue(entryPtr);
    }

    return nameObj;
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::getParameterTclObj
 *
 * INPUTS:
 *     theParameter     The handle of the parameter
 *     theInteraction   The handle of the interaction class
 *
 * RETURNS:
 *	A pointer to a Tcl_Obj containing the parameter name.
 *
 * DESCRIPTION:
 *      This is a wrapper for RTIambassador::getParameterName().  This is
 *      provided for performance reasons.  By hashing the name as a Tcl_Obj,
 *      time needed for memory allocation/deallocation is saved.
 */

Tcl_Obj*
FedAmb::getParameterTclObj(
    RTI::ParameterHandle    theParameter,
    RTI::InteractionClassHandle  theInteraction)
{
    Tcl_Obj*       nameObj;
    Tcl_HashEntry* entryPtr;
    int key[] = {theParameter, theInteraction};

    /* If the entry doesn't yet exist, create it.  Otherwise return it. */
    if ( (entryPtr = Tcl_FindHashEntry(intParmNameHash, (char*) key)) == NULL) 
    {
        int newInt;
        entryPtr = Tcl_CreateHashEntry(intParmNameHash, (char*) key, &newInt);

        char* nameStr = 
            rtiAmb->getParameterName(theParameter, theInteraction);
        
        nameObj = Tcl_NewStringObj(nameStr, -1);
        Tcl_IncrRefCount(nameObj);
        Tcl_SetHashValue(entryPtr, nameObj);

        delete[] nameStr;
    } 
    else
    {
        nameObj = (Tcl_Obj*) Tcl_GetHashValue(entryPtr);
    }

    return nameObj;
}

/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::getObjClassTclObj
 *
 * INPUTS:
 *     theObject      The handle of the object class
 *
 * RETURNS:
 *	A pointer to a Tcl_Obj containing the object class name.
 *
 * DESCRIPTION:
 *      This is a wrapper for RTIambassador::getObjectClassName().  This is
 *      provided for performance reasons.  By hashing the name as a Tcl_Obj,
 *      time needed for memory allocation/deallocation is saved.
 */

Tcl_Obj*
FedAmb::getObjClassTclObj(RTI::ObjectClassHandle  theObject)
{
    Tcl_Obj*       nameObj;
    Tcl_HashEntry* entryPtr;
    int key[] = {theObject, 0};

    /* If the entry doesn't yet exist, create it.  Otherwise return it. */
    if ((entryPtr = Tcl_FindHashEntry(objClassNameHash, (char*) key)) == NULL)
    {
        int newInt;
        entryPtr = 
            Tcl_CreateHashEntry(objClassNameHash, (char*) key, &newInt);

        char* nameStr = rtiAmb->getObjectClassName(theObject);
        
        nameObj = Tcl_NewStringObj(nameStr, -1);
        Tcl_IncrRefCount(nameObj);
        Tcl_SetHashValue(entryPtr, nameObj);

        delete[] nameStr;
    } 
    else
    {
        nameObj = (Tcl_Obj*) Tcl_GetHashValue(entryPtr);
    }

    return nameObj;
}


/***********************************************************************
 *
 * FUNCTION:
 *	FedAmb::getIntClassTclObj
 *
 * INPUTS:
 *     theInteraction      The handle of the interaction class
 *
 * RETURNS:
 *	A pointer to a Tcl_Obj containing the interaction class name.
 *
 * DESCRIPTION:
 *      This is a wrapper for RTIambassador::getInteractionClassName().  
 *      This is provided for performance reasons.  By hashing the name 
 *      as a Tcl_Obj, time needed for memory allocation/deallocation is saved.
 */

Tcl_Obj*
FedAmb::getIntClassTclObj(RTI::InteractionClassHandle  theInteraction)
{
    Tcl_Obj*       nameObj;
    Tcl_HashEntry* entryPtr;
    int key[] = {theInteraction, 0};

    /* If the entry doesn't yet exist, create it.  Otherwise return it. */
    if ((entryPtr = Tcl_FindHashEntry(intClassNameHash, (char*) key)) == NULL)
    {
        int newInt;
        entryPtr = 
            Tcl_CreateHashEntry(intClassNameHash, (char*) key, &newInt);

        char* nameStr = rtiAmb->getInteractionClassName(theInteraction);
        
        nameObj = Tcl_NewStringObj(nameStr, -1);
        Tcl_IncrRefCount(nameObj);
        Tcl_SetHashValue(entryPtr, nameObj);

        delete[] nameStr;
    } 
    else
    {
        nameObj = (Tcl_Obj*) Tcl_GetHashValue(entryPtr);
    }

    return nameObj;
}

/*
 * Federation Management Services
 */

void 
FedAmb::synchronizationPointRegistrationSucceeded(const char *label)
  throw(RTI::FederateInternalError)
{
    qmWithS(oSynchronizationPointRegistrationSucceeded, label);
}


void 
FedAmb::synchronizationPointRegistrationFailed(const char *label) 
  throw(RTI::FederateInternalError)
{
    qmWithS(oSynchronizationPointRegistrationFailed, label);
}


void 
FedAmb::announceSynchronizationPoint (const char *label, 
                                      const char *tag)
  throw(RTI::FederateInternalError)
{
    qmWithSS(oAnnounceSynchronizationPoint, label, tag);
}


void 
FedAmb::federationSynchronized (const char *label)
  throw(RTI::FederateInternalError)
{
    qmWithS(oFederationSynchronized, label);
}


void 
FedAmb::initiateFederateSave (const char *label)
  throw(RTI::UnableToPerformSave,
         RTI::FederateInternalError)
{
    qmWithS(oInitiateFederateSave, label);
}


void 
FedAmb::federationSaved ()
  throw(RTI::FederateInternalError)
{
    qm(oFederationSaved);
}


void 
FedAmb::federationNotSaved ()
  throw(RTI::FederateInternalError)
{
    qm(oFederationNotSaved);
}


void 
FedAmb::requestFederationRestoreSucceeded (const char *label)
  throw(RTI::FederateInternalError)
{
    qmWithS(oRequestFederationRestoreSucceeded, label);
}

// Case 1
void 
FedAmb::requestFederationRestoreFailed (const char *label)
  throw(RTI::FederateInternalError)
{
    qmWithS(oRequestFederationRestoreFailed, label);
}

// Case 2
void 
FedAmb::requestFederationRestoreFailed(const char *label,
                                       const char *reason)
  throw(RTI::FederateInternalError)
{
    qmWithSS(oRequestFederationRestoreFailed, label, reason);
}


void 
FedAmb::federationRestoreBegun ()
  throw (RTI::FederateInternalError)
{
    qm(oFederationRestoreBegun);
}


void 
FedAmb::initiateFederateRestore (const char *label, RTI::FederateHandle handle)
  throw(RTI::SpecifiedSaveLabelDoesNotExist,
         RTI::CouldNotRestore,
	 RTI::FederateInternalError)
{
    qmWithSH(oInitiateFederateRestore, label, handle);
}


void 
FedAmb::federationRestored ()
  throw(RTI::FederateInternalError)
{
    qm(oFederationRestored);
}


void 
FedAmb::federationNotRestored ()
  throw(RTI::FederateInternalError)
{
    qm(oFederationNotRestored);
}

/*
 * Declaration Management Services 
 */

void 
FedAmb::startRegistrationForObjectClass(
    RTI::ObjectClassHandle theClass)
    throw(RTI::ObjectClassNotPublished,
          RTI::FederateInternalError)
{
    qmWithO(oStartRegistrationForObjectClass, getObjClassTclObj(theClass));
}

void 
FedAmb::stopRegistrationForObjectClass(
    RTI::ObjectClassHandle theClass)
    throw(RTI::ObjectClassNotPublished,
           RTI::FederateInternalError)
{
    qmWithO(oStopRegistrationForObjectClass, getObjClassTclObj(theClass));
}

void 
FedAmb::turnInteractionsOn(
    RTI::InteractionClassHandle theHandle)
    throw(RTI::InteractionClassNotPublished,
          RTI::FederateInternalError)
{
    qmWithO(oTurnInteractionsOn, getIntClassTclObj(theHandle));
}

void 
FedAmb::turnInteractionsOff(
    RTI::InteractionClassHandle theHandle)
    throw(RTI::InteractionClassNotPublished,
          RTI::FederateInternalError)
{
    qmWithO(oTurnInteractionsOff, getIntClassTclObj(theHandle));
}

/*
 * Object Management Services
 */

void 
FedAmb::discoverObjectInstance(
    RTI::ObjectHandle theObject,
    RTI::ObjectClassHandle theObjectClass,
    const char* theObjectName)
    throw (
        RTI::CouldNotDiscover,
        RTI::ObjectClassNotKnown,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[5];

    objv[0] = faObj;
    objv[1] = oDiscoverObjectInstance;
    objv[2] = Tcl_NewWideIntObj(theObject);

    char* name = rtiAmb->getObjectClassName(theObjectClass);
    objv[3] = Tcl_NewStringObj(name, -1);
    delete[] name;

    objv[4] = Tcl_NewStringObj(theObjectName, -1);

    Tcl_Obj* command = Tcl_NewListObj(5, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

void 
FedAmb::setup_receiveInteraction(
    RTI::InteractionClassHandle theInteraction,            // supplied C1
    const RTI::ParameterHandleValuePairSet& theParameters, // supplied C4
    const char *theTag,                                    // supplied C4
    Tcl_Obj* objv[])
{
    objv[0] = faObj;
    objv[1] = oReceiveInteraction;
    objv[2] = getIntClassTclObj(theInteraction);
    objv[3] = Tcl_NewObj();

    for (RTI::ULong i = 0; i < theParameters.size(); i++)
    {
        Tcl_Obj* nameObj = 
            getParameterTclObj(theParameters.getHandle(i), theInteraction);
        Tcl_ListObjAppendElement(interp, objv[3], nameObj);

        unsigned long length;
        unsigned char* bytes = 
            (unsigned char*)theParameters.getValuePointer(i, length);
        Tcl_ListObjAppendElement(interp, objv[3], 
                                 Tcl_NewByteArrayObj(bytes, length));
    }

    objv[4] = optTag;
    objv[5] = Tcl_NewStringObj(theTag, -1);
}


/* Case 1 */
void 
FedAmb::receiveInteraction (
    RTI::InteractionClassHandle theInteraction,
    const RTI::ParameterHandleValuePairSet& theParameters,
    const RTI::FedTime& theTime,
    const char *theTag,
    RTI::EventRetractionHandle theHandle)
    throw (
        RTI::InteractionClassNotKnown,
        RTI::InteractionParameterNotKnown,
        RTI::InvalidFederationTime,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[10];

    setup_receiveInteraction(theInteraction, theParameters, theTag, objv);

    objv[6] = optTime;
    objv[7] = Tcl_NewDoubleObj(((RTIfedTime)theTime).getTime());
    objv[8] = optErh;

    objv[9] = Tcl_NewObj();
    Tcl_ListObjAppendElement(interp, objv[9],
                             Tcl_NewWideIntObj(theHandle.theSerialNumber));
    Tcl_ListObjAppendElement(interp, objv[9],
                             Tcl_NewWideIntObj(theHandle.sendingFederate));


    Tcl_Obj* command = Tcl_NewListObj(10, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/* Case 2 */
void 
FedAmb::receiveInteraction (
    RTI::InteractionClassHandle theInteraction,
    const RTI::ParameterHandleValuePairSet& theParameters,
    const char *theTag)
    throw (
        RTI::InteractionClassNotKnown,
        RTI::InteractionParameterNotKnown,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[6];

    setup_receiveInteraction(theInteraction, theParameters, theTag, objv);

    Tcl_Obj* command = Tcl_NewListObj(6, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

void 
FedAmb::setup_ReflectAttributeValues(
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleValuePairSet& theAttributes,
    const char* theTag,
    Tcl_Obj* objv[])
{
    objv[0] = faObj;
    objv[1] = oReflectAttributeValues;
    objv[2] = Tcl_NewWideIntObj(theObject);
    objv[3] = Tcl_NewObj();

    /* Get the object class handle, so we can retrieve attribute
     * names */
    RTI::ObjectClassHandle ch =
        rtiAmb->getObjectClass(theObject);

    for (RTI::ULong i = 0; i < theAttributes.size(); i++)
    {
        Tcl_Obj* nameObj = getAttributeTclObj(theAttributes.getHandle(i), ch);
        Tcl_ListObjAppendElement(interp, objv[3], nameObj);

        unsigned long length;
        unsigned char* bytes = 
            (unsigned char*)theAttributes.getValuePointer(i, length);

        Tcl_ListObjAppendElement(interp, objv[3], 
                                 Tcl_NewByteArrayObj(bytes, length));
    }

    objv[4] = optTag;
    objv[5] = Tcl_NewStringObj(theTag, -1);
}

/* Case 1 */
void 
FedAmb::reflectAttributeValues (
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleValuePairSet& theAttributes,
    const RTI::FedTime& theTime,
    const char *theTag,
    RTI::EventRetractionHandle theHandle)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::FederateOwnsAttributes,
        RTI::InvalidFederationTime,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[10];

    setup_ReflectAttributeValues(theObject, theAttributes, theTag, objv);

    objv[6] = optTime;
    objv[7] = Tcl_NewDoubleObj(((RTIfedTime)theTime).getTime());
    objv[8] = optErh;

    objv[9] = Tcl_NewObj();
    Tcl_ListObjAppendElement(interp, objv[9],
                             Tcl_NewWideIntObj(theHandle.theSerialNumber));
    Tcl_ListObjAppendElement(interp, objv[9],
                             Tcl_NewWideIntObj(theHandle.sendingFederate));

    Tcl_Obj* command = Tcl_NewListObj(10, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/* Case 2 */
void 
FedAmb::reflectAttributeValues (
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleValuePairSet& theAttributes,
    const char *theTag)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::FederateOwnsAttributes,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[6];

    setup_ReflectAttributeValues(theObject, theAttributes, theTag, objv);

    Tcl_Obj* command = Tcl_NewListObj(6, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

void 
FedAmb::setup_removeObjectInstance(
    RTI::ObjectHandle theObject,
    const char *theTag,
    Tcl_Obj* objv[])
{
    objv[0] = faObj;
    objv[1] = oRemoveObjectInstance;
    objv[2] = Tcl_NewWideIntObj(theObject);
    objv[3] = optTag;
    objv[4] = Tcl_NewStringObj(theTag, -1);
}

/* Case 1 */
void 
FedAmb::removeObjectInstance(
    RTI::ObjectHandle theObject,
    const RTI::FedTime& theTime,
    const char *theTag,
    RTI::EventRetractionHandle theHandle)
    throw (
        RTI::ObjectNotKnown,
        RTI::InvalidFederationTime,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[9];
    Tcl_Obj* erh[2];

    setup_removeObjectInstance(theObject, theTag, objv);

    objv[5] = optTime;
    objv[6] = Tcl_NewDoubleObj(((RTIfedTime)theTime).getTime());

    objv[7] = optErh;

    erh[0] = Tcl_NewWideIntObj(theHandle.theSerialNumber);
    erh[1] = Tcl_NewWideIntObj(theHandle.sendingFederate);

    objv[8] = Tcl_NewListObj(2, erh);

    Tcl_Obj* command = Tcl_NewListObj(9, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

/* Case 2 */
void 
FedAmb::removeObjectInstance(
    RTI::ObjectHandle theObject,
    const char *theTag)
    throw (
        RTI::ObjectNotKnown,
        RTI::FederateInternalError)
{
    Tcl_Obj* objv[5];

    setup_removeObjectInstance(theObject, theTag, objv);

    Tcl_Obj* command = Tcl_NewListObj(5, objv);
    Tcl_ListObjAppendElement(interp, methodQueue, command);
}

void 
FedAmb::provideAttributeValueUpdate(
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& theAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::AttributeNotOwned,
        RTI::FederateInternalError)
{
    qmWithHAs(oProvideAttributeValueUpdate, theObject, theAttributes);
}

void 
FedAmb::turnUpdatesOnForObjectInstance(
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& theAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotOwned,
        RTI::FederateInternalError)
{
    qmWithHAs(oTurnUpdatesOnForObjectInstance, theObject, theAttributes);
}

void 
FedAmb::turnUpdatesOffForObjectInstance(
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& theAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotOwned,
        RTI::FederateInternalError)
{
    qmWithHAs(oTurnUpdatesOffForObjectInstance, theObject, theAttributes);
}

/* Ownership Management */

void 
FedAmb::attributeOwnershipAcquisitionNotification (
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& securedAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::AttributeAcquisitionWasNotRequested,
        RTI::AttributeAlreadyOwned,
        RTI::AttributeNotPublished,
        RTI::FederateInternalError)
{
    qmWithHAs(oAttributeOwnershipAcquisitionNotification, 
              theObject, securedAttributes);
}

void 
FedAmb::attributeOwnershipUnavailable (
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& theAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::AttributeAlreadyOwned,
        RTI::AttributeAcquisitionWasNotRequested,
        RTI::FederateInternalError)
{
    qmWithHAs(oAttributeOwnershipUnavailable, theObject, theAttributes);
}

void 
FedAmb::confirmAttributeOwnershipAcquisitionCancellation (
    RTI::ObjectHandle theObject,
    const RTI::AttributeHandleSet& theAttributes)
    throw (
        RTI::ObjectNotKnown,
        RTI::AttributeNotKnown,
        RTI::AttributeAlreadyOwned,
        RTI::AttributeAcquisitionWasNotCanceled,
        RTI::FederateInternalError)
{
    qmWithHAs(oConfirmAttributeOwnershipAcquisitionCancellation, 
              theObject, theAttributes);
}

/* Time Management */

void 
FedAmb::timeRegulationEnabled (
    const  RTI::FedTime& theFederateTime)
    throw (
        RTI::InvalidFederationTime,
        RTI::EnableTimeRegulationWasNotPending,
        RTI::FederateInternalError)
{
    qmWithT(oTimeRegulationEnabled, theFederateTime);
}
                
void 
FedAmb::timeConstrainedEnabled (
    const RTI::FedTime& theFederateTime)
    throw (
        RTI::InvalidFederationTime,
        RTI::EnableTimeConstrainedWasNotPending,
        RTI::FederateInternalError)
{
    qmWithT(oTimeConstrainedEnabled, theFederateTime);
}
                
void 
FedAmb::timeAdvanceGrant (
    const RTI::FedTime& theTime)
    throw (
        RTI::InvalidFederationTime,
        RTI::TimeAdvanceWasNotInProgress,
        RTI::FederateInternalError)
{
    qmWithT(oTimeAdvanceGrant, theTime);
}



/*
 * Static Utility Functions
 */

/***********************************************************************
 *
 * FUNCTION:
 *	saveName()
 *
 * INPUTS:
 *	name		An arbitrary string
 *
 * RETURNS:
 *	A Tcl_Obj* with refcount 1
 *
 * DESCRIPTION:
 *	Saves the name as a Tcl_Obj* for long term storage.
 */

static Tcl_Obj*
saveName(const char* name)
{
    Tcl_Obj* objPtr = Tcl_NewStringObj(name, -1);
    Tcl_IncrRefCount(objPtr);

    return objPtr;
}

/***********************************************************************
 *
 * FUNCTION:
 *	bgerror()
 *
 * INPUTS:
 *	interp		The Tcl interpreter
 *      method          For genuine Tcl errors, it's NULL.
 *                      For RTI errors, it's an RTI method name.
 *
 * RETURNS:
 *	nothing
 *
 * DESCRIPTION:
 *	Calls bgerror, passing the current result as the error message.
 */

static void
bgerror(Tcl_Interp* interp, Tcl_Obj* method)
{
    Tcl_Obj* objv[2];

    objv[0] = oBgerror;

    objv[1] = Tcl_GetObjResult(interp);

    Tcl_IncrRefCount(objv[1]);

    if (method)
    {
        char* msg = Tcl_GetStringFromObj(objv[1], NULL);
        Tcl_Obj* errorInfo = Tcl_NewObj();
        
        Tcl_AppendObjToObj(errorInfo, objv[1]);
        Tcl_AppendStringsToObj(errorInfo, 
                               "\n    while in the RTI library for FederateAmbassador method\n",
                               NULL);
        Tcl_AppendObjToObj(errorInfo, method);

        Tcl_ObjSetVar2(interp, oErrorInfo, NULL, errorInfo,
                       TCL_GLOBAL_ONLY);
    }
    
    /* Ignore return value; if bgerror throws an error, that's
     * just too bad. */
    Tcl_EvalObjv(interp, 2, objv, TCL_EVAL_GLOBAL | TCL_EVAL_DIRECT);
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


