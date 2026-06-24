/* ===========================================================================
 * demo_ibex_uart_seg7 - Hochzaehler auf 7-Segment-Anzeige UND UART.
 *
 * Wie das seg7-Demo: ein 32-Bit-Wert wird hochgezaehlt und hex auf der
 * 8-stelligen Anzeige ausgegeben. Zusaetzlich wird jeder Wert als 8-stellige
 * Hex-Zahl ueber die USB-UART-Bruecke (115200 8N1) an den PC gesendet.
 *
 * Am PC mitlesen, z.B.:  picocom -b 115200 /dev/ttyUSB1
 *                  oder:  screen /dev/ttyUSB1 115200
 * ===========================================================================*/
#include "soc.h"

static void delay(volatile uint32_t loops)
{
    while (loops--) {
        /* nichts */
    }
}

/* 32-Bit-Wert als 8-stellige Hex-Zahl + CRLF senden. */
static void uart_put_hex32(uint32_t v)
{
    static const char hex[] = "0123456789ABCDEF";
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex[(v >> (i * 4)) & 0xF]);
    }
    uart_putc('\r');
    uart_putc('\n');
}

int main(void)
{
    uint32_t value = 0;

    uart_puts("demo_ibex_uart_seg7\r\n");

    for (;;) {
        seg7_write(value);       /* auf der 7-Segment-Anzeige */
        uart_put_hex32(value);   /* und ueber UART an den PC   */
        value++;
        delay(2000000u);         /* ~0,1 s sichtbar bei 100 MHz */
    }

    return 0;   /* nie erreicht */
}
