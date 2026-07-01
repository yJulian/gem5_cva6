# ==============================================================================
# verilate.mk - Custom rule to verilate CVA6 core with main-repo top-level wrapper
# ==============================================================================
# This file is included dynamically by GNU Make when compiling inside ext/cva6.
# It leverages the source file lists and variables defined in ext/cva6/Makefile.

.PHONY: verilate-core

verilate-core:
	@echo "[Verilator] Building CVA6 Core Model using custom rule"
	export TARGET_CFG=$(TARGET_CFG) && export CVA6_REPO_DIR=$(CVA6_REPO_DIR) && \
	$(verilator) --no-timing ../../cva_verilate/verilator_config_extra.vlt verilator_config.vlt \
                    -f core/Flist.cva6 \
                    core/cva6_rvfi.sv \
                    ../../cva_verilate/cva6_top.sv \
                    $(filter-out %.vhd, $(ariane_pkg)) \
                    $(filter-out core/fpu_wrap.sv, $(filter-out %.vhd, $(filter-out %_config_pkg.sv, $(src)))) \
                    +define+$(defines)$(if $(TRACE_FAST),+VM_TRACE)$(if $(TRACE_COMPACT),+VM_TRACE+VM_TRACE_FST) \
                    $(if $(TRACE_COMPACT), --trace-fst) \
                    $(if $(TRACE_FAST), --trace) \
                    +incdir+corev_apu/axi_node \
                    --unroll-count 256 \
                    -Wall \
                    -Werror-PINMISSING \
                    -Werror-IMPLICIT \
                    -Wno-fatal \
                    -Wno-PINCONNECTEMPTY \
                    -Wno-ASSIGNDLY \
                    -Wno-DECLFILENAME \
                    -Wno-UNUSED \
                    -Wno-UNOPTFLAT \
                    -Wno-BLKANDNBLK \
                    -Wno-style \
                    --cc \
                    $(list_incdir) --top-module cva6_top \
                    --threads-dpi none \
                    $(if $(verilator_threads), --threads $(verilator_threads)) \
                    -CFLAGS "-fPIC" \
                    --Mdir work-ver-core -O3
	cd work-ver-core && $(MAKE) -j${NUM_JOBS} -f Vcva6_top.mk
	g++ -O3 -shared -fPIC -o ../../cva_verilate/libVcva6_top.so \
		-I/usr/local/share/verilator/include \
		-I/usr/local/share/verilator/include/vltstd \
		-Iwork-ver-core \
		-I../../gem5/src/cpu/rtl/axi \
		$(if $(TRACE_FAST),-DVM_TRACE=1) \
		$(if $(TRACE_COMPACT),-DVM_TRACE=1 -DVM_TRACE_FST=1) \
		../../cva_verilate/cva6_rtl_core_impl.cc \
		-Wl,--whole-archive work-ver-core/libVcva6_top.a work-ver-core/libverilated.a -Wl,--no-whole-archive
