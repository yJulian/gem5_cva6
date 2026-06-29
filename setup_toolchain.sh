#!/bin/bash
# ==============================================================================
# setup_toolchain.sh - Modular environment setup for CVA6 gem5 Co-simulation
# ==============================================================================
# Usage: source setup_toolchain.sh
# ==============================================================================

# Guard: Ensure the script is sourced, not executed directly
check_sourced() {
    if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
        echo "Error: This script must be sourced, not run directly."
        echo "Usage: source setup_toolchain.sh"
        exit 1
    fi
}

# Determine the absolute path to the workspace root
setup_variables() {
    export WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export TOOLCHAIN_DIR="${WORKSPACE_DIR}/toolchain"
    export RISCV="${TOOLCHAIN_DIR}/xpack-riscv-none-elf-gcc-14.2.0-1"
    
    echo "============================================="
    echo "CVA6 gem5 Co-Simulation Setup"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo "============================================="
}

# Initialize and update git submodules if not already done
init_submodules() {
    echo "Checking git submodules..."
    # Check if a key CVA6 source file exists to determine if submodules are checked out
    if [ ! -f "${WORKSPACE_DIR}/ext/cva6/core/cva6.sv" ]; then
        echo "Submodules not detected. Initializing and updating submodules..."
        git submodule update --init --recursive
        echo "Submodules updated."
    else
        echo "Git submodules are already initialized."
    fi
}

# Download and install the RISC-V GCC toolchain if missing
install_toolchain() {
    echo "Checking RISC-V toolchain..."
    if [ ! -f "${RISCV}/bin/riscv-none-elf-gcc" ]; then
        echo "Toolchain not found. Starting download and installation..."
        mkdir -p "${TOOLCHAIN_DIR}"
        
        local ARCHIVE_NAME="xpack-riscv-none-elf-gcc-14.2.0-1-linux-x64.tar.gz"
        local URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-1/${ARCHIVE_NAME}"
        
        cd "${TOOLCHAIN_DIR}"
        if [ ! -f "${ARCHIVE_NAME}" ]; then
            echo "Downloading RISC-V GCC toolchain from GitHub..."
            if command -v wget &> /dev/null; then
                wget "${URL}" -O "${ARCHIVE_NAME}"
            elif command -v curl &> /dev/null; then
                curl -L "${URL}" -o "${ARCHIVE_NAME}"
            else
                echo "Error: Neither wget nor curl is installed. Please install one of them."
                return 1
            fi
        fi
        
        echo "Extracting toolchain..."
        tar -xzf "${ARCHIVE_NAME}"
        rm -f "${ARCHIVE_NAME}"
        cd "${WORKSPACE_DIR}"
        echo "Toolchain installed successfully."
    else
        echo "Toolchain already installed in ${RISCV}"
    fi

    # Add toolchain bin folder to PATH
    if [[ ":$PATH:" != *":${RISCV}/bin:"* ]]; then
        export PATH="${RISCV}/bin:${PATH}"
        echo "Added ${RISCV}/bin to PATH."
    fi
}

# Verilate the CVA6 core if the verilated library does not exist
verilate_cva6() {
    echo "Checking Verilated CVA6 core..."
    local V_LIB="${WORKSPACE_DIR}/cva_verilate/work-ver-core/libVcva6_top.so"
    if [ ! -f "${V_LIB}" ]; then
        echo "Verilated CVA6 library not found. Running verilation..."
        make verilate
    else
        echo "Verilated CVA6 core library already exists."
    fi
}

# Build the gem5 simulator if the binary is missing
build_gem5() {
    echo "Checking gem5 binary..."
    local GEM5_BIN="${WORKSPACE_DIR}/build/RISCV/gem5.opt"
    if [ ! -f "${GEM5_BIN}" ]; then
        echo "gem5 binary not found. Compiling gem5 (this may take a few minutes)..."
        make gem5
    else
        echo "gem5 binary already built."
    fi
}

# Define the 'gem5' command alias
setup_alias() {
    local GEM5_BIN="${WORKSPACE_DIR}/build/RISCV/gem5.opt"
    alias gem5="${GEM5_BIN}"
    echo "Alias 'gem5' registered to point to: ${GEM5_BIN}"
    echo "You can now run 'gem5 configs/cva6/...' directly!"
}

# Main workflow orchestration
main() {
    check_sourced
    setup_variables
    init_submodules
    install_toolchain
    verilate_cva6
    build_gem5
    setup_alias
    echo "============================================="
    echo "Setup Complete! Your environment is ready."
    echo "============================================="
}

main
