# ==============================================================================
# Makefile for Bare-metal test binary configuration and builds
# ==============================================================================

REPO_DIR ?= $(abspath $(CURDIR)/..)
RISCV_DIR ?= $(REPO_DIR)/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1
export RISCV ?= $(RISCV_DIR)

# Compiler prefix
RISCV_GCC = $(RISCV)/bin/riscv-none-elf-gcc

# Bare-metal test binary configuration
ELF_SRC = $(CURDIR)/sum.S
ELF_OUT = $(CURDIR)/sum.elf
ACCEL_SRC = $(CURDIR)/test_accel.S
ACCEL_ELF = $(CURDIR)/test_accel.elf
LINKER_SCRIPT = $(CURDIR)/link.ld

.PHONY: all elf accel-elf clean-elf

all: elf accel-elf

elf: $(ELF_OUT)

$(ELF_OUT): $(ELF_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V bare-metal test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ELF_SRC) -o $(ELF_OUT)

accel-elf: $(ACCEL_ELF)

$(ACCEL_ELF): $(ACCEL_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V bare-metal accelerator test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ACCEL_SRC) -o $(ACCEL_ELF)

clean-elf:
	@echo "Cleaning RISC-V test binaries..."
	rm -f $(ELF_OUT) $(ACCEL_ELF)
