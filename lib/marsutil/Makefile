#---------------------------------------------------------------------
#
# Makefile -- Makefile for marsutil(n)
#
# Targets supported:
# 
#    test     Runs the test suite.

# Configuration variables

TOP_DIR=../..

TCLSH=tclsh
FLAGS=

include $(TOP_DIR)/MakeDefs

# Target: test
test:
	$(TCLSH) marsutil.test $(FLAGS)

test_marsmisc:
	$(TCLSH) marsmisc.test $(FLAGS)

test_undostack:
	$(TCLSH) undostack.test $(FLAGS)

include $(TOP_DIR)/MakeRules
