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

# RTI Definitions
CPPFLAGS = -DRTI_USES_STD_FSTREAM -DREENTRANT \
                -DRTI_HAS_THREADS -DPOSIX_PTHREAD_SEMANTICS -g -O3

# LDFLAGS += -g -O3 ${LIB_PATH}
LDFLAGS += -g ${LIB_PATH}

C++ = g++

# All of the RTI stuff should really go in the "src" MakeRules.
RTI_ROOT_DIR = $(RTI_HOME)/$(RTI_BUILD_TYPE)
RTI_INC_DIR = $(RTI_ROOT_DIR)/include
RTI_LIB_DIR = $(RTI_ROOT_DIR)/lib

RTI_LIBS =  \
	-lRTI-NG -lfedtime -luserDdm \
	-lpthread

# TCL Paths
TCL_LIB_DIR  = $(JNEM_TCL_HOME)/lib
TCL_INC_DIR  = $(JNEM_TCL_HOME)/include

DEFINES  = -DUSE_TCL_STUBS
RLIBPATH = -Xlinker -rpath -Xlinker $(TCL_LIB_DIR)
LIBPATH  = -L$(TCL_LIB_DIR) \
	   -L$(RTI_LIB_DIR) $(RLIBPATH)
INCLPATH = -I$(TCL_INC_DIR) \
	   -I$(RTI_INC_DIR)


TARGET = $(TOP_DIR)/lib/Rti/libTclRti.so

OBJS = \
	rti.o fed_amb.o region.o

LIBS = \
	-lm -ltclstub8.5 $(RTI_LIBS)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(C++) $(LDFLAGS) $(LIBPATH) -shared -o $@ $(OBJS) $(LIBS)

%.o:%.cpp
	$(C++) -c $(DEFINES) $(CPPFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGET) MakeDepends

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

