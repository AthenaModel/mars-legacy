/***********************************************************************
 *
 * TITLE:
 *	tcl_rti.h
 *
 * AUTHOR:
 *	Will Duquette
 *
 * DESCRIPTION:
 *	JNEM: shark(1) header file
 *
 ***********************************************************************/

#ifndef tcl_rti_h
#define tcl_rti_h

#include <iostream>
#include <sstream>
#include <cassert>

using namespace std;

#include <stdlib.h>
#include <tcl.h>

#include <RTI.hh>
#include <fedtime.hh>
#include <NullFederateAmbassador.hh>

#include "fed_amb.h"

/*
 * Prototypes
 */

/* RTI::Region Tcl Commands */
int  rtiRegion_instanceCmd  (ClientData, Tcl_Interp*, 
                             int, Tcl_Obj* CONST argv[]);

/*
 * Data Types
 */

/* Used to dispatch subcommands. */
struct SubcommandVector {
    char* name;                /* Subcommand name */
    Tcl_ObjCmdProc* proc;      /* Implementing proc */
};

extern "C" {
    extern int Rti_Init(Tcl_Interp*);
}

#endif

