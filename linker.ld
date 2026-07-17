OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 512K
}

SECTIONS
{
    . = ORIGIN(IMEM);

    .text : { *(.text.start) *(.text*) } > IMEM
    .rodata : { *(.rodata*) } > IMEM

    . = ORIGIN(DMEM);

    .data : { *(.data*) } > DMEM
    .region_0 : { *(.region_0) } > DMEM
    .region_1 : { *(.region_1) } > DMEM
    .user_stack : { *(.user_stack) } > DMEM

    .tohost :
    {
        *(.tohost)
    } > DMEM

    .bss :
    {
        *(.bss*)
        *(COMMON)
    } > DMEM

    _end = .;
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
