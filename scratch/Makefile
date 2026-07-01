# ==============================================================================
# Makefile for Bare-metal test binary configuration and builds
# ==============================================================================

REPO_DIR ?= $(abspath $(CURDIR)/..)
RISCV_DIR ?= $(REPO_DIR)/toolchain/xpack-riscv-none-elf-gcc-14.2.0-1
export RISCV ?= $(RISCV_DIR)

# Compiler prefix
RISCV_GCC = $(RISCV)/bin/riscv-none-elf-gcc

# Bare-metal test binary configuration
NUM_WORDS ?= 100
ELF_SRC = $(CURDIR)/sum.S
ELF_OUT = $(CURDIR)/sum.elf
ACCEL_SRC = $(CURDIR)/test_accel.S
ACCEL_ELF = $(CURDIR)/test_accel.elf
FAIL_SUM_SRC = $(CURDIR)/fail_test_sum.S
FAIL_SUM_ELF = $(CURDIR)/fail_test_sum.elf
FAIL_ACCEL_SRC = $(CURDIR)/fail_test_accel.S
FAIL_ACCEL_ELF = $(CURDIR)/fail_test_accel.elf
MEMTEST_SRC = $(CURDIR)/memtest.S
MEMTEST_ELF = $(CURDIR)/memtest.elf
LINKER_SCRIPT = $(CURDIR)/link.ld

.PHONY: all elf accel-elf fail-test-elf fail-test-accel-elf memtest-elf clean-elf

all: elf accel-elf fail-test-elf fail-test-accel-elf memtest-elf

elf: $(ELF_OUT)

$(ELF_OUT): $(ELF_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V bare-metal test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ELF_SRC) -o $(ELF_OUT)

accel-elf: $(ACCEL_ELF)

$(ACCEL_ELF): $(ACCEL_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V bare-metal accelerator test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(ACCEL_SRC) -o $(ACCEL_ELF)

fail-test-elf: $(FAIL_SUM_ELF)

$(FAIL_SUM_ELF): $(FAIL_SUM_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V intentional-failure sum test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(FAIL_SUM_SRC) -o $(FAIL_SUM_ELF)

fail-test-accel-elf: $(FAIL_ACCEL_ELF)

$(FAIL_ACCEL_ELF): $(FAIL_ACCEL_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V intentional-failure accel test binary..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) $(FAIL_ACCEL_SRC) -o $(FAIL_ACCEL_ELF)

memtest-elf: $(MEMTEST_ELF)

$(MEMTEST_ELF): $(MEMTEST_SRC) $(LINKER_SCRIPT)
	@echo "Compiling RISC-V bare-metal memtest binary with NUM_WORDS=$(NUM_WORDS)..."
	$(RISCV_GCC) -march=rv64imafdc -mabi=lp64d -nostartfiles -T $(LINKER_SCRIPT) -DNUM_WORDS=$(NUM_WORDS) $(MEMTEST_SRC) -o $(MEMTEST_ELF)

clean-elf:
	@echo "Cleaning RISC-V test binaries..."
	rm -f $(ELF_OUT) $(ACCEL_ELF) $(FAIL_SUM_ELF) $(FAIL_ACCEL_ELF) $(MEMTEST_ELF)
