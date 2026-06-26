#include "m5ops.h"

.section .text
.globl _start

_start:
    # 1. Run loop 1 before checkpoint
    li t0, 0
    li t1, 100
loop1:
    addi t0, t0, 1
    blt t0, t1, loop1

    # 2. Trigger checkpoint
    m5_checkpoint 0, 0

    # 3. Run loop 2 after checkpoint
    li t0, 0
    li t1, 200
loop2:
    addi t0, t0, 1
    blt t0, t1, loop2

    # 4. Exit simulation
    m5_exit 0

hang:
    j hang
