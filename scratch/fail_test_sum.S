# fail_test_sum.S
# INTENTIONAL FAILURE TEST
# Computes sum 1..1000 = 500500, but compares against WRONG value 123456.
# This test MUST always produce FAILURE (tohost = 3).

.section .text
.globl _start

_start:
    # Initialize registers
    li t0, 1         # Start value (1)
    li t1, 1000      # End value (1,000)
    li t2, 0         # Sum accumulator

loop:
    add t2, t2, t0   # sum = sum + t0
    addi t0, t0, 1   # t0 = t0 + 1
    ble t0, t1, loop # if t0 <= 1000, loop

    # Intentionally wrong expected value to force FAILURE
    li t3, 123456    # WRONG: correct value is 500500
    beq t2, t3, success

failure:
    # Write 3 to tohost (exit code 1 = failure)
    li t4, 3
    la t5, tohost
    sd t4, 0(t5)
    # write result to host
    la t5, output_val
    sd t2, 0(t5)
    fence
    ebreak
    j hang

success:
    # Write 1 to tohost (exit code 0 = success)
    li t4, 1
    la t5, tohost
    sd t4, 0(t5)
    fence
    ebreak

hang:
    ebreak
    j hang

.section .tohost
.align 8
.globl tohost
tohost:
    .dword 0

.section .output_val
.align 8
.globl output_val
output_val:
    .dword 0