import shutil
import os

src = '/home/julian/.cache/gem5/riscv-bootloader-vmlinux-5.10-1.0.0'
dst = '/home/julian/gem5_cva6/scratch/riscv-bootloader-vmlinux-5.10-patched'

# Read original
f = open(src, 'rb')
data = bytearray(f.read())
f.close()

# Apply only the CPU node pointer patch (preserve CPU node pointer, do NOT clear it)
# Patch sd zero, 16(a1) at 0x14a0 (0x800004a0) to nop
data[0x14a0:0x14a4] = b'\x13\x00\x00\x00'

# Ensure the chosen node pointer patch is NOT applied (keep it as original to let it clear as intended)
data[0x14a8:0x14ac] = b'\x23\xb0\x05\x00'

# Write to custom destination
f_out = open(dst, 'wb')
f_out.write(data)
f_out.close()

print(f'Patched binary written to {dst}')
