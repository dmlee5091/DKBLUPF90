# Makefile for ReadFR

FC = gfortran
FFLAGS = -O2 -g
INCLUDE_DIR = ../build
LIB_DIR = ../lib
TARGET = ReadFR

.PHONY: all clean

all: $(TARGET)

$(TARGET): ReadFR.f90
	$(FC) $(FFLAGS) -I$(INCLUDE_DIR) ReadFR.f90 $(LIB_DIR)/libdkblupf90.a -o $(TARGET)
	mv $(TARGET) ../bin/
clean:
	rm -f $(TARGET) *.o *.mod
