# ==============================================================================
# Makefile for CVA6 RTL Co-simulation in gem5 (Verilator tasks only)
# ==============================================================================

# Parallel compilation jobs
JOBS ?= $(shell nproc)

# Path to repository root
REPO_DIR ?= $(abspath $(CURDIR)/..)

# Path to the RISC-V GCC toolchain (portable)
RISCV_DIR ?= $(REPO_DIR)/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1
export RISCV ?= $(RISCV_DIR)

.PHONY: verilate clean-cva6

# Verilate Target: compiles/verilates CVA6 RTL core using Verilator
verilate:
	@echo "Verilating CVA6 core RTL..."
	$(MAKE) -C $(REPO_DIR)/ext/cva6 -f Makefile -f $(CURDIR)/verilate.mk verilate-core \
		RISCV=$(RISCV) \
		NUM_JOBS=$(JOBS) \
		TRACE_FAST=1 \
		verilator="verilator"
	rm -rf $(CURDIR)/work-ver-core
	ln -s $(REPO_DIR)/ext/cva6/work-ver-core $(CURDIR)/work-ver-core

clean-cva6:
	@echo "Cleaning CVA6 verilate artifacts..."
	$(MAKE) -C $(REPO_DIR)/ext/cva6 clean
	rm -rf $(REPO_DIR)/ext/cva6/work-ver-core
	rm -rf $(CURDIR)/work-ver-core
	rm -f $(CURDIR)/libVcva6_top.so
