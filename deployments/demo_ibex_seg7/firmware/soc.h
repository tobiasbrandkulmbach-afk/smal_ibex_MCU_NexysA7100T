/* ===========================================================================
 * soc.h - Memory-Map des Ibex-SoC (demo_ibex_seg7) fuer C-Programme.
 *
 * Adressen muessen mit dem Adress-Dekoder im Deployment-Top
 * (deployments/demo_ibex_seg7/rtl/demo_ibex_seg7.sv) uebereinstimmen.
 * ===========================================================================*/
#ifndef SOC_H
#define SOC_H

#include <stdint.h>

/* --- Memory-Map -----------------------------------------------------------
 *   IMEM  0x0000_0000 .. 0x0000_03FC   1 KB  read-only  (Programmcode)
 *   DMEM  0x0001_0000 .. 0x0001_3FFC  16 KB  read/write (Daten, Stack)
 *   SEG7  0x8000_0000 (LO) / 0x8000_0004 (HI)  Zeichen-Anzeige (ASCII-Font)
 * ------------------------------------------------------------------------- */

/* --- 7-Segment-Zeichenanzeige @ 0x8000_0000 ---------------------------- *
 * Zwei Register mit je 4 ASCII-Zeichen (Hardware-Font in lib/seg7):
 *   SEG7_LO: Byte0 = Stelle 0 (AN0, rechts) .. Byte3 = Stelle 3
 *   SEG7_HI: Byte0 = Stelle 4             .. Byte3 = Stelle 7 (AN7, links)
 */
#define SEG7_BASE  0x80000000u
#define SEG7_LO    (*(volatile uint32_t *)(SEG7_BASE + 0x0))
#define SEG7_HI    (*(volatile uint32_t *)(SEG7_BASE + 0x4))

/* 32-Bit-Wert als 8 Hex-Ziffern anzeigen (Stelle 0 = niederwertigstes Nibble). */
static inline void seg7_show_hex32(uint32_t v)
{
    static const char hexd[] = "0123456789ABCDEF";
    uint32_t lo = 0, hi = 0;
    for (int i = 0; i < 4; i++) {
        lo |= (uint32_t)(uint8_t)hexd[(v >> (i * 4)) & 0xF] << (i * 8);
        hi |= (uint32_t)(uint8_t)hexd[(v >> ((i + 4) * 4)) & 0xF] << (i * 8);
    }
    SEG7_LO = lo;
    SEG7_HI = hi;
}

#endif /* SOC_H */
