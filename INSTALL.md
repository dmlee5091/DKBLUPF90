# DKBLUPF90 Installation Guide

**Version**: 1.0  
**Last Updated**: February 13, 2026  
**Author**: Dr. DEUKMIN LEE (Hankyong National University)  
**Email**: dhlee@hknu.ac.kr

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Installation Methods](#installation-methods)
4. [Post-Installation Verification](#post-installation-verification)
5. [Troubleshooting](#troubleshooting)
6. [Uninstallation](#uninstallation)

---

## System Requirements

### Minimum Requirements
- **Operating System**: Linux (Ubuntu 18.04+, CentOS 7+, RHEL 7+, Debian 10+)
- **Compiler**: gfortran 4.8 or higher
- **Build Tools**: make, ar (binutils)
- **Disk Space**: 100 MB (source + binaries)
- **Memory**: 4 GB RAM

### Recommended Requirements
- **Operating System**: Ubuntu 20.04 LTS or newer
- **Compiler**: gfortran 9.0 or higher
- **Disk Space**: 500 MB (including test data)
- **Memory**: 8 GB RAM or more (for large datasets)

### Dependencies

#### Required
```bash
# Ubuntu/Debian
sudo apt-get install build-essential gfortran make

# CentOS/RHEL/Fedora
sudo yum install gcc gcc-gfortran make binutils
```

#### Optional (for documentation)
```bash
# Ubuntu/Debian
sudo apt-get install pandoc texlive-xetex texlive-latex-extra

# CentOS/RHEL/Fedora
sudo yum install pandoc texlive-xetex texlive-latex
```

---

## Pre-Installation Checklist

### 1. Check gfortran Installation
```bash
gfortran --version
# Output should show version 4.8 or higher
```

### 2. Verify Build Tools
```bash
make --version
ar --version
```

### 3. Check Available Disk Space
```bash
df -h /usr/local  # For system-wide installation
df -h $HOME       # For user installation
```

### 4. Prepare Installation Directory
```bash
# For user installation (recommended for non-admin users)
mkdir -p ~/.local/bin
mkdir -p ~/.local/lib
mkdir -p ~/.local/include
```

---

## Installation Methods

### Method 1: Automatic Installation (Recommended)

#### System-Wide Installation (requires root)
```bash
cd /home/your_user/DKBLUPF90
sudo ./install.sh
```

**Installation Locations:**
- Libraries: `/usr/local/lib/libdkblupf90.so*`
- Binaries: `/usr/local/bin/ReadFR`
- Headers: `/usr/local/include/dkblupf90/`
- Examples: `/usr/local/share/dkblupf90/examples/`

#### User Directory Installation (no root required)
```bash
cd /home/your_user/DKBLUPF90
PREFIX=$HOME/.local ./install.sh
```

**Installation Locations:**
- Libraries: `~/.local/lib/libdkblupf90.so*`
- Binaries: `~/.local/bin/ReadFR`
- Headers: `~/.local/include/dkblupf90/`

**Add to PATH:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

# Apply changes
source ~/.bashrc
```

### Method 2: Manual Installation

#### Build Library
```bash
cd /home/your_user/DKBLUPF90
make clean        # Clean previous builds
make lib          # Build shared library
```

#### Build ReadFR Program
```bash
make readfr       # Build ReadFR
```

#### Install to Standard Location
```bash
# Create installation directory
sudo mkdir -p /usr/local/lib /usr/local/bin /usr/local/include/dkblupf90

# Copy library
sudo cp lib/libdkblupf90.so* /usr/local/lib/

# Copy binary
sudo cp bin/ReadFR /usr/local/bin/

# Copy headers/modules
sudo cp include/*.mod /usr/local/include/dkblupf90/

# Update library cache
sudo ldconfig
```

#### Install to User Directory
```bash
# Create installation directory
mkdir -p $HOME/.local/lib $HOME/.local/bin $HOME/.local/include/dkblupf90

# Copy files
cp lib/libdkblupf90.so* $HOME/.local/lib/
cp bin/ReadFR $HOME/.local/bin/
cp include/*.mod $HOME/.local/include/dkblupf90/

# Update PATH and LD_LIBRARY_PATH in ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Method 3: Docker Installation (Optional)

```dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y build-essential gfortran make
WORKDIR /tmp
COPY DKBLUPF90 /tmp/DKBLUPF90
WORKDIR /tmp/DKBLUPF90
RUN sudo ./install.sh
ENTRYPOINT ["ReadFR"]
```

---

## Post-Installation Verification

### 1. Verify Installation Locations
```bash
# Check binary
which ReadFR
ReadFR --version 2>&1 | head -1

# Check library
ldconfig -p | grep libdkblupf90
```

### 2. Validate Binary Functionality
```bash
cd /usr/local/share/dkblupf90/examples  # or copy examples to working dir
ReadFR parameter

# Check output file
ls -lh GENO_QC_*.geno
```

### 3. Run Test Suite
```bash
cd /home/your_user/DKBLUPF90
make test
```

### 4. Troubleshoot Library Loading
```bash
# Check library dependency
ldd /usr/local/bin/ReadFR

# Set library path if needed
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ReadFR parameter
```

---

## Troubleshooting

### Issue 1: "gfortran: command not found"
```bash
# Ubuntu/Debian
sudo apt-get install gfortran

# CentOS/RHEL
sudo yum install gcc-gfortran
```

### Issue 2: "libdkblupf90.so: cannot open shared object file"
```bash
# Add library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Or make it permanent (add to ~/.bashrc)
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Update library cache
sudo ldconfig
```

### Issue 3: "Permission denied" during installation
```bash
# Use sudo for system-wide installation
sudo ./install.sh

# Or use user directory installation
PREFIX=$HOME/.local ./install.sh
```

### Issue 4: Compilation errors
```bash
# Check gfortran version
gfortran --version

# Ensure minimum version 4.8
# If version is too old, update:
# Ubuntu/Debian
sudo apt-get install gfortran-9

# CentOS/RHEL
sudo yum install devtoolset-9-gcc-gfortran
scl enable devtoolset-9 bash
```

### Issue 5: "segmentation fault" or runtime errors
```bash
# Rebuild with debug symbols
make clean
CFLAGS="-g -O0" make lib
make readfr

# Run with gdb
gdb --args ReadFR parameter
(gdb) run
```

---

## Uninstallation

### System-Wide Installation
```bash
# Remove binary
sudo rm /usr/local/bin/ReadFR

# Remove library
sudo rm /usr/local/lib/libdkblupf90.so*

# Remove headers
sudo rm -rf /usr/local/include/dkblupf90

# Remove examples
sudo rm -rf /usr/local/share/dkblupf90

# Update library cache
sudo ldconfig
```

### User Directory Installation
```bash
# Remove binary
rm ~/.local/bin/ReadFR

# Remove library
rm ~/.local/lib/libdkblupf90.so*

# Remove headers
rm -rf ~/.local/include/dkblupf90
```

---

## Environment Variables

### Recommended Settings

```bash
# Add to ~/.bashrc or ~/.bash_profile
export DKBLUPF90_HOME=/usr/local  # or $HOME/.local for user installation
export PATH="$DKBLUPF90_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$DKBLUPF90_HOME/lib:$LD_LIBRARY_PATH"
export FFLAGS="-O2 -fPIC"
```

### Verification
```bash
# Test environment variables
echo $DKBLUPF90_HOME
echo $LD_LIBRARY_PATH
which ReadFR
```

---

## Support and Feedback

For installation issues or feedback:
- **Email**: dhlee@hknu.ac.kr
- **Organization**: Hankyong National University
- **Department**: Department of Animal Science

### Reporting Installation Issues

When reporting issues, please provide:
1. Operating system (output of `uname -a`)
2. gfortran version (output of `gfortran --version`)
3. Error messages (complete output)
4. Installation method used
5. Installation directory chosen

---

## License

DKBLUPF90 is released under the MIT License.
See LICENSE file for details.

---

**End of Installation Guide**  
Version 1.0 | February 13, 2026
