OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text) }

  . = 0x80001000;
  .tohost : { *(.tohost) }

  . = 0x80002000;
  .output_val : { *(.output_val) }
}
