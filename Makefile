# ==============================================================================
# Wrapper Makefile in the root that delegates to cva_verilate/Makefile
# ==============================================================================

.PHONY: all toolchain submodules verilate elf gem5 run-rtl run-rtl-l2 run-accel-l2 run-gem5 clean clean-gem5 clean-cva6 clean-elf help run-test-accel accel-elf accel-so

all toolchain submodules verilate elf gem5 run-rtl run-rtl-l2 run-accel-l2 run-gem5 clean clean-gem5 clean-cva6 clean-elf help run-test-accel accel-elf accel-so:
	$(MAKE) -C cva_verilate $@