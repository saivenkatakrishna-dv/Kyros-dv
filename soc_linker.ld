ENTRY(_start)

MEMORY {
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 264K
}

SECTIONS {
  . = ORIGIN(RAM);

  .text : {
    *(.text.start)
    *(.text*)
  } > RAM

  .rodata : { *(.rodata*) } > RAM
  .data   : { *(.data*) } > RAM
  .bss    : { *(.bss*) *(COMMON) } > RAM

  . = ALIGN(4);
  /*_stack_top = ORIGIN(RAM) + LENGTH(RAM);*/
  _stack_top = 0x0001ffec;
}
