# Copyright 2026 Antigravity
# Description: gem5 configuration script for CVA6 RTL co-simulation with L2 Cache.

import m5
import sys
from m5.objects import *
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run CVA6 RTL core in gem5 with L2 cache")
parser.add_argument("--binary", type=str, default="scratch/sum.elf",
                    help="Path to the RISC-V bare-metal ELF binary")
parser.add_argument("--trace", action="store_true",
                    help="Enable VCD tracing of CVA6 RTL core internal signals")
parser.add_argument("--trace-file", type=str, default="m5out/cva6_trace.vcd",
                    help="Filename/path for the output VCD trace file")
parser.add_argument("--rtl-library", type=str, default="cva_verilate/libVcva6_top.so",
                    help="Path to the RTL shared library")
args = parser.parse_args()

# Create the system
system = System()

# Set up clock and voltage domains
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = '50MHz' # CVA6 RTL clock frequency
system.clk_domain.voltage_domain = VoltageDomain()

# Set up the physical memory range (256MB starting at 0x80000000)
system.mem_ranges = [AddrRange(0x80000000, size='256MiB')]

# Create a system crossbar (interconnect)
system.membus = SystemXBar()

# Connect the system port to the crossbar (required by gem5)
system.system_port = system.membus.cpu_side_ports

# Instantiate our custom CVA6 RTL CPU
system.cpu = RtlCPU(rtl_library=args.rtl_library)
if args.trace:
    system.cpu.trace_enable = True
    system.cpu.trace_file = args.trace_file

# --- L2 Cache Setup ---
# Create an L2 crossbar (coherent bus) between CPU and L2 Cache
system.l2bus = L2XBar()

# Connect CVA6 instruction and data ports to the L2 bus
system.cpu.inst_port = system.l2bus.cpu_side_ports
system.cpu.data_port = system.l2bus.cpu_side_ports

# Define the L2 cache class
class L2Cache(Cache):
    size = '256KiB'
    assoc = 8
    tag_latency = 20
    data_latency = 20
    response_latency = 20
    mshrs = 20
    tgts_per_mshr = 12

# Instantiate L2 cache
system.l2cache = L2Cache()

# Connect L2 cache to L2 bus and system membus
system.l2cache.cpu_side = system.l2bus.mem_side_ports
system.l2cache.mem_side = system.membus.cpu_side_ports
# ----------------------

# Set up physical memory and connect it to the crossbar
system.mem_ctrl = SimpleMemory(range=system.mem_ranges[0], latency='10ns')
system.mem_ctrl.port = system.membus.mem_side_ports

# Load the bare-metal binary using RiscvBareMetal workload
system.workload = RiscvBareMetal(bootloader=args.binary)

# Instantiate the simulation root (full_system=True needed for BareMetal workload with standard CPU)
root = Root(full_system=True, system=system)

# Initialize the SimObjects and build the memory image
print("Instantiating SimObjects...")
m5.instantiate()

# Run simulation loop checking for tohost write
tohost_addr = 0x80001000
max_ticks = 500000000000 # 500 billion ticks timeout (25 million cycles)
tick_step = 100000000 # Run 100M ticks at a time (5000 cycles) to minimize host loop overhead
current_tick = 0

exit_cause = "Maximum simulation ticks reached"
tohost_val = 0

while current_tick < max_ticks:
    exit_event = m5.simulate(tick_step)
    current_tick = m5.curTick()
    
    # Read tohost
    tohost_bytes = system.physProxy.read(tohost_addr, 8)
    tohost_val = int.from_bytes(tohost_bytes, 'little')
    
    if tohost_val != 0:
        exit_cause = f"tohost written with value {tohost_val}"
        break
        
    if exit_event.getCause() != "simulate() limit reached":
        exit_cause = exit_event.getCause()
        # Re-read tohost: the store may have been committed just before/during
        # the ebreak exit event (fence + sd pipeline delay in CVA6 RTL).
        tohost_bytes = system.physProxy.read(tohost_addr, 8)
        tohost_val = int.from_bytes(tohost_bytes, 'little')
        break

print("\n============================================")
if tohost_val == 1:
    print(f"CVA6 Simulation finished! tohost = {tohost_val} (exit code = 0)")
    print("SUCCESS: Program completed successfully!")
    sys.exit(0)
elif tohost_val != 0:
    print(f"CVA6 Simulation finished! tohost = {tohost_val} (exit code = {tohost_val >> 1 if tohost_val > 1 else -1})")
    print(f"FAILURE: program exited with tohost code {tohost_val}")
    sys.exit(tohost_val >> 1 if tohost_val > 1 else 1)
else:
    print(f"Simulation ended because: {exit_cause}")
    sys.exit(1)
print(f"Total simulated ticks: {current_tick}")
print("============================================\n")
