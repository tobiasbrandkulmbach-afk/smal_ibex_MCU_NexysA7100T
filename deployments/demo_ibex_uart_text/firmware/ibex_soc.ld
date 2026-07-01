/* ===========================================================================
 * Linker-Script fuer den Ibex-SoC (demo_ibex_uart_text).
 *
 * Speicher-Modell: ECHTE HARVARD-TRENNUNG.
 *   IMEM (0x0000_0000) enthaelt AUSSCHLIESSLICH Code (.text/.vectors).
 *   DMEM (0x0001_0000) enthaelt ALLE Daten: rodata + .data + .bss + Stack.
 * Der Daten-Bus des Ibex greift nie aufs IMEM zu, der Instruktions-Bus nie
 * aufs DMEM. Beide Speicher werden per $readmemh (imem.mem / dmem.mem) beim
 * FPGA-Bitstream initialisiert; es gibt KEIN Runtime-Kopieren durch crt0.
 *
 * WICHTIG: Die Groessen muessen mit den RAM-Instanzen im Deployment-Top
 * uebereinstimmen:
 *     IMEM  ADDR_WIDTH=8   -> 256 Woerter ->  1 KB   @ 0x0000_0000
 *     DMEM  ram #(.AddrWidth(12)) -> 4096 Woerter -> 16 KB   @ 0x0001_0000
 *
 * HINWEIS (Reset-Verhalten): Da .data/rodata resident im DMEM liegen und nur
 * bei der FPGA-Konfiguration (BRAM-Init aus dmem.mem) gesetzt werden, setzt
 * ein Warm-Reset (BTNC) veraenderte globale .data-Variablen NICHT auf ihren
 * Initialwert zurueck. crt0 nullt lediglich .bss. Wer echtes Re-Init bei
 * jedem Reset braucht, muesste zum crt0-Copy-Muster (Init-Abbild im IMEM)
 * zurueckkehren.
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
    imem (rx) : ORIGIN = 0x00000000, LENGTH = 1K    /* 256 Woerter, nur Code    */
    dmem (rw) : ORIGIN = 0x00010000, LENGTH = 16K   /* 4096 Woerter, alle Daten */
}

/* Stack waechst nach unten ab dem oberen Ende des DMEM. */
_stack_top = ORIGIN(dmem) + LENGTH(dmem);

SECTIONS
{
    /* --- IMEM: Vektoren + Code ------------------------------------------ *
     * Trap-Vektor liegt bei 0x00 (mtvec-Basis), danach wird der Location-
     * Counter per Dot-Zuweisung auf 0x80 gesetzt, damit _start exakt auf dem
     * Ibex-Reset-Vektor (BootAddr + 0x80) landet.                            */
    .text ORIGIN(imem) :
    {
        KEEP(*(.vectors))           /* Trap-Vektor @ 0x00 */
        . = ORIGIN(imem) + 0x80;    /* _start MUSS bei 0x80 liegen */
        KEEP(*(.text.init))         /* crt0 / _start zuerst */
        *(.text .text.*)
        . = ALIGN(4);
    } > imem

    /* --- DMEM: rodata (resident, ueber dmem.mem initialisiert) ---------- *
     * MUSS am DMEM-Anfang liegen, weil der Build dmem.mem aus den DMEM-
     * Sektionen erzeugt (objcopy) und Datei-Offset 0 = DMEM-Wort 0.         */
    .rodata ORIGIN(dmem) :
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > dmem

    /* --- DMEM: .data (resident, initialisierte Globals) ----------------- */
    .data :
    {
        . = ALIGN(4);
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
    } > dmem

    /* --- DMEM: .bss (uninitialisiert, von crt0 genullt) ----------------- */
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
