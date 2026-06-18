.section .text
.globl _start

_start:
    # Initialize registers
    li t0, 1         # Start value (1)
    li t1, 100000     # End value (100000)
    li t2, 0         # Sum accumulator

loop:
    add t2, t2, t0   # sum = sum + t0
    addi t0, t0, 1   # t0 = t0 + 1
    ble t0, t1, loop # if t0 <= 100000, loop

    # Check if sum is correct (5000050000)
    li t3, 5000050000
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
