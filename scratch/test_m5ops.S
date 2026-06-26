#include "m5ops.h"

.section .text
.globl _start

_start:
    # 1. Run a loop before resetting stats
    li t0, 0
    li t1, 50
loop1:
    addi t0, t0, 1
    blt t0, t1, loop1

    # 2. Call m5_reset_stats (delay=0, period=0)
    m5_reset_stats 0, 0

    # 3. Run a longer loop after resetting stats
    li t0, 0
    li t1, 100
loop2:
    addi t0, t0, 1
    blt t0, t1, loop2

    # 4. Call m5_dump_stats (delay=0, period=0)
    m5_dump_stats 0, 0

    # 5. Call m5_exit (delay=0)
    m5_exit 0

hang:
    j hang
