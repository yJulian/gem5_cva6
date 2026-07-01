# Copyright 2026 Antigravity
# Description: gem5 configuration script to attempt booting Linux on the custom CVA6 RTL Core.

import argparse
import sys
import os
from os import path

# Import classic gem5 objects
import m5
from m5.objects import *
from m5.util import fatal, warn
from m5.util.fdthelper import *

from gem5.utils.requires import requires
from gem5.isas import ISA
from gem5.resources.resource import obtain_resource

# Ensure we are using the RISC-V target
requires(isa_required=ISA.RISCV)

# Parse command line arguments
parser = argparse.ArgumentParser(
    description="Attempt to boot a minimal BusyBox Linux distro on the CVA6 RTL core in gem5 FS mode"
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
    "--mem-size",
    type=str,
    default="512MiB",
    help="Physical memory size (e.g., 512MiB, 1GiB)",
)
args = parser.parse_args()

# Create the top-level System
system = System()
system.mem_mode = "timing"

# Set up clock and voltage domains (Matching the 50MHz CVA6 RTL frequency)
system.voltage_domain = VoltageDomain(voltage="1.0V")
system.clk_domain = SrcClockDomain(
    clock="2GHz", voltage_domain=system.voltage_domain
)

# Set up physical memory range starting at 0x80000000
system.mem_ranges = [AddrRange(0x80000000, size=args.mem_size)]

# Create crossbars (interconnects)
system.membus = SystemXBar()
system.iobus = IOXBar()

# Connect system port to the crossbar (required by gem5)
system.system_port = system.membus.cpu_side_ports

# Instantiate our custom CVA6 RTL CPU
# Note: Clint and Plic autogeneration code requires system.cpu to be an iterable list
system.cpu = [CVA6RtlCPU()]
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

# Set up VirtIO MMIO disk controller using BusyBox image
image = CowDiskImage(child=RawDiskImage(read_only=True), read_only=False)
disk_resource = obtain_resource("riscv-disk-img", resource_version="1.0.0")
image.child.image_file = disk_resource.get_local_path()

system.platform.disk = RiscvMmioVirtIO(
    vio=VirtIOBlock(image=image),
    interrupt_id=0x8,
    pio_size=4096,
    pio_addr=0x10008000,
)

# Bridge between main system bus and IO bus (for MMIO registers)
system.bridge = Bridge(delay="50ns")
system.bridge.mem_side_port = system.iobus.cpu_side_ports
system.bridge.cpu_side_port = system.membus.mem_side_ports
system.bridge.ranges = system.platform._off_chip_ranges()

# Attach and configure all IO devices
system.platform.attachOnChipIO(system.membus)
system.platform.attachOffChipIO(system.iobus)
system.platform.attachPlic()
system.platform.setNumCores(1)

# Cache line size setting required for system components
system.cache_line_size = 64

# Use the custom patched bootloader/kernel binary
system.workload = RiscvLinux()
system.workload.object_file = "/home/julian/gem5_cva6/scratch/riscv-bootloader-vmlinux-5.10-patched"


# Custom DTB (Device Tree Blob) generator for CVA6 RTL Core
def generateMemNode(state, mem_range):
    node = FdtNode(f"memory@{int(mem_range.start):x}")
    node.append(FdtPropertyStrings("device_type", ["memory"]))
    node.append(
        FdtPropertyWords(
            "reg",
            state.addrCells(mem_range.start)
            + state.sizeCells(mem_range.size()),
        )
    )
    return node


def generateDtb(system):
    state = FdtState(addr_cells=2, size_cells=2, cpu_cells=1)
    root = FdtNode("/")
    root.append(state.addrCellsProperty())
    root.append(state.sizeCellsProperty())
    root.appendCompatible(["riscv-virtio"])

    # Add memory node
    for mem_range in system.mem_ranges:
        root.append(generateMemNode(state, mem_range))

    # Merge platform device tree nodes (PLIC, CLINT, UART, etc.)
    for node in system.platform.generateDeviceTree(state):
        if node.get_name() == root.get_name():
            root.merge(node)
        else:
            root.append(node)

    # Locate 'cpus' container and insert CVA6 CPU 0
    cpus_node = None
    for sub in root.subdata:
        if isinstance(sub, FdtNode) and sub.get_name() == "cpus":
            cpus_node = sub
            break

    if not cpus_node:
        cpus_node = FdtNode("cpus")
        cpus_node.append(FdtPropertyWords("#address-cells", [1]))
        cpus_node.append(FdtPropertyWords("#size-cells", [0]))
        cpus_node.append(FdtPropertyWords("timebase-frequency", [10000000]))
        root.append(cpus_node)

    # Construct CVA6 CPU Node manually since CVA6RtlCPU lacks autogeneration helpers
    cpu_node = FdtNode("cpu@0")
    cpu_node.append(FdtPropertyStrings("device_type", ["cpu"]))
    cpu_node.append(FdtPropertyWords("reg", [0]))
    cpu_node.append(FdtPropertyStrings("mmu-type", ["riscv,sv39"]))
    cpu_node.append(FdtPropertyStrings("status", ["okay"]))
    cpu_node.append(FdtPropertyStrings("riscv,isa", ["rv64imafdc"]))
    cpu_node.append(FdtPropertyWords("clock-frequency", [2000000000]))
    cpu_node.appendCompatible(["riscv"])

    # Nested interrupt controller
    int_node = FdtNode("interrupt-controller")
    int_state = FdtState(interrupt_cells=1)
    phandle = int_state.phandle(system.cpu[0])

    int_node.append(int_state.interruptCellsProperty())
    int_node.append(FdtProperty("interrupt-controller"))
    int_node.appendCompatible(["riscv,cpu-intc"])
    int_node.append(FdtPropertyWords("phandle", [phandle]))

    cpu_node.append(int_node)
    cpus_node.append(cpu_node)

    # Chosen node for bootloader and kernel boot arguments
    node = FdtNode("chosen")
    node.append(FdtPropertyStrings("bootargs", [system.workload.command_line]))
    node.append(FdtPropertyStrings("stdout-path", ["/soc/uart@10000000"]))
    root.append(node)

    fdt = Fdt()
    fdt.add_rootnode(root)

    if not os.path.exists(m5.options.outdir):
        os.makedirs(m5.options.outdir)

    fdt.writeDtsFile(path.join(m5.options.outdir, "device.dts"))
    fdt.writeDtbFile(path.join(m5.options.outdir, "device.dtb"))


# Initialize device tree generation and arguments
system.workload.dtb_addr = 0x87E00000
system.workload.command_line = "console=ttyS0 root=/dev/vda rw"
generateDtb(system)
system.workload.dtb_filename = path.join(m5.options.outdir, "device.dtb")

# Instantiate simulation Root
root = Root(full_system=True, system=system)

print("\n==========================================================================")
print("Simulation Ready to Start!")
print("Connecting CVA6 RTL Core to BusyBox Linux workload.")
print("Note: The current CVA6 C++ co-simulation wrapper ties interrupt pins to 0.")
print("The Linux kernel will start booting but will hang when attempting to")
print("calibrate timers or configure the PLIC/CLINT due to lack of interrupts.")
print("==========================================================================\n")

print("Beginning gem5 Full System simulation with CVA6 RTL CPU...")
m5.instantiate()
m5.simulate()
