# fail_test_accel.S
# INTENTIONAL FAILURE TEST for FIFO Accelerator
# Performs a real DMA transfer via the FIFO Accelerator, but verifies the result
# against deliberately WRONG expected values.
# This test MUST always produce FAILURE (tohost = 3).

.section .text
.globl _start

_start:
    # Initialize some source data in RAM at 0x80010000
    li t0, 0x80010000
    li t1, 0x1111222233334444
    sd t1, 0(t0)
    fence
    li t1, 0x5555666677778888
    sd t1, 8(t0)
    fence
    li t1, 0x9999aaaabbbbcccc
    sd t1, 16(t0)
    fence
    li t1, 0xddddeeeeffff0000
    sd t1, 24(t0)
    fence

    # Initialize destination data to zero at 0x80020000
    li t0, 0x80020000
    sd zero, 0(t0)
    fence
    sd zero, 8(t0)
    fence
    sd zero, 16(t0)
    fence
    sd zero, 24(t0)
    fence

    # Initialize MMIO register pointers
    li a0, 0x10000          # Accel Base Address
    li a1, 0x80010000       # Source RAM Addr
    li a2, 0x80020000       # Dest RAM Addr
    li a3, 4                # Length (4 words)

    # Configure DMA registers
    sd a1, 8(a0)            # SRC_ADDR = 0x80010000
    fence
    sd a2, 16(a0)           # DST_ADDR = 0x80020000
    fence
    sd a3, 24(a0)           # LEN = 4
    fence

    # Start DMA transfer (write 1 to CTRL)
    li t2, 1
    sd t2, 0(a0)            # CTRL.START = 1
    fence

    # Force write buffer to flush to MMIO
    fence io, io

wait_loop:
    ld t3, 0(a0)            # Read CTRL
    andi t4, t3, 4          # Check CTRL.DONE (bit 2)
    beqz t4, wait_loop      # If not done, poll again

    # Clear DONE bit
    li t2, 4
    sd t2, 0(a0)            # CTRL.DONE = 1 to clear
    fence

    # Verify results with INTENTIONALLY WRONG expected values
    li t0, 0x80020000

    ld t1, 0(t0)
    li t2, 0xDEADBEEFCAFEBABE  # WRONG: expected 0x1111222233334444
    bne t1, t2, failure

    ld t1, 8(t0)
    li t2, 0xBAADF00DBAADF00D   # WRONG: expected 0x5555666677778888
    bne t1, t2, failure

    ld t1, 16(t0)
    li t2, 0x0123456789ABCDEF   # WRONG: expected 0x9999aaaabbbbcccc
    bne t1, t2, failure

    ld t1, 24(t0)
    li t2, 0xFEEDFACEFEEDFACE   # WRONG: expected 0xddddeeeeffff0000
    bne t1, t2, failure

success:
    # Write 1 to tohost (should NOT be reached in this fail test)
    li t4, 1
    la t5, tohost
    sd t4, 0(t5)
    fence
    ebreak
    j hang

failure:
    # Write 3 to tohost (EXPECTED outcome for this fail test)
    li t4, 3
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
