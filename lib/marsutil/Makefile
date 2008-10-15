#---------------------------------------------------------------------
#
# Makefile -- Makefile for marsutil(n)
#
# Targets supported:
# 
#    test     Runs the test suite.

# Configuration variables

TOP_DIR=../..

TCLSH=tclsh8.5
export TCLLIBPATH = $(MARS_TESTLIBPATH)

include $(TOP_DIR)/MakeDefs

# Target: test
test:
	@echo "TCLLIBPATH=$(TCLLIBPATH)"
	$(TCLSH) marsutil.test

include $(TOP_DIR)/MakeRules
