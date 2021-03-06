#---------------------------------------------------------------------
# TITLE:
#    Makefile -- Mars Binary Code Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    This Makefile defines the following targets:
#
#    all       Build all binary code in all subdirectories.
#    clean     Deletes all build products in all subdirectories.
#    subs      Builds all subdirectories.
#    <subdir>  Rebuilds the specified subdirectory from scratch.
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

TOP_DIR = ..

# Standard definitions are found in the following file.

include $(TOP_DIR)/MakeDefs

SRCLIBDIR = $(TOP_DIR)/src/lib

# Subdirectories to build
#
# libGeoTiff isn't yet supported on Windows.

LINUXSUBS   = libGeotrans libGeostars libTiff libGTiff
WINSUBS     = libGeotrans libGeostars libTiff libGTiff
OTHERCLEANS = clean-Marsbin

ifeq ($(MARS_OS),linux)
    SUBS = $(LINUXSUBS)
else ifeq ($(MARS_OS),win)
    SUBS = $(WINSUBS)
else 
    SUBS =
endif

.PHONY: all

all: $(SRCLIBDIR) subs Marsbin

#---------------------------------------------------------------------
# Target: <subdir> -- Rebuilds individual subdirectories

.PHONY: $(SUBS) Marsbin clean-Marsbin

$(SUBS):
	cd $@ ; make clean ; make

Marsbin:
	cd $@ ; chmod +x configure ; ./configure --with-tcl=$(MARS_TCL_HOME)/lib --prefix $(realpath $(TOP_DIR)) --exec-prefix $(realpath $(TOP_DIR))
	cd $@ ; make clean ; make ; make install

clean-Marsbin:
	cd Marsbin ; if test -f Makefile ; then make clean ; fi

#---------------------------------------------------------------------
# Target: lib -- creates the lib directory

$(SRCLIBDIR):
	mkdir $(SRCLIBDIR)


#---------------------------------------------------------------------
# Standard Rules

include $(TOP_DIR)/MakeRules

#---------------------------------------------------------------------
# Making Subdirectories

include MakeSubs



