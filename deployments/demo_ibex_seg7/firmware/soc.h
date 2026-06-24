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
 *   SEG7  0x8000_0000                  1 Reg write       (Hex-Anzeige)
 * ------------------------------------------------------------------------- */

#define SEG7_BASE  0x80000000u

/* 32-Bit-Wert -> 8-stellige Hex-Anzeige (Nexys A7, 7-Segment). */
#define SEG7       (*(volatile uint32_t *)SEG7_BASE)

static inline void seg7_write(uint32_t value)
{
    SEG7 = value;
}

#endif /* SOC_H */
