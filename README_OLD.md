# DKBLUPF90 - Fortran GBLUP Library and ReadFR Program

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Fortran](https://img.shields.io/badge/Fortran-90%2B-purple.svg)](https://fortran-lang.org/)

High-performance Fortran library and SNP quality control program for genomic data processing.

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Usage Examples](#usage-examples)
- [Documentation](#documentation)
- [License](#license)

## Overview

DKBLUPF90 is a high-performance Fortran library and program for quality control and preprocessing of large-scale genomic SNP data. The main program **ReadFR** reads Illumina FinalReport files and performs SNP quality control, converting data into formats suitable for GBLUP analysis.

### Features
- **O(1) time complexity** hash table-based fast search
- **Large-scale data processing**: Handles hundreds of thousands of SNPs and thousands of animals simultaneously
- **Various QC options**: GC Score, Call Rate, Cluster Separation, etc.
- **Multiple chip version support**: Compatible with V1, V2, and other SNP chip versions
- **Memory efficient**: Dynamic memory management with optimized data structures
- **Flexible configuration**: Parameter file-based settings

## Key Features

### 1. ReadFR Program
- Illumina FinalReport file parsing
- Animal-level and SNP-level quality control
- Flexible QC threshold configuration
- GENO file generation (BLUPF90 compatible)
- Detailed QC report generation

### 2. DKBLUPF90 Library
- **M_HashTable**: Generic hash table (numeric string keys)
- **M_PEDHashTable**: Pedigree-specific hash table
- **M_Variables**: Common data type definitions
- **M_ReadFile**: File I/O utilities
- **M_StrEdit**: String processing functions
- **M_ReadPar**: Parameter file parser
- **Qsort4**: Fast sorting algorithm

## System Requirements

### Required
- **OS**: Linux (Ubuntu, CentOS, RHEL, etc.)
- **Compiler**: gfortran 4.8 or higher
- **Build Tools**: make, ar (binutils)
- **Memory**: Minimum 4GB RAM (8GB+ recommended for large datasets)

### Optional
- **PDF Generation**: pandoc, texlive-xetex (for document generation)

## Installation

### Automatic Installation (Recommended)

System-wide installation (requires root):
```bash
sudo ./install.sh
```

User directory installation:
```bash
PREFIX=$HOME/.local ./install.sh
```

### Manual Installation

```bash
# Build library only
make lib

# Build ReadFR program
make readfr

# Build test programs (optional)
make testprog
```

Verify installation:
```bash
which ReadFR
ls -lh /usr/local/lib/libdkblupf90.*
```

## Quick Start

### 1. Prepare Parameter File

```bash
cp /usr/local/share/dkblupf90/examples/parameter my_parameter
nano my_parameter
```

Example parameter file:
```
COMMENT ==========================================
COMMENT ReadFR Parameter File
COMMENT ==========================================

COMMENT PED file (pedigree data)
PEDFile
/path/to/PED_Total.txt

COMMENT SNP FinalReport (Illumina output)
SNPFile
/path/to/FinalReport.txt
ANIMAL-ARN 2
SNP_Name 1
Chr 10
Position 11
Allele1-AB 13
Allele2-AB 14
GC_Score 27 0.65
R-Intensity 25 0.4 2.0
GT_Score 29 0.50
Cluster_Sep 30 0.30

COMMENT MAP file (SNP position information)
MAPFile
/path/to/MAP.txt

COMMENT Output prefix
OutputPrefix
output

COMMENT QC Thresholds
AnimalCallRate 0.95
SNPCallRate 0.90
```

### 2. Run ReadFR

```bash
ReadFR my_parameter
```

### 3. Check Output Files

```bash
# QC passed GENO file with auto-generated name (date and sequence number)
ls output_20260213_*.geno

# Example output files (auto-generated with date YYYYMMDD and sequence):
# output_20260213_00.geno  (first run on Feb 13)
# output_20260213_01.geno  (second run same day)
# output_20260214_00.geno  (first run on Feb 14)
```

## Project Structure

```
DKBLUPF90/
├── source/              # Library source code
│   ├── M_Kinds.f90
│   ├── M_Variables.f90
│   ├── M_HashTable.f90
│   ├── M_PEDHashTable.f90
│   ├── M_ReadFile.f90
│   ├── M_StrEdit.f90
│   ├── M_ReadPar.f90
│   ├── M_Stamp.f90
│   └── Qsort4.f90
├── ReadFR/              # ReadFR program
│   ├── ReadFR.f90
│   └── check/           # Test data
├── bin/                 # Executable files
├── lib/                 # Libraries
├── include/             # Header (module) files
├── build/               # Build artifacts
├── Makefile
├── install.sh           # Installation script
└── USER_MANUAL.pdf      # Complete user guide
```

## Usage Examples

### Example 1: Basic QC Execution

```bash
ReadFR parameter_file
```

### Example 2: Stringent QC Criteria

Modify parameter file:
```
GC_Score 27 0.70        # Changed from 0.65
AnimalCallRate 0.98     # Changed from 0.95
SNPCallRate 0.95        # Changed from 0.90
```

### Example 3: Multiple Chip Versions

```bash
# Chip V1 data
ReadFR parameter_v1

# Chip V2 data
ReadFR parameter_v2

# Check auto-generated output files (with automatic date and sequence numbering)
ls output_v1_*.geno
ls output_v2_*.geno

# Merge results
cat output_v1_20260213_00.geno output_v2_20260213_00.geno > merged_GENO.txt
```

### Example 4: Using Library in Fortran Program

```fortran
program MyProgram
    use M_HashTable
    use M_PEDHashTable
    
    type(HashTable) :: ht
    type(PEDHashTable) :: ped_ht
    
    ! Create hash tables
    call ht_create(ht, 1009)
    call pht_create(ped_ht, 1009)
    
    ! Use tables...
    
    ! Cleanup
    call ht_free(ht)
    call pht_free(ped_ht)
end program
```

Compile:
```bash
gfortran -I/usr/local/include/dkblupf90 my_program.f90 \
         -L/usr/local/lib -ldkblupf90 -o my_program
```

## Documentation

### User Guides
- **HASH_TABLE_GUIDE.md**: Hash table usage
- **PED_HASH_TABLE_GUIDE.md**: Pedigree hash table guide
- **QC_THRESHOLDS_USAGE.md**: QC threshold configuration

### ReadFR Documentation
- **ReadFR/SNP_QC_GUIDE.md**: SNP quality control details
- **ReadFR/PIPELINE_GUIDE.md**: Large-scale analysis pipeline
- **ReadFR/QC_EVALUATION_REPORT.md**: QC evaluation report

### Complete User Manual
- **USER_MANUAL.pdf**: Comprehensive guide with all features

Documentation location after installation:
```bash
/usr/local/share/dkblupf90/examples/
```

## Performance

### Benchmark (Intel Core i7, 16GB RAM)

| Data Scale | Animals | SNPs | Processing Time | Memory |
|-----------|---------|------|-----------------|--------|
| Small | 500 | 50K | ~5s | ~200MB |
| Medium | 2,000 | 60K | ~15s | ~500MB |
| Large | 10,000 | 70K | ~2m | ~2GB |
| Very Large | 50,000 | 70K | ~10m | ~8GB |

## Troubleshooting

### gfortran not found

```bash
# Ubuntu/Debian
sudo apt-get install gfortran

# CentOS/RHEL
sudo yum install gcc-gfortran
```

### Library not found

```bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### Permission denied

```bash
# Install in user directory
PREFIX=$HOME/.local ./install.sh
```

### Parameter file error

1. Verify file paths are correct
2. Check column numbers match FinalReport format
3. Verify Unix line endings (vs Windows)

```bash
dos2unix parameter_file
```

## Uninstallation

```bash
sudo /usr/local/bin/uninstall-dkblupf90.sh
```

## Applications

- **GBLUP (Genomic BLUP)**: Genomic evaluation
- **Genomic Selection**: Breeding value prediction
- **Relationship Matrix Construction**: G matrix generation
- **SNP Data Preprocessing**: QC and format conversion
- **Large-scale Genomic Analysis**: Pipeline development

## Citation

If you use this software in your research, please cite:

```
Lee, D.H. (2026). DKBLUPF90: High-Performance Fortran Library for Genomic Data Processing.
```

## License

This project is distributed under the MIT License.

## Contributing

Bug reports, feature suggestions, and code contributions are welcome!

## Support

For questions or issues, please submit a GitHub issue or contact the project maintainer.

---

**Version**: 1.0.0  
**Last Updated**: February 13, 2026  
**Author**: DH Lee
