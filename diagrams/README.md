# gem5 & CVA6 RTL Co-Simulation Architecture Diagram

This directory contains a Python script using the `mingrammer/diagrams` library to generate a detailed system architecture diagram for the `gem5_cva6` co-simulation environment.

## Diagram Components

The diagram represents three main layers of the co-simulation environment:

1. **Python Configuration Layer (`configs/cva6/run_rtl.py` or `run_accel_l2.py`)**:
   - Initiates and configures the topology of the simulation.
   - Sets up clock domains, memories, buses, and cache coherence.

2. **gem5 C++ Simulator Process**:
   - **`CVA6RtlCPU` SimObject**: The main wrapper class. Translates between gem5's event-driven transaction packets and Verilator's pin-based RTL interface.
   - **AXI State Machine Buffers**: Internal C++ buffers holding states for the standard AXI channels (AR, R, AW, W, B).
   - **Instruction and Data Ports (`inst_port` and `data_port`)**: Standard gem5 `RequestPort`s used by the wrapper to send memory access transactions into the cache hierarchy or system bus.
   - **Interconnect & Memory (`L2XBar`, `L2Cache`, `SystemXBar`, `SimpleMemory`)**: Standard gem5 memory system objects that simulate coherent caching and main memory.
   - **`FifoAccelerator`**: A custom gem5 SimObject simulating a hardware accelerator that communicates via PIO (register writes from CPU) and DMA (master memory read/write requests).

3. **Verilated RTL Core (`libVcva6_top.so`)**:
   - Compiled CVA6 RISC-V core using Verilator.
   - Communicates using AXI signals exposed by `CVA6RtlCoreInterface`.

## AXI Protocol Mapping

The co-simulation boundary is bridged by mapping the core's AXI interface signals (`noc_req_*` and `noc_resp_*`) to gem5's memory transaction protocol:

* **AR (Address Read) Channel**:
  - The core raises `noc_req_ar_valid_o` with address `noc_req_ar_addr_o`.
  - The `CVA6RtlCPU` SimObject captures the request, sets up a gem5 read `Packet` (`Packet::createRead`), and forwards it via `inst_port` or `data_port`.
  - When memory returns the data, `CVA6RtlCPU` sets `noc_resp_r_valid_i` and drives `noc_resp_r_data_i` along with `noc_resp_r_last_i`.
* **AW/W (Write Address & Write Data) Channels**:
  - The core asserts `noc_req_aw_valid_o` and `noc_req_w_valid_o` with address, length, and write data.
  - The `CVA6RtlCPU` buffers the address and data beats, then sends a gem5 write `Packet` (`Packet::createWrite`) to the bus.
  - Upon memory acknowledgement, the wrapper asserts `noc_resp_b_valid_i` (B channel response) back to the core.

## How to Run the Script

To generate the diagram, run the script using the pre-configured `diagrams` environment:

```bash
/home/julian/.local/bin/diagrams diagrams/generate_diagram.py
```

This will output a PNG image named `gem5_cva6_co_sim_architecture.png` in this folder.
