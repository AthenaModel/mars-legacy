#---------------------------------------------------------------------
# TITLE:
#    Makefile -- shark(1) Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Builds the shark(1) executable.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

TOP_DIR = ../..

BIN = $(TOP_DIR)/bin

# TBD: This makefile needs cleaning up, and some of the mechanism 
# should be shared with other C/C++ Makefiles.

# RTI Definitions
# CPPFLAGS = -DRTI_USES_STD_FSTREAM -DREENTRANT \
#                -DRTI_HAS_THREADS -DPOSIX_PTHREAD_SEMANTICS -g -O3

CPPFLAGS = -DREENTRANT -DPOSIX_PTHREAD_SEMANTICS -g -O3

# LDFLAGS += -g -O3 ${LIB_PATH}
LDFLAGS += -g ${LIB_PATH}


C++ = g++

# TCL Paths
TCL_LIB_DIR  = $(JNEM_TCL_HOME)/lib
TCL_INC_DIR  = $(JNEM_TCL_HOME)/include

DEFINES  = -DJNEM_VERSION=\"$(JNEM_VERSION)\"
RLIBPATH = -Xlinker -rpath -Xlinker $(TCL_LIB_DIR)
LIBPATH  = -L$(TOP_DIR)/src/lib \
	   -L$(TCL_LIB_DIR) $(RLIBPATH)
INCLPATH = -I$(TOP_DIR)/src/include \
	   -I$(TCL_INC_DIR)

TARGETS = $(BIN)/shark 

SHARK_OBJS = \
	shark.o

SHARK_LIBS = \
	-lm -ltcl8.5 -lpthread

all: $(TARGETS)

$(BIN)/shark: $(SHARK_OBJS)
	$(C++) $(LDFLAGS) $(LIBPATH) -o $@ $(SHARK_OBJS) $(SHARK_LIBS)

%.o:%.cpp
	$(C++) -c $(DEFINES) $(CPPFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(BIN)/shark MakeDepends

#-------------------------------------------------------------------
# Dependency checking.
#
# TBD: This should go in src/MakeRules, once we have one.
# DYNAMIC_HEADERS should list any header files that are built
# dynamically.  (Do we still need this?)

depend: MakeDepends

MKDEP = g++ -MM
MKDEPFLAGS = $(DEFINES) $(CPPFLAGS) $(INCLPATH)
DEPEND_SRCS = $(wildcard *.c) $(wildcard *.cpp)

MakeDepends: $(DYNAMIC_HEADERS) $(DEPEND_SRCS)
	@echo Doing make MakeDepends.$(MACH)
	@$(MKDEP) -MF $@ $(MKDEPFLAGS) $(DEPEND_SRCS) 2>MakeDepends.log

include MakeDepends


#-------------------------------------------------------------------
# Standard MakeRules

include $(TOP_DIR)/MakeRules

