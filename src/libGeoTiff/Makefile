#---------------------------------------------------------------------
# TITLE:
#
# AUTHOR:
#
# DESCRIPTION:
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

TOP_DIR = ../..

include $(TOP_DIR)/MakeDefs
#
# TCL Paths
TCL_LIB_DIR  = $(MARS_TCL_HOME)/lib
TCL_INC_DIR  = $(MARS_TCL_HOME)/include

DEFINES  = \
	-DUSE_TCL_STUBS

RLIBPATH = -Xlinker -rpath -Xlinker $(TCL_LIB_DIR)

LIBPATH  = \
	-L$(TCL_LIB_DIR) \
	-ljpeg -lm -lz   \
	-lpthread        \
	 $(RLIBPATH)

INCLPATH = \
	-I$(TCL_INC_DIR) 

LIBS = $(TOP_DIR)/src/lib/libgeotiff.a $(TOP_DIR)/src/lib/libtiff.a

# Compilation Flags
CFLAGS = -fPIC -g -O -Wall

# Include Directory

CC  = g++

TARGET = $(TOP_DIR)/lib/marsgui/libGeoTiff.so

OBJS = \
	geoTiffRead.o


all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) $(LIBPATH) -shared -o $@ $(OBJS) $(LIBS)

%.o:%.cpp
	$(CC) -fPIC -c $(DEFINES) $(CFLAGS) $(INCLPATH) $< -o $@

clean:
	rm -f *.o $(TARGET) MakeDepends


