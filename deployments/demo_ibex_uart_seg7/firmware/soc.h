/* ===========================================================================
 * soc.h - Memory-Map des Ibex-SoC (demo_ibex_uart_seg7) fuer C-Programme.
 *
 * Adressen muessen mit dem Adress-Dekoder im Deployment-Top
 * (rtl/demo_ibex_uart_seg7.sv) uebereinstimmen.
 * ===========================================================================*/
#ifndef SOC_H
#define SOC_H

#include <stdint.h>

/* --- 7-Segment-Anzeige @ 0x8000_0000 ----------------------------------- */
#define SEG7_BASE  0x80000000u
#define SEG7       (*(volatile uint32_t *)SEG7_BASE)

static inline void seg7_write(uint32_t value)
{
    SEG7 = value;
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
