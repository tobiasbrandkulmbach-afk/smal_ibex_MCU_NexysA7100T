/* ===========================================================================
 * crt0.S - minimaler C-Runtime-Startup fuer den Ibex-SoC.
 *
 * Speicher-Modell: ECHTE HARVARD-TRENNUNG (siehe Linker-Script <demo>.ld).
 *   Code liegt im IMEM, ALLE Daten (rodata/.data/.bss/Stack) im DMEM. Beide
 *   Speicher werden per $readmemh beim FPGA-Bitstream initialisiert. rodata
 *   und initialisierte .data-Globals sind damit bereits resident im DMEM -
 *   crt0 kopiert daher NICHTS mehr, sondern nullt nur .bss.
 *
 * Aufgaben:
 *   1. Trap-Vektor an 0x0 (Default: Endlosschleife)
 *   2. _start an 0x80:  Stackpointer setzen, .bss nullen, main() aufrufen,
 *      danach anhalten.
 *
 * Die Sektionsnamen (.vectors / .text.init) werden vom Linker-Script an die
 * festen Adressen 0x00 bzw. 0x80 platziert.
 * ===========================================================================*/

    /* --- Trap-Vektor @ 0x0 ------------------------------------------------ */
    .section .vectors, "ax"
    .global _trap_vector
_trap_vector:
    j   _trap_handler

    /* Schwacher Default-Trap-Handler: anhalten. In C ueberschreibbar via
     * 'void _trap_handler(void)'. */
    .weak _trap_handler
_trap_handler:
    j   _trap_handler

    /* --- Reset-Einsprung @ 0x80 ------------------------------------------ */
    .section .text.init, "ax"
    .global _start
_start:
    /* Stackpointer initialisieren */
    la   sp, _stack_top

    /* .bss nullen (rodata/.data sind bereits resident im DMEM) */
    la   a0, _bss_start
    la   a1, _bss_end
1:  bgeu a0, a1, 2f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    1b

    /* main() aufrufen */
2:  call main

    /* Falls main() zurueckkehrt: anhalten */
_halt:
    wfi
    j    _halt
