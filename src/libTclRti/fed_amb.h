/***********************************************************************
 *
 * TITLE:
 *	fed_amb.h
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	JNEM: shark(1) header file, RTI FedAmb class
 *
 ***********************************************************************/

#ifndef fed_amb_h
#define fed_amb_h

/* Federate Ambassador class; calls Tcl code as needed. */
class FedAmb : public NullFederateAmbassador 
{
private:
    Tcl_Interp* interp;
    char* faCmd;
    RTI::RTIambassador* rtiAmb;
    Tcl_Obj* faObj;
    Tcl_Obj* methodQueue;
    Tcl_HashTable* intClassNameHash;
    Tcl_HashTable* intParmNameHash;
    Tcl_HashTable* objAttrNameHash;
    Tcl_HashTable* objClassNameHash;

public:
    FedAmb();

    virtual ~FedAmb()
        throw(RTI::FederateInternalError); 

    void setFaName(
        Tcl_Interp* theInterp,
        const char* theFaName,
        RTI::RTIambassador* theRtiAmb);

    void evalQueue()
        throw();

    void qm(
        Tcl_Obj* method)
        throw();

    void qmWithO(
        Tcl_Obj* method,
        Tcl_Obj* o)
        throw();

    void qmWithS(
        Tcl_Obj* method,
        const char* s)
        throw();

    void qmWithSS(
        Tcl_Obj* method,
        const char* s1,
        const char* s2)
        throw();

    void qmWithSH(
        Tcl_Obj* method,
        const char* s,
        RTI::Handle h)
        throw();

    void qmWithHAs(
        Tcl_Obj* method,
        RTI::ObjectHandle h,
        const RTI::AttributeHandleSet& ahs)
        throw();

    void qmWithT(
        Tcl_Obj* method,
        const RTI::FedTime& t)
        throw();

    void clearCache();

    Tcl_Obj* getAttributeTclObj(
        RTI::AttributeHandle    theAttribute,
        RTI::ObjectClassHandle  theObject);

    Tcl_Obj* getParameterTclObj(
        RTI::ParameterHandle         theParameter,
        RTI::InteractionClassHandle  theInteraction);

    Tcl_Obj* getIntClassTclObj(
        RTI::InteractionClassHandle  theInteraction);

    Tcl_Obj* getObjClassTclObj(
        RTI::ObjectClassHandle  theObject);

    ////////////////////////////////////
    // Federation Management Services //
    ////////////////////////////////////

    virtual void synchronizationPointRegistrationSucceeded (
        const char *label) // supplied C4)
        throw (
            RTI::FederateInternalError);
                
    virtual void synchronizationPointRegistrationFailed (
        const char *label) // supplied C4)
        throw (
            RTI::FederateInternalError);
                
    virtual void announceSynchronizationPoint (
        const char *label, // supplied C4
        const char *tag)   // supplied C4
        throw (
            RTI::FederateInternalError);
                
    virtual void federationSynchronized (
        const char *label) // supplied C4)
        throw (
            RTI::FederateInternalError);
                
    virtual void initiateFederateSave (
        const char *label) // supplied C4
        throw (
            RTI::UnableToPerformSave,
            RTI::FederateInternalError);
                
    virtual void federationSaved ()
        throw (
            RTI::FederateInternalError);
                
    virtual void federationNotSaved ()
        throw (
            RTI::FederateInternalError);
                
    virtual void requestFederationRestoreSucceeded (
        const char *label) // supplied C4
        throw (
            RTI::FederateInternalError);
                
    virtual void requestFederationRestoreFailed (
        const char *label) // supplied C4
        throw (
            RTI::FederateInternalError);
                
    virtual void requestFederationRestoreFailed (
        const char *label,
        const char *reason) // supplied C4
        throw (
            RTI::FederateInternalError);
                
    virtual void federationRestoreBegun ()
        throw (
            RTI::FederateInternalError);
                
    virtual void initiateFederateRestore (
        const char      *label,      // supplied C4
        RTI::FederateHandle handle)  // supplied C1
        throw (
            RTI::SpecifiedSaveLabelDoesNotExist,
            RTI::CouldNotRestore,
            RTI::FederateInternalError);
                
    virtual void federationRestored ()
        throw (
            RTI::FederateInternalError);
                
    virtual void federationNotRestored ()
        throw (
            RTI::FederateInternalError);
		

    /////////////////////////////////////
    // Declaration Management Services //
    /////////////////////////////////////
		
    virtual void startRegistrationForObjectClass (
        RTI::ObjectClassHandle theClass) // supplied C1
        throw (
            RTI::ObjectClassNotPublished,
            RTI::FederateInternalError);
		
    virtual void stopRegistrationForObjectClass (
        RTI::ObjectClassHandle theClass) // supplied C1
        throw (
            RTI::ObjectClassNotPublished,
            RTI::FederateInternalError);
		
    virtual void turnInteractionsOn (
        RTI::InteractionClassHandle theHandle) // supplied C1
        throw (
            RTI::InteractionClassNotPublished,
            RTI::FederateInternalError);
		
    virtual void turnInteractionsOff (
        RTI::InteractionClassHandle theHandle) // supplied C1
        throw (
            RTI::InteractionClassNotPublished,
            RTI::FederateInternalError);


    ////////////////////////////////
    // Object Management Services //
    ////////////////////////////////

    virtual void discoverObjectInstance (
        RTI::ObjectHandle theObject,           // supplied C1
        RTI::ObjectClassHandle theObjectClass, // supplied C1
        const char *theObjectName)             // supplied C4
        throw (
            RTI::CouldNotDiscover,
            RTI::ObjectClassNotKnown,
            RTI::FederateInternalError);

