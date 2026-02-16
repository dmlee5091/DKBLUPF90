cmake_minimum_required(VERSION 3.10)
project(GPBLUP_Project Fortran)

enable_language(Fortran)

# Find OpenMP
find_package(OpenMP REQUIRED)
if(OpenMP_Fortran_FOUND)
    message(STATUS "OpenMP found: ${OpenMP_Fortran_FLAGS}")
endif()

# Set Fortran compiler flags
set(CMAKE_Fortran_FLAGS_DEBUG "-g -O0 -Wall -Wextra -fcheck=all -fbacktrace")
set(CMAKE_Fortran_FLAGS_RELEASE "-O3 -march=native")

# Set default build type to Debug if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

# Fortran compiler configuration for GNU
if(CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -Wall -Wextra -Wno-tabs")
    set(CMAKE_Fortran_FLAGS_RELEASE "-O3 -march=native")
    set(CMAKE_Fortran_FLAGS_DEBUG "-g -O0 -fcheck=all -fbacktrace -Wno-tabs")
endif()

# Set output directories
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Include directories
include_directories(${CMAKE_BINARY_DIR}/modules)

# Source modules from source directory
set(MODULE_SOURCES
    source/M_Kinds.f90
    source/M_Stamp.f90
    source/M_ReadFile.f90
    source/M_StrEdit.f90
    source/M_Variables.f90
    source/M_readpar.f90
    source/M_HashTable.f90
    source/M_PEDHashTable.f90
    source/M_param.f90
    source/Qsort4.f90
)

# Create library from common modules
add_library(gpblup_modules ${MODULE_SOURCES})
set_target_properties(gpblup_modules PROPERTIES
    Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules
)

# ReadFR Program
set(READFR_SOURCES
    ReadFR/ReadFR.f90
)

add_executable(ReadFR ${READFR_SOURCES})
target_link_libraries(ReadFR gpblup_modules)
set_target_properties(ReadFR PROPERTIES
    OUTPUT_NAME ReadFR
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# Install binaries to GPBLUP/bin
install(TARGETS ReadFR
    RUNTIME DESTINATION ${CMAKE_SOURCE_DIR}/bin
)

# Enable testing
enable_testing()

# Enable testing
enable_testing()
