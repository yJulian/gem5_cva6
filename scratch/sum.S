.section .text
.globl _start

_start:
    # Initialize registers
    li t0, 1         # Start value (1)
    li t1, 9         # End value (9)
    li t2, 0         # Sum accumulator

loop:
    add t2, t2, t0   # sum = sum + t0
    addi t0, t0, 1   # t0 = t0 + 1
    ble t0, t1, loop # if t0 <= 9, loop

    # Check if sum is correct (45)
    li t3, 45
    beq t2, t3, success

failure:
    # Write 3 to tohost (exit code 1)
    li t4, 3
    la t5, tohost
    sd t4, 0(t5)
    j hang

success:
    # Write 1 to tohost (success / exit code 0)
    li t4, 1
    la t5, tohost
    sd t4, 0(t5)

hang:
    j hang

.section .tohost
.align 8
.globl tohost
tohost:
    .dword 0