    void setup_receiveInteraction(
        RTI::InteractionClassHandle theInteraction,            // supplied C1
        const RTI::ParameterHandleValuePairSet& theParameters, // supplied C4
        const char *theTag,                                    // supplied C4
        Tcl_Obj* objv[]);

    virtual void receiveInteraction (
        RTI::InteractionClassHandle theInteraction,            // supplied C1
        const RTI::ParameterHandleValuePairSet& theParameters, // supplied C4
        const RTI::FedTime& theTime,                           // supplied C4
        const char *theTag,                                    // supplied C4
        RTI::EventRetractionHandle theHandle)                  // supplied C1
        throw (
            RTI::InteractionClassNotKnown,
            RTI::InteractionParameterNotKnown,
            RTI::InvalidFederationTime,
            RTI::FederateInternalError);
                
    virtual void receiveInteraction (
        RTI::InteractionClassHandle theInteraction,            // supplied C1
        const RTI::ParameterHandleValuePairSet& theParameters, // supplied C4
        const char *theTag)                                    // supplied C4
        throw (
            RTI::InteractionClassNotKnown,
            RTI::InteractionParameterNotKnown,
            RTI::FederateInternalError);

    void setup_ReflectAttributeValues(
        RTI::ObjectHandle theObject,
        const RTI::AttributeHandleValuePairSet& theAttributes,
        const char* theTag,
        Tcl_Obj* objv[]);
                
    virtual void reflectAttributeValues (
        RTI::ObjectHandle theObject,                           // supplied C1
        const RTI::AttributeHandleValuePairSet& theAttributes, // supplied C4
        const RTI::FedTime& theTime,                           // supplied C1
        const char *theTag,                                    // supplied C4
        RTI::EventRetractionHandle theHandle)                  // supplied C1
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::FederateOwnsAttributes,
            RTI::InvalidFederationTime,
            RTI::FederateInternalError);
                
    virtual void reflectAttributeValues (
        RTI::ObjectHandle theObject,                           // supplied C1
        const RTI::AttributeHandleValuePairSet& theAttributes, // supplied C4
        const char *theTag)                                    // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::FederateOwnsAttributes,
            RTI::FederateInternalError);

    void setup_removeObjectInstance(
        RTI::ObjectHandle theObject,          // supplied C1
        const char *theTag,                   // supplied C4
        Tcl_Obj* objv[]);

    virtual void removeObjectInstance (
        RTI::ObjectHandle theObject,          // supplied C1
        const RTI::FedTime& theTime,          // supplied C4
        const char *theTag,                   // supplied C4
        RTI::EventRetractionHandle theHandle) // supplied C1
        throw (
            RTI::ObjectNotKnown,
            RTI::InvalidFederationTime,
            RTI::FederateInternalError);
		
    virtual void removeObjectInstance (
        RTI::ObjectHandle theObject, // supplied C1
        const char *theTag)          // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::FederateInternalError);
		
    virtual void provideAttributeValueUpdate (
        RTI::ObjectHandle theObject,                  // supplied C1
        const RTI::AttributeHandleSet& theAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::AttributeNotOwned,
            RTI::FederateInternalError);

    virtual void turnUpdatesOnForObjectInstance (
        RTI::ObjectHandle theObject,                  // supplied C1
        const RTI::AttributeHandleSet& theAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotOwned,
            RTI::FederateInternalError);
		
    virtual void turnUpdatesOffForObjectInstance (
        RTI::ObjectHandle theObject,                  // supplied C1
        const RTI::AttributeHandleSet& theAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotOwned,
            RTI::FederateInternalError);

    ///////////////////////////////////
    // Ownership Management Services //
    ///////////////////////////////////

    virtual void attributeOwnershipAcquisitionNotification (
        RTI::ObjectHandle theObject,                      // supplied C1
        const RTI::AttributeHandleSet& securedAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::AttributeAcquisitionWasNotRequested,
            RTI::AttributeAlreadyOwned,
            RTI::AttributeNotPublished,
            RTI::FederateInternalError);

    virtual void attributeOwnershipUnavailable (
        RTI::ObjectHandle theObject,                  // supplied C1
        const RTI::AttributeHandleSet& theAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::AttributeAlreadyOwned,
            RTI::AttributeAcquisitionWasNotRequested,
            RTI::FederateInternalError);


    virtual void confirmAttributeOwnershipAcquisitionCancellation (
        RTI::ObjectHandle theObject,                  // supplied C1
        const RTI::AttributeHandleSet& theAttributes) // supplied C4
        throw (
            RTI::ObjectNotKnown,
            RTI::AttributeNotKnown,
            RTI::AttributeAlreadyOwned,
            RTI::AttributeAcquisitionWasNotCanceled,
            RTI::FederateInternalError);

    //////////////////////////////
    // Time Management Services //
    //////////////////////////////
                
    virtual void timeRegulationEnabled (
        const  RTI::FedTime& theFederateTime) // supplied C4
        throw (
            RTI::InvalidFederationTime,
            RTI::EnableTimeRegulationWasNotPending,
            RTI::FederateInternalError);
                
    virtual void timeConstrainedEnabled (
        const RTI::FedTime& theFederateTime) // supplied C4
        throw (
            RTI::InvalidFederationTime,
            RTI::EnableTimeConstrainedWasNotPending,
            RTI::FederateInternalError);
                
    virtual void timeAdvanceGrant (
        const RTI::FedTime& theTime) // supplied C4
        throw (
            RTI::InvalidFederationTime,
            RTI::TimeAdvanceWasNotInProgress,
            RTI::FederateInternalError);
};

#endif

