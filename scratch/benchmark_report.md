# CVA6 Verilator Thread Scaling Benchmark Report

This report compares the performance of CVA6 RTL simulation in gem5 using different Verilator thread counts.

Note: gem5 compiles once and dynamically loads `libVcva6_top.so` compiled with varying Verilator threads.

## Host Configuration
- **CPU Threads Available:** 16

## Results

| Threads | Verilation Time (s) | Simulation Time (s) | Speedup (vs 1 Thread) | Simulated Ticks |
|---------|---------------------|---------------------|-----------------------|-----------------|
| 1       | 20.99               | 27.18               | 1.00                 x | 60,006,620,000  |
| 2       | 13.74               | 26.94               | 1.01                 x | 60,006,620,000  |
| 3       | 13.13               | 24.56               | 1.11                 x | 60,006,620,000  |
| 4       | 13.77               | 25.72               | 1.06                 x | 60,006,620,000  |

## Discussion
Increasing the thread count partitions the Verilator C++ model across multiple threads. However, performance scaling depends on:
1. **Design Size:** Small designs have high thread synchronization overhead that may offset the execution gains.
2. **Core/Thread count on Host:** Hardware resource limits.
