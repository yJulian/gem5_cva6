#!/bin/bash
# Description: Download and install the portable RISC-V GCC toolchain.

set -e

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="${SCRIPT_DIR}/toolchain"
URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-1/xpack-riscv-none-elf-gcc-14.2.0-1-linux-x64.tar.gz"
ARCHIVE="xpack-riscv-none-elf-gcc-14.2.0-1-linux-x64.tar.gz"

echo "Creating toolchain directory at ${TOOLCHAIN_DIR}..."
mkdir -p "${TOOLCHAIN_DIR}"

cd "${TOOLCHAIN_DIR}"

if [ -d "xpack-riscv-none-elf-gcc-14.2.0-1" ]; then
    echo "Toolchain already installed in ${TOOLCHAIN_DIR}/xpack-riscv-none-elf-gcc-14.2.0-1, skipping."
    exit 0
fi

if [ -f "${ARCHIVE}" ]; then
    echo "Archive ${ARCHIVE} already exists, skipping download."
else
    echo "Downloading RISC-V GCC Toolchain..."
    if command -v wget &> /dev/null; then
        wget "${URL}" -O "${ARCHIVE}"
    elif command -v curl &> /dev/null; then
        curl -L "${URL}" -o "${ARCHIVE}"
    else
        echo "Error: Neither wget nor curl is installed. Please install one of them."
        exit 1
    fi
fi

echo "Extracting toolchain..."
tar -xzf "${ARCHIVE}"

echo "Cleaning up archive..."
rm -f "${ARCHIVE}"

echo "Toolchain installed successfully in ${TOOLCHAIN_DIR}/xpack-riscv-none-elf-gcc-14.2.0-1"
