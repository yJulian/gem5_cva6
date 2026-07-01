# Copyright 2026 Antigravity
# Description: gem5 configuration script to run a bare-metal PCIe test on the custom CVA6 RTL Core.

import argparse
import sys
import os
from os import path

# Import classic gem5 objects
import m5
from m5.objects import *
from m5.util import fatal, warn

from gem5.utils.requires import requires
from gem5.isas import ISA

# Ensure we are using the RISC-V target
requires(isa_required=ISA.RISCV)

# Parse command line arguments
parser = argparse.ArgumentParser(
    description="Run a bare-metal PCIe test on the CVA6 RTL core in gem5"
)
parser.add_argument(
    "--binary",
    type=str,
    default="scratch/pcie_test.elf",
    help="Path to the RISC-V bare-metal ELF binary",
)
parser.add_argument(
    "--trace",
    action="store_true",
    help="Enable VCD tracing of CVA6 RTL core internal signals",
)
parser.add_argument(
    "--trace-file",
    type=str,
    default="m5out/cva6_trace.vcd",
    help="Filename/path for the output VCD trace file",
)
parser.add_argument(
    "--rtl-library",
    type=str,
    default="cva_verilate/libVcva6_top.so",
    help="Path to the RTL shared library",
)
args = parser.parse_args()

# Create the top-level System
system = System()
system.mem_mode = "timing"

# Set up clock and voltage domains (Matching the 50MHz CVA6 RTL frequency)
system.voltage_domain = VoltageDomain(voltage="1.0V")
system.clk_domain = SrcClockDomain(
    clock="50MHz", voltage_domain=system.voltage_domain
)

# Set up physical memory range starting at 0x80000000
system.mem_ranges = [AddrRange(0x80000000, size="256MB")]

# Create crossbars (interconnects)
system.membus = SystemXBar()
system.iobus = IOXBar()

# Connect system port to the crossbar (required by gem5)
system.system_port = system.membus.cpu_side_ports

# Instantiate our custom CVA6 RTL CPU
# Note: Platform code requires system.cpu to be an iterable list
system.cpu = [RtlCPU(rtl_library=args.rtl_library)]
system.cpu[0].cpu_id = 0

# Set up BaseCPU parameters for ThreadContext and Interrupt routing
system.cpu[0].mmu = RiscvMMU()
system.cpu[0].interrupts = [RiscvInterrupts()]
system.cpu[0].isa = [RiscvISA()]
system.cpu[0].decoder = [RiscvDecoder(isa=system.cpu[0].isa[0])]

if args.trace:
    system.cpu[0].trace_enable = True
    system.cpu[0].trace_file = args.trace_file

# Connect CVA6 instruction and data ports to the main coherent bus
system.cpu[0].inst_port = system.membus.cpu_side_ports
system.cpu[0].data_port = system.membus.cpu_side_ports

# Set up physical memory (RAM) and connect it to the main bus
system.mem_ctrl = SimpleMemory(range=system.mem_ranges[0], latency="10ns")
system.mem_ctrl.port = system.membus.mem_side_ports

# Set up the HiFive Platform devices (PLIC, CLINT, UART console, and PCIe)
system.platform = HiFive()

# RTCCLK (Set to 100MHz for simulation time progression)
system.platform.rtc = RiscvRTC(frequency=Frequency("100MHz"))
system.platform.clint.int_pin = system.platform.rtc.int_pin

# Connect the platform's PCI/IO system to the incoherent I/O bus
system.iobus.cpu_side_ports = system.platform.pci_host.up_request_port()
system.iobus.mem_side_ports = system.platform.pci_host.up_response_port()

system.platform.pci_bus.cpu_side_ports = (
    system.platform.pci_host.down_request_port()
)
system.platform.pci_bus.default = (
    system.platform.pci_host.down_response_port()
)
system.platform.pci_bus.config_error_port = (
    system.platform.pci_host.config_error.pio
)

# Instantiate a simple PCIe Device (Intel GbE e1000 network card)
# We place it at device 1, function 0
system.pcie_device = IGbE_e1000(pci_dev=1, pci_func=0)

# Connect the PCIe device to the platform's PCIe controller and bus
system.pcie_device.upstream = system.platform.pci_host
system.pcie_device.pio = system.platform.pci_bus.mem_side_ports
system.pcie_device.dma = system.platform.pci_bus.cpu_side_ports

# Bridge between main system bus and IO bus (for MMIO registers)
system.bridge = Bridge(delay="50ns")
system.bridge.mem_side_port = system.iobus.cpu_side_ports
system.bridge.cpu_side_port = system.membus.mem_side_ports

# Build bridge ranges explicitly, including the PCIe address ranges
bridge_ranges = system.platform._off_chip_ranges()
bridge_ranges.append(
    AddrRange(
        system.platform.pci_host.conf_base,
        size=system.platform.pci_host.conf_size,
    )
)
bridge_ranges.append(
    AddrRange(system.platform.pci_host.pci_mem_base, size="1GiB")
)
bridge_ranges.append(
    AddrRange(system.platform.pci_host.pci_pio_base, size="16MiB")
)
system.bridge.ranges = bridge_ranges

# Attach and configure all platform devices
system.platform.attachOnChipIO(system.membus)
system.platform.attachOffChipIO(system.iobus)
system.platform.attachPlic()
system.platform.setNumCores(1)

# Cache line size setting required for system components
system.cache_line_size = 64

# Load bare-metal PCIe test binary
system.workload = RiscvBareMetal(bootloader=args.binary)

# Instantiate simulation Root
root = Root(full_system=True, system=system)

print("Instantiating SimObjects...")
m5.instantiate()

# Run simulation loop checking for tohost write
tohost_addr = 0x80001000
max_ticks = 500000000000  # 500 billion ticks timeout (25 million cycles)
tick_step = 100000000  # Run 100M ticks at a time (5000 cycles) to minimize host loop overhead
current_tick = 0

exit_cause = "Maximum simulation ticks reached"
tohost_val = 0

print("Beginning gem5 simulation for PCIe test...")
while current_tick < max_ticks:
    exit_event = m5.simulate(tick_step)
    current_tick = m5.curTick()

    # Read tohost
    tohost_bytes = system.physProxy.read(tohost_addr, 8)
    tohost_val = int.from_bytes(tohost_bytes, "little")

    if tohost_val != 0:
        exit_cause = f"tohost written with value {tohost_val}"
        break

    if exit_event.getCause() != "simulate() limit reached":
        exit_cause = exit_event.getCause()
        # Re-read tohost in case the event occurred concurrently
        tohost_bytes = system.physProxy.read(tohost_addr, 8)
        tohost_val = int.from_bytes(tohost_bytes, "little")
        break

print("\n============================================")
if tohost_val == 1:
    print(f"Simulation finished! tohost = {tohost_val} (exit code = 0)")
    print("SUCCESS: PCIe access test passed successfully!")
    sys.exit(0)
elif tohost_val != 0:
    print(
        f"Simulation finished! tohost = {tohost_val} (exit code = {tohost_val >> 1 if tohost_val > 1 else -1})"
    )
    print(f"FAILURE: PCIe test program failed with exit code {tohost_val}")
    sys.exit(tohost_val >> 1 if tohost_val > 1 else 1)
else:
    print(f"Simulation finished due to: {exit_cause}")
    print("FAILURE: Simulation ended without writing success to tohost.")
    sys.exit(1)
