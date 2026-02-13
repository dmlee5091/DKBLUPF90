# Makefile for DKBLUPF90 Library Package
# Fortran Compiler
FC = gfortran
AR = ar
ARFLAGS = rcs

# Compiler Flags
FFLAGS = -O2 -g -fPIC -J$(BUILDDIR) -I$(BUILDDIR)
LDFLAGS = -shared

# Directories
SRCDIR = source
BUILDDIR = build
LIBDIR = lib
INCDIR = include
BINDIR = bin

# Library name
LIBNAME = libdkblupf90
STATIC_LIB = $(LIBDIR)/$(LIBNAME).a
SHARED_LIB = $(LIBDIR)/$(LIBNAME).so

# Source files (의존성 순서대로)
SOURCES = \
	$(SRCDIR)/M_Kinds.f90 \
	$(SRCDIR)/M_Stamp.f90 \
	$(SRCDIR)/M_Variables.f90 \
	$(SRCDIR)/M_StrEdit.f90 \
	$(SRCDIR)/M_ReadFile.f90 \
	$(SRCDIR)/Qsort4.f90 \
	$(SRCDIR)/M_readpar.f90 \
	$(SRCDIR)/M_HashTable.f90 \
	$(SRCDIR)/M_PEDHashTable.f90

# Object files
OBJECTS = $(patsubst $(SRCDIR)/%.f90,$(BUILDDIR)/%.o,$(SOURCES))

# Module files
MODULES = $(patsubst $(SRCDIR)/%.f90,$(BUILDDIR)/%.mod,$(SOURCES))

# ReadFR program
READFR_DIR = ReadFR
READFR_SRC = $(READFR_DIR)/ReadFR.f90
READFR_OBJ = $(BUILDDIR)/ReadFR.o
READFR_EXE = $(BINDIR)/ReadFR

# Test programs (auto-detect)
TEST_SRC = $(wildcard test_*.f90)
TEST_EXE = $(patsubst %.f90,%,$(TEST_SRC))

# Default target - 라이브러리와 ReadFR 모두 빌드
all: directories $(STATIC_LIB) $(SHARED_LIB) $(READFR_EXE)

# Build only library (라이브러리만 빌드)
lib: directories $(STATIC_LIB) $(SHARED_LIB)

# Build ReadFR program
readfr: all

# Build test program
testprog: all
	@if [ -z "$(TEST_SRC)" ]; then \
		echo "No test_*.f90 files found. Skipping test build."; \
	else \
		echo "Building test programs..."; \
		for src in $(TEST_SRC); do \
			$(FC) -I$(INCDIR) -o $${src%.f90} $$src -L$(LIBDIR) -ldkblupf90 -Wl,-rpath,$(PWD)/$(LIBDIR); \
		done; \
	fi

# Create necessary directories
directories:
	@mkdir -p $(BUILDDIR) $(LIBDIR) $(INCDIR) $(BINDIR)

# Build static library
$(STATIC_LIB): $(OBJECTS)
	@echo "Creating static library: $@"
	$(AR) $(ARFLAGS) $@ $^
	@cp $(BUILDDIR)/*.mod $(INCDIR)/ 2>/dev/null || true
	@echo "Static library created successfully!"

# Build shared library
$(SHARED_LIB): $(OBJECTS)
	@echo "Creating shared library: $@"
	$(FC) $(LDFLAGS) -o $@ $^
	@cp $(BUILDDIR)/*.mod $(INCDIR)/ 2>/dev/null || true
	@echo "Shared library created successfully!"

# Compile individual modules
$(BUILDDIR)/M_Kinds.o: $(SRCDIR)/M_Kinds.f90
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_Stamp.o: $(SRCDIR)/M_Stamp.f90
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_Variables.o: $(SRCDIR)/M_Variables.f90
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_StrEdit.o: $(SRCDIR)/M_StrEdit.f90 $(BUILDDIR)/M_Kinds.o
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_ReadFile.o: $(SRCDIR)/M_ReadFile.f90 $(BUILDDIR)/M_Variables.o
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/Qsort4.o: $(SRCDIR)/Qsort4.f90
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_readpar.o: $(SRCDIR)/M_readpar.f90 $(BUILDDIR)/M_Kinds.o $(BUILDDIR)/M_Variables.o $(BUILDDIR)/M_StrEdit.o $(BUILDDIR)/M_ReadFile.o
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_HashTable.o: $(SRCDIR)/M_HashTable.f90 $(BUILDDIR)/M_Kinds.o $(BUILDDIR)/M_Variables.o
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(BUILDDIR)/M_PEDHashTable.o: $(SRCDIR)/M_PEDHashTable.f90 $(BUILDDIR)/M_Kinds.o $(BUILDDIR)/M_Variables.o
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -c $< -o $@

$(READFR_OBJ): $(READFR_SRC) $(OBJECTS) | directories
	@echo "Compiling $<"
	$(FC) $(FFLAGS) -I$(INCDIR) -c $< -o $@

$(READFR_EXE): $(READFR_OBJ) $(STATIC_LIB)
	@echo "Linking $@"
	$(FC) -o $@ $(READFR_OBJ) -L$(LIBDIR) -ldkblupf90 -Wl,-rpath,$(PWD)/$(LIBDIR)


# Install (optional)
install: all
	@echo "Installing libraries and modules..."
	@mkdir -p /usr/local/lib /usr/local/include/dkblupf90
	@cp $(STATIC_LIB) $(SHARED_LIB) /usr/local/lib/
	@cp $(INCDIR)/*.mod /usr/local/include/dkblupf90/
	@echo "Installation complete!"

# Clean build files


clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILDDIR) $(LIBDIR) $(INCDIR) $(TEST_EXE)
	@echo "Clean complete!"

# Clean and rebuild
rebuild: clean all

# Test build (builds test executable)
test: testprog

# Show build information
info:
	@echo "=== Build Information ==="
	@echo "Compiler: $(FC)"
	@echo "Flags: $(FFLAGS)"
	@echo "Source directory: $(SRCDIR)"
	@echo "Build directory: $(BUILDDIR)"
	@echo "Library directory: $(LIBDIR)"
	@echo "Static library: $(STATIC_LIB)"
	@echo "Shared library: $(SHARED_LIB)"
	@echo "Source files:"
	@echo "$(SOURCES)" | tr ' ' '\n'

# Generate documentation
docs:
	@echo "Generating PDF documentation..."
	@if command -v pandoc >/dev/null 2>&1; then \
		pandoc USER_MANUAL.md -o USER_MANUAL.pdf --pdf-engine=xelatex --toc --number-sections \
		-V geometry:margin=1in -V fontsize=11pt -V documentclass=article; \
		echo "✓ USER_MANUAL.pdf generated"; \
	else \
		echo "Error: pandoc not found. Run: sudo apt-get install pandoc texlive-xetex"; \
		exit 1; \
	fi

.PHONY: all directories clean rebuild test install info readfr testprog docs
