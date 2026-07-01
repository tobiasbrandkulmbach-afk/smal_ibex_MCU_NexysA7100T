/* ===========================================================================
 * soc.h - Memory-Map des Ibex-SoC (demo_ibex_uart_text) fuer C-Programme.
 *
 * Adressen muessen mit dem Adress-Dekoder im Deployment-Top
 * (rtl/demo_ibex_uart_text.sv) uebereinstimmen.
 * ===========================================================================*/
#ifndef SOC_H
#define SOC_H

#include <stdint.h>

/* --- 7-Segment-Zeichenanzeige @ 0x8000_0000 ---------------------------- *
 * Zwei Register mit je 4 ASCII-Zeichen. Der Hardware-Font (lib/seg7) macht
 * daraus die Segmentmuster.
 *   SEG7_LO: Byte0 = Stelle 0 (AN0, rechts) .. Byte3 = Stelle 3
 *   SEG7_HI: Byte0 = Stelle 4             .. Byte3 = Stelle 7 (AN7, links)
 */
#define SEG7_BASE  0x80000000u
#define SEG7_LO    (*(volatile uint32_t *)(SEG7_BASE + 0x0))
#define SEG7_HI    (*(volatile uint32_t *)(SEG7_BASE + 0x4))

/* Zeigt 8 Zeichen an. buf[0] = linke Stelle (AN7), buf[7] = rechte (AN0). */
static inline void seg7_show(const char buf[8])
{
    SEG7_LO = ((uint32_t)(uint8_t)buf[7])       |
              ((uint32_t)(uint8_t)buf[6] << 8)  |
              ((uint32_t)(uint8_t)buf[5] << 16) |
              ((uint32_t)(uint8_t)buf[4] << 24);
    SEG7_HI = ((uint32_t)(uint8_t)buf[3])       |
              ((uint32_t)(uint8_t)buf[2] << 8)  |
              ((uint32_t)(uint8_t)buf[1] << 16) |
              ((uint32_t)(uint8_t)buf[0] << 24);
}

/* --- UART @ 0x9000_0000 ------------------------------------------------- */
#define UART_BASE     0x90000000u
#define UART_DATA     (*(volatile uint32_t *)(UART_BASE + 0x0))  /* W: senden, R: empfangen */
#define UART_STATUS   (*(volatile uint32_t *)(UART_BASE + 0x4))  /* read-only */

#define UART_TX_READY (1u << 0)   /* TX frei, neues Byte schreibbar */
#define UART_RX_VALID (1u << 1)   /* empfangenes Byte wartet        */
#define UART_OVERRUN  (1u << 2)   /* Byte ging verloren             */

/* Blockiert, bis der Sender frei ist, dann ein Byte senden. */
static inline void uart_putc(char c)
{
    while (!(UART_STATUS & UART_TX_READY)) { }
    UART_DATA = (uint8_t)c;
}

static inline void uart_puts(const char *s)
{
    while (*s) uart_putc(*s++);
}

static inline int uart_rx_ready(void)
{
    return (UART_STATUS & UART_RX_VALID) != 0;
}

/* Blockiert, bis ein Byte da ist, und liefert es (loescht rx_valid). */
static inline char uart_getc(void)
{
    while (!(UART_STATUS & UART_RX_VALID)) { }
    return (char)(UART_DATA & 0xFF);
}

#endif /* SOC_H */
