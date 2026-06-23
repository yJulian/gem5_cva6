# CVA6 Verilator Thread Scaling Benchmark Report

This report compares the performance of CVA6 RTL simulation in gem5 using different Verilator thread counts.

## Host Configuration
- **CPU Threads Available:** 16

## Results

| Threads | Verilation Time (s) | Gem5 Build Time (s) | Dhrystone Sim Time (s) | Speedup (vs 1 Thread) | Simulated Ticks |
|---------|---------------------|---------------------|------------------------|-----------------------|-----------------|
| 1       | 18.96               | 109.98              | 21.84                  | 1.00                 x | 45,780,220,000  |
| 4       | 13.32               | 91.18               | 20.91                  | 1.04                 x | 45,780,220,000  |
| 8       | 10.32               | 89.23               | 29.37                  | 0.74                 x | 45,780,220,000  |
| 16      | 11.25               | 110.89              | 90.66                  | 0.24                 x | 45,780,220,000  |

## Discussion
Increasing the thread count partitions the Verilator C++ model across multiple threads. However, performance scaling depends on:
1. **Design Size:** Small designs have high thread synchronization overhead that may offset the execution gains.
2. **Core/Thread count on Host:** Hardware resources limits.
