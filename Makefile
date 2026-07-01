# ==============================================================================
# Master Makefile for CVA6 gem5 Co-simulation Project
# ==============================================================================

# Parallel compilation jobs
JOBS ?= $(shell nproc)

# Path to the RISC-V GCC toolchain (portable)
RISCV_DIR = $(CURDIR)/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1
export RISCV = $(RISCV_DIR)

# Bare-metal test binary output configurations (for run configs)
ELF_OUT = $(CURDIR)/scratch/sum.elf
ACCEL_ELF = $(CURDIR)/scratch/test_accel.elf
FAIL_SUM_ELF = $(CURDIR)/scratch/fail_test_sum.elf
FAIL_ACCEL_ELF = $(CURDIR)/scratch/fail_test_accel.elf

# gem5 targets and paths
GEM5_OPT = build/RISCV/gem5.opt

.PHONY: all toolchain submodules verilate elf gem5 run-rtl run-rtl-l2 run-accel-l2 run-gem5 clean clean-gem5 clean-cva6 clean-elf help run-test-accel accel-elf accel-so fail-test-elf fail-test-accel-elf run-fail-test run-fail-accel

# Default target builds everything
all: toolchain submodules verilate elf gem5

# 1. Submodules Target: initializes/updates all git submodules
submodules:
	@echo "Checking/updating git submodules..."
	git submodule update --init --recursive

# 2. Toolchain Target: installs RISC-V GCC toolchain if not present
toolchain:
	@if [ ! -d "$(RISCV_DIR)" ]; then \
		echo "Toolchain not found. Starting download and installation..."; \
		mkdir -p toolchain; \
		cd toolchain && \
		URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-1/xpack-riscv-none-elf-gcc-14.2.0-1-linux-x64.tar.gz" && \
		ARCHIVE="xpack-riscv-none-elf-gcc-14.2.0-1-linux-x64.tar.gz" && \
		if [ ! -f "$$ARCHIVE" ]; then \
			echo "Downloading RISC-V GCC Toolchain..."; \
			if command -v wget >/dev/null 2>&1; then \
				wget "$$URL" -O "$$ARCHIVE"; \
			elif command -v curl >/dev/null 2>&1; then \
				curl -L "$$URL" -o "$$ARCHIVE"; \
			else \
				echo "Error: Neither wget nor curl is installed. Please install one of them."; \
				exit 1; \
			fi; \
		fi && \
		echo "Extracting toolchain..." && \
		tar -xzf "$$ARCHIVE" && \
		rm -f "$$ARCHIVE"; \
	else \
		echo "Toolchain already installed in $(RISCV_DIR)."; \
	fi

# 3. Verilate Target: compiles/verilates CVA6 RTL core using Verilator
verilate: toolchain
	$(MAKE) -C cva_verilate verilate JOBS=$(JOBS) RISCV=$(RISCV)

# 4. Elf Target: builds the bare-metal RISC-V binary from sum.S
elf: toolchain
	$(MAKE) -C scratch elf RISCV=$(RISCV)

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

accel-elf: toolchain
	$(MAKE) -C scratch accel-elf RISCV=$(RISCV)

accel-so:
	@echo "Building accelerator shared library..."
	$(MAKE) -C accelerator

fail-test-elf: toolchain
	$(MAKE) -C scratch fail-test-elf RISCV=$(RISCV)

fail-test-accel-elf: toolchain
	$(MAKE) -C scratch fail-test-accel-elf RISCV=$(RISCV)

# 6d. Run Intentional Failure Test (sum): verifies FAILURE path for sum test
run-fail-test: fail-test-elf gem5
	@echo "Running INTENTIONAL FAILURE TEST (sum) -- Expected: FAILURE (tohost=3)"
	./$(GEM5_OPT) configs/cva6/run_fail_test.py --binary $(FAIL_SUM_ELF)

# 6e. Run Intentional Failure Test (accel): verifies FAILURE path for accelerator test
run-fail-accel: fail-test-accel-elf accel-so gem5
	@echo "Running INTENTIONAL FAILURE TEST (accel) -- Expected: FAILURE (tohost=3)"
	./$(GEM5_OPT) configs/cva6/run_fail_accel.py --binary $(FAIL_ACCEL_ELF)

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
	$(MAKE) -C cva_verilate clean-cva6

clean-elf:
	$(MAKE) -C scratch clean-elf
	$(MAKE) -C accelerator clean

# 9. Help Target: prints usage instructions
help:
	@echo "Available Makefile targets:"
	@echo "  make               - Build everything: toolchain, submodules, verilated cva6, test elf, gem5"
	@echo "  make submodules    - Initialize and recursively update git submodules"
	@echo "  make toolchain     - Download and install the portable RISC-V GCC toolchain"
	@echo "  make verilate      - Verilate the CVA6 core RTL using Verilator"
	@echo "  make elf           - Compile the bare-metal assembly test in scratch/sum.S to ELF"
	@echo "  make gem5          - Build the gem5.opt simulator binary with SCons"
	@echo "  make run-rtl       - Run the gem5 co-simulation using the Verilated CVA6 core"
	@echo "  make run-rtl-l2    - Run the gem5 co-simulation with CVA6 RTL core and L2 cache"
	@echo "  make run-accel-l2  - Run the gem5 co-simulation with CVA6 RTL core, L2 cache, and FIFO Accelerator"
	@echo "  make run-fail-test  - Run the intentional FAILURE test for sum (verifies failure detection)"
	@echo "  make run-fail-accel - Run the intentional FAILURE test for accel (verifies failure detection)"
	@echo "  make run-gem5      - Run the standard gem5 TimingSimpleCPU simulation"
	@echo "  make clean         - Delete all built files and build directories"
	@echo "  make help          - Display this help message"