# Makefile for compiling the SystemVerilog FIFO DMA Accelerator into a shared library (.so)

VERILATOR = verilator
VERILATOR_ROOT ?= /usr/local/share/verilator
CXX = g++
CXXFLAGS = -O3 -shared -fPIC -std=c++17

TOP_MODULE = fifo_accel
SV_SRC = fifo_accel.sv
WRAPPER_SRC = fifo_accel_impl.cc
SO_TARGET = libfifo_accel.so

.PHONY: all clean

all: $(SO_TARGET)

$(SO_TARGET): $(SV_SRC) $(WRAPPER_SRC)
	@echo "Verilating SystemVerilog model..."
	$(VERILATOR) --cc -CFLAGS "-fPIC" --Mdir obj_dir -O3 --trace $(SV_SRC)
	@echo "Compiling Verilated sources..."
	$(MAKE) -C obj_dir -f V$(TOP_MODULE).mk
	@echo "Building shared library (.so)..."
	$(CXX) $(CXXFLAGS) -o $(SO_TARGET) \
		-I$(VERILATOR_ROOT)/include \
		-I$(VERILATOR_ROOT)/include/vltstd \
		-Iobj_dir \
		-I../gem5/src/test_objects/fifo \
		$(WRAPPER_SRC) \
		$(VERILATOR_ROOT)/include/verilated.cpp \
		$(VERILATOR_ROOT)/include/verilated_vcd_c.cpp \
		$(VERILATOR_ROOT)/include/verilated_threads.cpp \
		obj_dir/V$(TOP_MODULE)__ALL.a

clean:
	rm -rf obj_dir $(SO_TARGET)
