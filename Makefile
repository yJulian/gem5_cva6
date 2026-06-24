# ==============================================================================
# Makefile for CVA6 RTL Co-simulation in gem5
# ==============================================================================
# Coordinates:
# 1. Installation of the RISC-V GCC toolchain (optional, automated)
# 2. Verilation of the CVA6 RISC-V core (targets rv64imafdc by default)
# 3. Compilation of bare-metal assembly tests (e.g. scratch/sum.S)
# 4. Compilation of the gem5 simulator with CVA6 integration
# 5. Running the co-simulation or standard timing CPU simulation
# ==============================================================================

# Parallel compilation jobs
JOBS ?= $(shell nproc)

# Path to the RISC-V GCC toolchain (portable)
RISCV_DIR = $(CURDIR)/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1
export RISCV = $(RISCV_DIR)

# Compiler prefix
RISCV_GCC = $(RISCV)/bin/riscv-none-elf-gcc

# Bare-metal test binary configuration
ELF_SRC = scratch/sum.S
ELF_OUT = scratch/sum.elf
ACCEL_SRC = scratch/test_accel.S
ACCEL_ELF = scratch/test_accel.elf
LINKER_SCRIPT = scratch/link.ld

# gem5 targets and paths
GEM5_OPT = build/RISCV/gem5.opt

.PHONY: all toolchain submodules verilate elf gem5 run-rtl run-rtl-l2 run-accel-l2 run-gem5 clean clean-gem5 clean-cva6 clean-elf help run-test-accel accel-elf accel-so

# Default target builds everything
all: toolchain submodules verilate elf gem5

# 1. Submodules Target: initializes/updates all git submodules
submodules:
	@echo "Checking/updating git submodules..."
	git submodule update --init --recursive

# 2. Toolchain Target: installs RISC-V GCC toolchain if not present
toolchain:
	@if [ ! -d "$(RISCV_DIR)" ]; then \
		echo "Installing RISC-V toolchain via install_toolchain.sh..."; \
		./install_toolchain.sh; \
	else \
		echo "Toolchain already installed in $(RISCV_DIR)."; \
	fi

# 3. Verilate Target: compiles/verilates CVA6 RTL core using Verilator
verilate: toolchain submodules
	@echo "Verilating CVA6 core RTL..."
	$(MAKE) -C cva6 verilate-core RISCV=$(RISCV) NUM_JOBS=$(JOBS) TRACE_FAST=1

# 4. Elf Target: builds the bare-metal RISC-V binary from sum.S
elf: $(ELF_OUT)

$(ELF_OUT): $(ELF_SRC) $(LINKER_SCRIPT) toolchain
	@echo "Compiling RISC-V bare-metal test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ELF_SRC) -o $(ELF_OUT)

# 5. gem5 Target: compiles the gem5 simulator with CVA6 CPU SimObject support
gem5: verilate
	@echo "Building gem5 RISC-V opt binary (includes CVA6 RTL CPU)..."
	scons -C gem5 $(GEM5_OPT) -j$(JOBS)

# 6. Run RTL Target: runs co-simulation using the verilated CVA6 core
run-rtl: elf gem5
	@echo "Running gem5 simulation with CVA6 RTL Core..."
	./$(GEM5_OPT) configs/cva6/run_rtl.py --binary $(ELF_OUT)

# 6a. Run RTL with L2 Cache Target: runs co-simulation using CVA6 and gem5 L2 Cache
run-rtl-l2: elf gem5
	@echo "Running gem5 simulation with CVA6 RTL Core and L2 Cache..."
	./$(GEM5_OPT) configs/cva6/run_rtl_l2.py --binary $(ELF_OUT)

# 6b. Run RTL Accel Target: runs co-simulation with CVA6 and the FIFO Accelerator
run-test-accel: accel-elf accel-so gem5
	@echo "Running gem5 simulation with CVA6 and FIFO Accelerator..."
	./$(GEM5_OPT) configs/cva6/run_accel.py --binary $(ACCEL_ELF)

# 6c. Run RTL Accel with L2 Cache Target: runs co-simulation with CVA6, L2 Cache, and FIFO Accelerator
run-accel-l2: accel-elf accel-so gem5
	@echo "Running gem5 simulation with CVA6, L2 Cache, and FIFO Accelerator..."
	./$(GEM5_OPT) configs/cva6/run_accel_l2.py --binary $(ACCEL_ELF)

accel-elf: $(ACCEL_ELF)

$(ACCEL_ELF): $(ACCEL_SRC) $(LINKER_SCRIPT) toolchain
	@echo "Compiling RISC-V bare-metal accelerator test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ACCEL_SRC) -o $(ACCEL_ELF)

accel-so:
	@echo "Building accelerator shared library..."
	$(MAKE) -C accelerator

# 7. Run gem5 Target: runs standard timing simulation in gem5 (no RTL)
run-gem5: elf gem5
	@echo "Running gem5 simulation with TimingSimpleCPU..."
	./$(GEM5_OPT) configs/cva6/run_gem5.py --binary $(ELF_OUT)

# 8. Clean Target: cleans gem5 build, verilated cva6 build, and compiled test binaries
clean: clean-gem5 clean-cva6 clean-elf
	@echo "Cleanup completed."

clean-gem5:
	@echo "Cleaning gem5 build directories..."
	rm -rf build/

clean-cva6:
	@echo "Cleaning CVA6 verilate artifacts..."
	$(MAKE) -C cva6 clean
	rm -rf cva6/work-ver-core

clean-elf:
	@echo "Cleaning RISC-V test binaries..."
	rm -f $(ELF_OUT) $(ACCEL_ELF)
	$(MAKE) -C accelerator clean

# 9. Help Target: prints usage instructions
help:
	@echo "Available Makefile targets:"
	@echo "  make               - Build everything: toolchain, submodules, verilated cva6, test elf, gem5"
	@echo "  make submodules    - Initialize and recursively update git submodules"
	@echo "  make toolchain     - Download and install the portable RISC-V GCC toolchain"
	@echo "  make verilate      - Verilate the CVA6 core RTL using Verilator"
	@echo "  make elf           - Compile the bare-metal assembly test in $(ELF_SRC) to ELF"
	@echo "  make gem5          - Build the gem5.opt simulator binary with SCons"
	@echo "  make run-rtl       - Run the gem5 co-simulation using the Verilated CVA6 core"
	@echo "  make run-rtl-l2    - Run the gem5 co-simulation with CVA6 RTL core and L2 cache"
	@echo "  make run-accel-l2  - Run the gem5 co-simulation with CVA6 RTL core, L2 cache, and FIFO Accelerator"
	@echo "  make run-gem5      - Run the standard gem5 TimingSimpleCPU simulation"
	@echo "  make clean         - Delete all built files and build directories"
	@echo "  make help          - Display this help message"
