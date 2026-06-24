/* ===========================================================================
 * Linker-Script fuer den Ibex-SoC (demo_ibex_seg7).
 *
 * WICHTIG: Die Groessen IMEM/DMEM muessen mit den ram-Instanzen im
 * Deployment-Top uebereinstimmen (Parameter AddrWidth):
 *     IMEM  ram #(.AddrWidth(8))  -> 256 Woerter ->  1 KB   @ 0x0000_0000
 *     DMEM  ram #(.AddrWidth(12)) -> 4096 Woerter -> 16 KB   @ 0x0001_0000
 * Wird die Hardware vergroessert, hier LENGTH anpassen (und umgekehrt).
 *
 * Ibex-Boot: Reset-PC = BootAddr + 0x80, mtvec-Basis = BootAddr + 0x00.
 * Mit BootAddr = 0x0 liegt damit:
 *     _start         (Reset-Einsprung) bei 0x0000_0080
 *     _trap_vector   (Trap-Handler)    bei 0x0000_0000
 * ===========================================================================*/

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    imem (rx) : ORIGIN = 0x00000000, LENGTH = 1K    /* 256 Woerter, read-only  */
    dmem (rw) : ORIGIN = 0x00010000, LENGTH = 16K   /* 4096 Woerter, read/write */
}

/* Stack waechst nach unten ab dem oberen Ende des DMEM. */
_stack_top = ORIGIN(dmem) + LENGTH(dmem);

SECTIONS
{
    /* --- Vektoren + Code in EINER Section ------------------------------- *
     * Trap-Vektor liegt bei 0x00 (mtvec-Basis), danach wird der Location-
     * Counter per Dot-Zuweisung auf 0x80 gesetzt, damit _start exakt auf dem
     * Ibex-Reset-Vektor (BootAddr + 0x80) landet. Eine Dot-Zuweisung ZWISCHEN
     * zwei region-gebundenen Sections wuerde ld ignorieren - deshalb der
     * Offset innerhalb der Section.                                          */
    .text ORIGIN(imem) :
    {
        KEEP(*(.vectors))           /* Trap-Vektor @ 0x00 */
        . = ORIGIN(imem) + 0x80;    /* _start MUSS bei 0x80 liegen */
        KEEP(*(.text.init))         /* crt0 / _start zuerst */
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > imem

    /* --- .data: liegt zur Laufzeit im DMEM (VMA), das Init-Abbild aber
     *     im IMEM (LMA). crt0 kopiert es beim Start nach DMEM. ----------- */
    .data :
    {
        . = ALIGN(4);
        _data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _data_end = .;
    } > dmem AT > imem
    _data_lma = LOADADDR(.data);

    /* --- .bss: uninitialisiert, wird von crt0 genullt ------------------- */
    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > dmem

    /* Debug-Sektionen nicht ins Speicherabbild laden. */
    /DISCARD/ : { *(.comment) *(.note .note.*) *(.eh_frame) }
}
