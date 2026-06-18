# Copyright 2026 Antigravity
# Description: gem5 configuration script for CVA6 RTL co-simulation.

import m5
from m5.objects import *
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run CVA6 RTL core in gem5")
parser.add_argument("--binary", type=str, default="scratch/sum.elf",
                    help="Path to the RISC-V bare-metal ELF binary")
parser.add_argument("--trace", action="store_true",
                    help="Enable VCD tracing of CVA6 RTL core internal signals")
parser.add_argument("--trace-file", type=str, default="m5out/cva6_trace.vcd",
                    help="Filename/path for the output VCD trace file")
args = parser.parse_args()

# Create the system
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

# Connect CVA6 instruction and data ports to the crossbar
system.cpu.inst_port = system.membus.cpu_side_ports
system.cpu.data_port = system.membus.cpu_side_ports

# Set up physical memory and connect it to the crossbar
system.mem_ctrl = SimpleMemory(range=system.mem_ranges[0], latency='10ns')
system.mem_ctrl.port = system.membus.mem_side_ports

# Load the bare-metal binary using RiscvBareMetal workload
system.workload = RiscvBareMetal(bootloader=args.binary)

# Instantiate the simulation root
root = Root(full_system=False, system=system)

# Initialize the SimObjects and build the memory image
print("Instantiating SimObjects...")
m5.instantiate()

print(f"Starting CVA6 RTL Simulation with binary: {args.binary}")
exit_event = m5.simulate()

print(f"Simulation ended at tick {m5.curTick()} because: {exit_event.getCause()}")
