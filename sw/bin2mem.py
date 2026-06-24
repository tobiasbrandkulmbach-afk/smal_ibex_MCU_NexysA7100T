#!/usr/bin/env python3
# ===========================================================================
# bin2mem.py - wandelt ein rohes Binaer-Abbild (objcopy -O binary) in das
# $readmemh-Format der ram.sv um: ein 32-Bit-Wort (little-endian) pro Zeile,
# als 8-stellige Hex-Zahl.
#
# Beispiele:
#   bin2mem.py firmware.bin -o imem.mem --words 256
#   bin2mem.py --zero       -o dmem.mem --words 4096
# ===========================================================================
import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description="raw binary -> $readmemh word list")
    ap.add_argument("input", nargs="?", help="Eingabe-Binaerdatei (entfaellt bei --zero)")
    ap.add_argument("-o", "--output", required=True, help="Ausgabe .mem")
    ap.add_argument("--words", type=int, default=0,
                    help="Auf genau N Woerter auffuellen/pruefen (0 = exakt Eingabelaenge)")
    ap.add_argument("--zero", action="store_true",
                    help="Nur Nullen ausgeben (--words erforderlich)")
    args = ap.parse_args()

    if args.zero:
        data = b""
    else:
        if not args.input:
            ap.error("input fehlt (oder --zero verwenden)")
        with open(args.input, "rb") as f:
            data = f.read()

    # Auf 4-Byte-Grenze auffuellen
    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)

    nwords = len(data) // 4

    if args.words:
        if nwords > args.words:
            print(f"FEHLER: Abbild belegt {nwords} Woerter, "
                  f"Speicher hat aber nur {args.words}.", file=sys.stderr)
            return 1
        data += b"\x00" * ((args.words - nwords) * 4)
        nwords = args.words

    with open(args.output, "w") as out:
        for i in range(nwords):
            word = int.from_bytes(data[i * 4:i * 4 + 4], "little")
            out.write(f"{word:08x}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
