#!/usr/bin/env python3
# Copyright 2026 Antigravity
# Description: Script using mingrammer/diagrams to generate a diagram
#              explaining the gem5 + CVA6 RTL co-simulation architecture.

import os
from diagrams import Diagram, Cluster, Edge
from diagrams.programming.language import Python, Cpp
from diagrams.generic.storage import Storage
from diagrams.generic.network import Switch
from diagrams.generic.blank import Blank

def main():
    # Diagram configuration
    graph_attr = {
        "fontsize": "16",
        "bgcolor": "white",
        "splines": "spline", # Smooth curved routing for edges
        "nodesep": "0.4",
        "ranksep": "0.7",
        "pad": "0.3",
    }
    
    # Ensure the output image is saved in the same directory as this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "gem5_cva6_co_sim_architecture")
    
    # We define a top-to-bottom layout
    with Diagram(
        name="gem5 & CVA6 RTL Co-Simulation System Architecture",
        filename=output_path,
        outformat="png",
        show=False,
        direction="TB",
        graph_attr=graph_attr
    ):
        # 1. Configuration / Control Layer
        py_config = Python(
            "run_rtl.py / run_accel_l2.py\n(gem5 Python Setup Script)"
        )

        # 2. gem5 Simulation Process (C++ Environment)
        with Cluster("gem5 Simulator Process (C++ Engine)"):
            
            # CVA6 SimObject Wrapper
            with Cluster("CVA6 RTL SimObject Wrapper (CVA6RtlCPU)"):
                cva6_cpu = Cpp("CVA6RtlCPU\n(gem5 SimObject)")
                
                # Ports exposed to gem5
                inst_port = Blank("inst_port\n(RequestPort)")
                data_port = Blank("data_port\n(RequestPort)")
                
                # AXI State buffers inside wrapper
                axi_buffers = Storage("AXI State Machine Buffers\n(AR, R, AW, W, B)")
                
                cva6_cpu >> Edge(style="dashed", color="blue", label="inst fetch") >> inst_port
                cva6_cpu >> Edge(style="dashed", color="blue", label="data access") >> data_port
                cva6_cpu >> Edge(style="dashed", color="gray") >> axi_buffers

            # Optional Coherent L2 Cache Hierarchy (found in run_accel_l2.py)
            with Cluster("Cache Hierarchy"):
                l2_xbar = Switch("L2XBar\n(L2 Coherent Bus)")
                l2_cache = Storage("L2Cache\n(256 KiB)")
                l2_xbar >> l2_cache

            # System Bus Crossbar
            membus = Switch("SystemXBar\n(membus)")
            
            # Physical RAM
            phys_ram = Storage("SimpleMemory\n(256MB RAM @ 0x80000000)")

            # Optional RTL FIFO Accelerator
            with Cluster("FIFO Accelerator"):
                fifo_accel = Cpp("FifoAccelerator\n(SimObject)")
                accel_lib = Storage("libfifo_accel.so\n(RTL shared library)")
                fifo_accel >> Edge(style="dotted", color="purple") >> accel_lib

        # 3. Verilated RTL Core (Inside compiled shared library)
        with Cluster("Verilated RTL Core (Shared Library)"):
            with Cluster("libVcva6_top.so (Verilator output)"):
                core_interface = Cpp("CVA6RtlCoreInterface\n(Abstract Interface)")
                cva6_rtl = Blank("CVA6 RTL Core\n(SystemVerilog Model)")
                
                core_interface >> Edge(style="solid", color="indigo") >> cva6_rtl

        # --- Inter-component connections and flow ---
        
        # Python config triggers instantiation & orchestration of gem5 SimObjects
        py_config >> Edge(label="configures & runs", style="dotted", color="dimgray") >> cva6_cpu
        py_config >> Edge(label="sets topology", style="dotted", color="dimgray") >> membus

        # Dynamic loading (dlopen) of the Verilated shared library by CVA6RtlCPU
        cva6_cpu >> Edge(label="dlopen() / dlsym()\ninstantiates core", color="darkgreen", style="solid") >> core_interface

        # AXI channels handshake (The core/wrapper boundary)
        # AR (Address Read) & R (Read Data)
        cva6_rtl >> Edge(label="AR (noc_req_ar_*)", color="darkorange", style="solid") >> axi_buffers
        axi_buffers >> Edge(label="R (noc_resp_r_*)", color="darkorange", style="solid") >> cva6_rtl

        # AW (Address Write), W (Write Data) & B (Write Response)
        cva6_rtl >> Edge(label="AW / W (noc_req_aw_* / noc_req_w_*)", color="crimson", style="solid") >> axi_buffers
        axi_buffers >> Edge(label="B (noc_resp_b_*)", color="crimson", style="solid") >> cva6_rtl

        # Clock & Control (tick / eval)
        cva6_cpu >> Edge(label="set_clk_i() / set_rst_ni()\neval()", color="royalblue", style="solid") >> core_interface

        # Connect CVA6 CPU Ports to Cache Hierarchy
        inst_port >> Edge(color="blue") >> l2_xbar
        data_port >> Edge(color="blue") >> l2_xbar
        
        # Connect Cache to Main System Bus
        l2_cache >> Edge(color="blue") >> membus
        
        # Connect System Bus to Memory
        membus >> Edge(label="memory requests", color="blue") >> phys_ram

        # Connect FIFO Accelerator to System Bus (PIO and DMA)
        membus >> Edge(label="PIO Configuration (0x10000)", color="darkgreen") >> fifo_accel
        fifo_accel >> Edge(label="DMA Access (Memory / RAM)", color="darkgreen") >> membus

if __name__ == "__main__":
    main()
