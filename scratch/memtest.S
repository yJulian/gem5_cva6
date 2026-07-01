.section .text
.globl _start

_start:
    # Initialize registers
    # Base address for memory test data: 0x80002000
    li t0, 0x80002000
    li t1, 0             # Loop counter (i = 0)
    li t2, NUM_WORDS     # Number of words to test (defined at compilation)

    # 1. Write loop: Fill memory with unique pattern (0xDEADBEEF00000000 + i)
write_loop:
    # Compute address: t3 = t0 + t1 * 8
    slli t3, t1, 3       # t3 = t1 * 8 (double words / 64-bit values)
    add t3, t0, t3       # t3 = base_addr + offset

    # Generate a unique test value for this index
    li t4, 0xDEADBEEF
    slli t4, t4, 32      # Shift to upper 32 bits
    add t4, t4, t1       # val = 0xDEADBEEF00000000 + i

    sd t4, 0(t3)         # Store 64-bit value to RAM

    # Force write to complete before next loop iteration (workaround for AXI wrapper bug)
    fence

    addi t1, t1, 1       # i++
    blt t1, t2, write_loop

    # Force all writes to complete before starting reads
    fence

    # Reset loop counter for verification
    li t1, 0

    # 2. Read loop: Read back and verify the pattern
read_loop:
    # Compute address: t3 = t0 + t1 * 8
    slli t3, t1, 3
    add t3, t0, t3

    ld t4, 0(t3)         # Load 64-bit value from RAM

    # Generate the expected value
    li t5, 0xDEADBEEF
    slli t5, t5, 32
    add t5, t5, t1

    # Compare loaded value with expected value
    bne t4, t5, failure  # If they do not match, jump to failure

    addi t1, t1, 1       # i++
    blt t1, t2, read_loop

success:
    # Write 1 to tohost (success / exit code 0)
    li t4, 1
    la t5, tohost
    sd t4, 0(t5)
    fence
    ebreak

hang:
    ebreak
    j hang

failure:
    # Write 3 to tohost (failure / exit code 1)
    li t4, 3
    la t5, tohost
    sd t4, 0(t5)
    fence
    ebreak
    j hang

.section .tohost
.align 8
.globl tohost
tohost:
    .dword 0
