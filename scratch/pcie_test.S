.section .text
.globl _start

_start:
    # 1. Read the PCI Vendor and Device ID for Device 1
    li t0, 0x30008000    # PCI Config space address for Bus 0, Dev 1, Func 0
    lw t1, 0(t0)         # Read 32-bit Vendor/Device ID
    
    # Expected for IGbE_e1000:
    # (DeviceID << 16) | VendorID = (0x1075 << 16) | 0x8086 = 0x10758086
    li t2, 0x10758086
    bne t1, t2, failure  # If they don't match, jump to failure

    # 2. Map BAR0 of Device 1 to PCI bus address 0 (resolves to physical address 0x40000000)
    # BAR0 is at offset 0x10 in the configuration space (i.e. 0x30008010)
    li t3, 0x0
    sw t3, 0x10(t0)      # Write 0 to BAR0 (using sw for 32-bit write)
    fence

    # 3. Enable Memory Space access in the PCI Command Register
    # The Command Register is at offset 0x4 (i.e. 0x30008004)
    # We need to set bit 1 (Memory Space Enable)
    lh t4, 0x4(t0)       # Read 16-bit Command register
    ori t4, t4, 0x2      # OR with 2 (Memory Space Enable)
    sh t4, 0x4(t0)       # Write back to Command register
    fence

    # 4. Read the REG_STATUS register at offset 0x08 of the mapped BAR0
    # IGbE's REG_STATUS is a 32-bit register at offset 0x08.
    # It returns regs.sts (initialized to speed=3, fd=1, lu=1 -> 0xC3).
    li t5, 0x40000008    # base 0x40000000 + offset 0x08
    lw t6, 0(t5)         # Load 32-bit word (lw)
    
    # Expected value is 0xC3 (decimal 195)
    li a0, 0xC3
    bne t6, a0, failure  # If it is not 0xC3, jump to failure

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
