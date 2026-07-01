/* ===========================================================================
 * demo_ibex_uart_text - Lauftext auf der 7-Segment-Anzeige.
 *
 * Jedes ueber die USB-UART empfangene Zeichen erscheint rechts (AN0) auf der
 * 8-stelligen 7-Segment-Anzeige; bereits angezeigte Zeichen wandern eine
 * Stelle nach links. Nicht darstellbare Zeichen zeigt der Hardware-Font als
 * leere Stelle. Steuerzeichen (CR/LF etc.) werden ignoriert.
 *
 * Am PC senden, z.B.:  screen /dev/ttyUSB1 115200   (dann einfach tippen)
 * ===========================================================================*/
#include "soc.h"

int main(void)
{
    /* Anzeigepuffer: buf[0] = linke Stelle (AN7), buf[7] = rechte (AN0). */
    char buf[8];
    for (int i = 0; i < 8; i++) buf[i] = ' ';

    seg7_show(buf);                 /* Start: alles leer */

    for (;;) {
        char c = uart_getc();       /* blockiert bis ein Byte da ist */

        /* Nur druckbare Zeichen anzeigen; Steuerzeichen verwerfen. */
        if ((uint8_t)c < 0x20 || (uint8_t)c > 0x7E) {
            continue;
        }

        /* Alles eine Stelle nach links schieben, neues Zeichen rechts rein. */
        for (int i = 0; i < 7; i++) buf[i] = buf[i + 1];
        buf[7] = c;

        seg7_show(buf);
    }

    return 0;   /* nie erreicht */
}
