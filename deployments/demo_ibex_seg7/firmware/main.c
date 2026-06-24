/* ===========================================================================
 * seg7_counter - Minimal-Demo fuer den Ibex-SoC.
 *
 * Zaehlt einen 32-Bit-Wert hoch und gibt ihn auf der 8-stelligen
 * 7-Segment-Anzeige (Hex) aus. Zwischen den Schritten eine kurze
 * Software-Verzoegerung, damit das Zaehlen sichtbar ist.
 * ===========================================================================*/
#include "soc.h"

/* Grobe Busy-Wait-Schleife (volatile -> wird nicht wegoptimiert). */
static void delay(volatile uint32_t loops)
{
    while (loops--) {
        /* nichts */
    }
}

int main(void)
{
    uint32_t value = 0;

    for (;;) {
        seg7_write(value);
        value++;
        delay(2000000u);   /* bei 100 MHz grob ~0,1 s sichtbar */
    }

    return 0;   /* nie erreicht */
}
