#!/bin/bash
# DKBLUPF90 Installation Script
# This script automatically installs the DKBLUPF90 library and ReadFR program

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Installation directory (default: /usr/local)
PREFIX="${PREFIX:-/usr/local}"
INSTALL_BIN="${PREFIX}/bin"
INSTALL_LIB="${PREFIX}/lib"
INSTALL_INCLUDE="${PREFIX}/include/dkblupf90"

# Check if running as root for system-wide installation
check_permissions() {
    if [ "$PREFIX" = "/usr/local" ] || [[ "$PREFIX" == /usr/* ]]; then
        if [ "$EUID" -ne 0 ]; then
            print_warning "System-wide installation requires root privileges"
            print_info "Either run with sudo or set PREFIX to a user directory:"
            print_info "  PREFIX=\$HOME/.local ./install.sh"
            exit 1
        fi
    fi
}

# Check for required dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v gfortran &> /dev/null; then
        print_error "gfortran is not installed"
        print_info "Install it with: sudo apt-get install gfortran (Ubuntu/Debian)"
        print_info "               or: sudo yum install gcc-gfortran (CentOS/RHEL)"
        exit 1
    fi
    
    if ! command -v ar &> /dev/null; then
        print_error "ar (binutils) is not installed"
        exit 1
    fi
    
    print_info "✓ gfortran found: $(gfortran --version | head -n1)"
    print_info "✓ ar found"
}

# Display installation information
display_info() {
    echo ""
    echo "======================================================================"
    echo "  DKBLUPF90 Library and ReadFR Program Installation"
    echo "======================================================================"
    echo ""
    echo "Installation directories:"
    echo "  PREFIX:      $PREFIX"
    echo "  Executables: $INSTALL_BIN"
    echo "  Libraries:   $INSTALL_LIB"
    echo "  Headers:     $INSTALL_INCLUDE"
    echo ""
    echo "======================================================================"
    echo ""
}

# Build the library and program
build_project() {
    print_info "Building DKBLUPF90 library..."
    
    # Clean any previous builds
    make clean 2>/dev/null || true
    
    # Build library
    if ! make lib; then
        print_error "Failed to build library"
        exit 1
    fi
    
    print_info "✓ Library built successfully"
    
    # Build ReadFR program
    print_info "Building ReadFR program..."
    if ! make readfr; then
        print_error "Failed to build ReadFR program"
        exit 1
    fi
    
    print_info "✓ ReadFR program built successfully"
}

# Install files to the system
install_files() {
    print_info "Installing files..."
    
    # Create installation directories
    mkdir -p "$INSTALL_BIN"
    mkdir -p "$INSTALL_LIB"
    mkdir -p "$INSTALL_INCLUDE"
    
    # Install executables
    print_info "Installing executables to $INSTALL_BIN"
    install -m 755 bin/ReadFR "$INSTALL_BIN/"
    
    # Install libraries
    print_info "Installing libraries to $INSTALL_LIB"
    install -m 644 lib/libdkblupf90.a "$INSTALL_LIB/"
    install -m 755 lib/libdkblupf90.so "$INSTALL_LIB/"
    
    # Install header files (module files)
    print_info "Installing module files to $INSTALL_INCLUDE"
    install -m 644 include/*.mod "$INSTALL_INCLUDE/"
    
    print_info "✓ Files installed successfully"
}

# Update library cache
update_ldconfig() {
    if [ "$EUID" -eq 0 ] && command -v ldconfig &> /dev/null; then
        print_info "Updating library cache..."
        echo "$INSTALL_LIB" > /etc/ld.so.conf.d/dkblupf90.conf
        ldconfig
        print_info "✓ Library cache updated"
    else
        print_warning "Skipping ldconfig (not running as root)"
        print_info "Add $INSTALL_LIB to your LD_LIBRARY_PATH:"
        print_info "  export LD_LIBRARY_PATH=$INSTALL_LIB:\$LD_LIBRARY_PATH"
    fi
}

# Create example parameter file
create_examples() {
    print_info "Creating example files in $PREFIX/share/dkblupf90/examples..."
    
    EXAMPLE_DIR="$PREFIX/share/dkblupf90/examples"
    mkdir -p "$EXAMPLE_DIR"
    
    # Copy example parameter files if they exist
    if [ -d "ReadFR/check" ]; then
        cp -f ReadFR/check/parameter "$EXAMPLE_DIR/" 2>/dev/null || true
    fi
    
    # Copy documentation
    cp -f *.md "$EXAMPLE_DIR/" 2>/dev/null || true
    cp -f ReadFR/*.md "$EXAMPLE_DIR/" 2>/dev/null || true
    
    print_info "✓ Examples and documentation copied"
}

# Create uninstall script
create_uninstall() {
    print_info "Creating uninstall script..."
    
    cat > "$PREFIX/bin/uninstall-dkblupf90.sh" << 'EOF'
#!/bin/bash
# DKBLUPF90 Uninstall Script

PREFIX="${PREFIX:-/usr/local}"

echo "Uninstalling DKBLUPF90..."

rm -f "$PREFIX/bin/ReadFR"
rm -f "$PREFIX/lib/libdkblupf90.a"
rm -f "$PREFIX/lib/libdkblupf90.so"
rm -rf "$PREFIX/include/dkblupf90"
rm -rf "$PREFIX/share/dkblupf90"
rm -f /etc/ld.so.conf.d/dkblupf90.conf

if command -v ldconfig &> /dev/null; then
    ldconfig
fi

rm -f "$PREFIX/bin/uninstall-dkblupf90.sh"

echo "DKBLUPF90 has been uninstalled."
EOF
    
    chmod +x "$PREFIX/bin/uninstall-dkblupf90.sh"
    print_info "✓ Uninstall script created at $PREFIX/bin/uninstall-dkblupf90.sh"
}

# Display post-installation message
post_install_message() {
    echo ""
    echo "======================================================================"
    echo -e "${GREEN}  Installation completed successfully!${NC}"
    echo "======================================================================"
    echo ""
    echo "Installed components:"
    echo "  • ReadFR program: $INSTALL_BIN/ReadFR"
    echo "  • Static library: $INSTALL_LIB/libdkblupf90.a"
    echo "  • Shared library: $INSTALL_LIB/libdkblupf90.so"
    echo "  • Module files:   $INSTALL_INCLUDE/"
    echo "  • Examples:       $PREFIX/share/dkblupf90/examples/"
    echo ""
    echo "Usage:"
    echo "  ReadFR parameter_file"
    echo ""
    echo "Documentation:"
    echo "  Example files and guides are available in:"
    echo "  $PREFIX/share/dkblupf90/examples/"
    echo ""
    echo "To uninstall:"
    echo "  sudo $PREFIX/bin/uninstall-dkblupf90.sh"
    echo ""
    
    if [ "$PREFIX" != "/usr/local" ] && [[ "$PREFIX" != /usr/* ]]; then
        echo "NOTE: You may need to add $INSTALL_BIN to your PATH:"
        echo "  export PATH=$INSTALL_BIN:\$PATH"
        echo "  export LD_LIBRARY_PATH=$INSTALL_LIB:\$LD_LIBRARY_PATH"
        echo ""
        echo "Add these lines to your ~/.bashrc for permanent effect."
        echo ""
    fi
    
    echo "======================================================================"
}

# Main installation process
main() {
    display_info
    check_permissions
    check_dependencies
    build_project
    install_files
    update_ldconfig
    create_examples
    create_uninstall
    post_install_message
}

# Run main function
main
