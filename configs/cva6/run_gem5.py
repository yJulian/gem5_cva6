# Copyright 2026 Antigravity
# Description: gem5 configuration script for RISC-V timing CPU simulation (without RTL).

import m5
from m5.objects import *
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run standard RISC-V core in gem5")
parser.add_argument("--binary", type=str, default="scratch/sum.elf",
                    help="Path to the RISC-V bare-metal ELF binary")
args = parser.parse_args()

# Create the system
system = System()
system.mem_mode = 'timing'

# Set up clock and voltage domains
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = '50MHz' # RISC-V CPU clock frequency (matches RTL)
system.clk_domain.voltage_domain = VoltageDomain()

# Set up the physical memory range (256MB starting at 0x80000000)
system.mem_ranges = [AddrRange(0x80000000, size='256MB')]

# Create a system crossbar (interconnect)
system.membus = SystemXBar()

# Connect the system port to the crossbar (required by gem5)
system.system_port = system.membus.cpu_side_ports

# Instantiate standard RISC-V Timing CPU
system.cpu = RiscvTimingSimpleCPU()

# Connect instruction and data ports to the crossbar
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports

# Create interrupt controller (standard for gem5 CPU)
system.cpu.createInterruptController()
system.cpu.createThreads()

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

print(f"Starting standard gem5 Simulation with binary: {args.binary}")

# Run simulation loop checking for tohost write
tohost_addr = 0x80001000
max_ticks = 10000000000 # 10 seconds timeout or equivalent
tick_step = 100000 # Run 100k ticks at a time
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
        break

print("\n============================================")
if tohost_val == 1:
    print(f"gem5 Simulation finished! tohost = {tohost_val} (exit code = 0)")
    print("SUCCESS: Sum of 1 to 9 is correct!")
elif tohost_val != 0:
    print(f"gem5 Simulation finished! tohost = {tohost_val} (exit code = {tohost_val >> 1 if tohost_val > 1 else -1})")
    if tohost_val == 3:
         print("FAILURE: program exited with code 3")
    else:
         print(f"FAILURE: program exited with tohost code {tohost_val}")
else:
    print(f"Simulation ended because: {exit_cause}")
print(f"Total simulated ticks: {current_tick}")
print("============================================\n")
