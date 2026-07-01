# Copyright 2026 Antigravity
# Description: gem5 configuration script for CVA6 RTL memory test simulation.
# It automatically compiles the memtest.S assembly with the requested number of words
# and runs the RTL core to verify memory read/write correctness.

import os
import sys
import subprocess
import argparse
import m5
from m5.objects import *

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run CVA6 RTL memory test in gem5")
parser.add_argument("--num-words", type=int, default=100,
                    help="Number of 64-bit words to read and write (default: 100)")
parser.add_argument("--use-l2", action="store_true",
                    help="Enable L2 cache in the simulation")
parser.add_argument("--trace", action="store_true",
                    help="Enable VCD tracing of CVA6 RTL core internal signals")
parser.add_argument("--trace-file", type=str, default="m5out/cva6_trace.vcd",
                    help="Filename/path for the output VCD trace file")
args = parser.parse_args()

if args.num_words <= 0:
    print("Error: --num-words must be greater than 0")
    sys.exit(1)

# Paths relative to the workspace root
script_dir = os.path.dirname(os.path.abspath(__file__))
workspace_dir = os.path.abspath(os.path.join(script_dir, "..", ".."))

# 1. Compile the assembly file with the specified number of words
gcc_path = os.path.join(workspace_dir, "toolchain/xpack-riscv-none-elf-gcc-14.2.0-1/bin/riscv-none-elf-gcc")
linker_script = os.path.join(workspace_dir, "scratch/link.ld")
assembly_src = os.path.join(workspace_dir, "scratch/memtest.S")
elf_out = os.path.join(workspace_dir, "scratch/memtest.elf")

if not os.path.exists(gcc_path):
    print(f"Error: RISC-V GCC toolchain not found at {gcc_path}")
    print("Please run 'make toolchain' first to install the toolchain.")
    sys.exit(1)

print(f"Compiling memory test binary with NUM_WORDS={args.num_words}...")
compile_cmd = [
    gcc_path,
    "-march=rv64imafdc",
    "-mabi=lp64d",
    "-nostartfiles",
    "-T", linker_script,
    f"-DNUM_WORDS={args.num_words}",
    assembly_src,
    "-o", elf_out
]

try:
    subprocess.run(compile_cmd, check=True)
    print("Compilation successful.")
except subprocess.CalledProcessError as e:
    print(f"Error: Compilation failed with exit code {e.returncode}")
    sys.exit(1)

# 2. Build the gem5 system
system = System()

# Set up clock and voltage domains
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = '50MHz' # CVA6 RTL clock frequency
system.clk_domain.voltage_domain = VoltageDomain()

# Set up the physical memory range (256MB starting at 0x80000000)
system.mem_ranges = [AddrRange(0x80000000, size='256MB')]

# Create a system crossbar (interconnect)
system.membus = SystemXBar()

# Connect the system port to the crossbar (required by gem5)
system.system_port = system.membus.cpu_side_ports

# Instantiate our custom CVA6 RTL CPU
system.cpu = CVA6RtlCPU()
if args.trace:
    system.cpu.trace_enable = True
    system.cpu.trace_file = args.trace_file

if args.use_l2:
    print("Configuring system WITH L2 Cache...")
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
else:
    print("Configuring system WITHOUT L2 Cache...")
    # Connect CVA6 instruction and data ports directly to the system crossbar
    system.cpu.inst_port = system.membus.cpu_side_ports
    system.cpu.data_port = system.membus.cpu_side_ports

# Set up physical memory and connect it to the crossbar
system.mem_ctrl = SimpleMemory(range=system.mem_ranges[0], latency='10ns')
system.mem_ctrl.port = system.membus.mem_side_ports

# Load the compiled bare-metal binary
system.workload = RiscvBareMetal(bootloader=elf_out)

# Instantiate the simulation root (full_system=True needed for BareMetal workload with standard CPU)
root = Root(full_system=True, system=system)

# Initialize the SimObjects and build the memory image
print("Instantiating SimObjects...")
m5.instantiate()

# Run simulation loop checking for tohost write
tohost_addr = 0x80001000
# Calculate a dynamic timeout based on the number of words to avoid timeout failures on large sizes
max_ticks = 500000000000 + (args.num_words * 100000000)
tick_step = 100000000 # Run 100M ticks at a time (5000 cycles) to minimize host loop overhead
current_tick = 0

exit_cause = "Maximum simulation ticks reached"
tohost_val = 0

print("Starting simulation...")
while current_tick < max_ticks:
    exit_event = m5.simulate(tick_step)
    current_tick = m5.curTick()
    
    # Read tohost
    tohost_bytes = system.physProxy.read(tohost_addr, 8)
    tohost_val = int.from_bytes(tohost_bytes, 'little')
    
    print(f"Simulation ended at Tick: {current_tick}, tohost = {tohost_val}")

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
    print(f"CVA6 Memory Test finished! tohost = {tohost_val} (exit code = 0)")
    print(f"SUCCESS: Successfully wrote and verified {args.num_words} words in RAM!")
    sys.exit(0)
elif tohost_val != 0:
    print(f"CVA6 Memory Test finished! tohost = {tohost_val} (exit code = {tohost_val >> 1 if tohost_val > 1 else -1})")
    print("FAILURE: Memory verification failed or program crashed!")
    sys.exit(tohost_val >> 1 if tohost_val > 1 else 1)
else:
    print(f"Simulation ended because: {exit_cause}")
    sys.exit(1)
print(f"Total simulated ticks: {current_tick}")
print("============================================\n")
