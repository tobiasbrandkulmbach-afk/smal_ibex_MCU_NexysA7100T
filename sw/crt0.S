/* ===========================================================================
 * crt0.S - minimaler C-Runtime-Startup fuer den Ibex-SoC.
 *
 * Aufgaben:
 *   1. Trap-Vektor an 0x0 (Default: Endlosschleife)
 *   2. _start an 0x80:  Stackpointer setzen, .data kopieren, .bss nullen,
 *      main() aufrufen, danach anhalten.
 *
 * Die Sektionsnamen (.vectors / .text.init) werden vom Linker-Script
 * ibex_soc.ld an die festen Adressen 0x00 bzw. 0x80 platziert.
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

    /* .data vom Lade-Abbild (IMEM) ins DMEM kopieren */
    la   a0, _data_lma
    la   a1, _data_start
    la   a2, _data_end
1:  bgeu a1, a2, 2f
    lw   t0, 0(a0)
    sw   t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j    1b

    /* .bss nullen */
2:  la   a0, _bss_start
    la   a1, _bss_end
3:  bgeu a0, a1, 4f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    3b

    /* main() aufrufen */
4:  call main

    /* Falls main() zurueckkehrt: anhalten */
_halt:
    wfi
    j    _halt
