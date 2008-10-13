#---------------------------------------------------------------------
# TITLE:
#    Makefile -- Mars Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    This Makefile defines the following targets:
#
#    	all          Builds Mars code and documentation.
#    	docs         Builds Mars documentation
#    	test         Runs Mars unit tests.
#    	clean        Deletes all build products
#       build        Builds code and documentation from scratch,
#                    and runs tests.
#       cmbuild      Official build; requires MARS_VERSION=x.y
#                    on make command line.  Builds code and 
#                    documentation from scratch, and tags it with
#                    the version number in the repository.
#
#    For normal development, this Makefile is usually executed as
#    follows:
#
#        make
#
#    Optionally, this is followed by
#
#        make test
#
#    For official builds (whether development or release), this
#    sequence is used:
#
#        make build                          
#
#    Resolve any problems until "make build" runs cleanly. Then,
#
#        make MARS_VERSION=x.y cmbuild
#
#    NOTE: Before doing the official build, docs/build.ehtml should be
#    updated with the build notes for the current version.
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

# Set the root of the directory tree.
TOP_DIR = .

.PHONY: all docs test build cmbuild clean

#---------------------------------------------------------------------
# Shared Definitions

include MakeDefs

#---------------------------------------------------------------------
# Target: all
#
# Build code and documentation.

all: docs

#---------------------------------------------------------------------
# Target: docs
#
# Build development documentation.

docs: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+              Building Documentation               +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	cd $(TOP_DIR)/docs ; make

#---------------------------------------------------------------------
# Target: test
#
# Run all unit tests.

test: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+               Running Unit Tests                  +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	cd $(TOP_DIR)/test ; make

#---------------------------------------------------------------------
# Target: build
#
# Build code and documentation from scratch, and run tests.

build: clean docs test

#---------------------------------------------------------------------
# Target: clean
#
# Delete all build products.

clean: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+                     Cleaning                      +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""
	cd $(TOP_DIR)/test ; make clean
	cd $(TOP_DIR)/docs ; make clean

#---------------------------------------------------------------------
# Shared Rules

include MakeRules



