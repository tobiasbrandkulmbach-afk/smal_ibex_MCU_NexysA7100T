# sw/ – Allgemeine Firmware-Bausteine

Wiederverwendbare, **deployment-unabhängige** Bestandteile zum Bauen von
C-Firmware für den Ibex-SoC. Hier liegt nichts Projektspezifisches – Memory-Map,
Peripherie-Adressen und das eigentliche Programm gehören ins jeweilige
Deployment (`deployments/<demo>/firmware/`).

```
sw/
├── crt0.S          # C-Runtime-Startup: Stack setzen, .bss nullen, main()
├── bin2mem.py      # .bin (objcopy) → $readmemh-Format (.mem)
└── firmware.cmake  # add_firmware()-Funktion (von Deployments inkludiert)
```

## Build-Ablauf (3 Ordner)

```
toolchain/riscv-toolchain.cmake   ─┐  Compiler-Auswahl (RV32IMC)
sw/  (crt0, bin2mem, add_firmware) ─┤  allgemeine Bausteine
deployments/<demo>/firmware/       ─┘  main.c, soc.h, ibex_soc.ld, CMakeLists.txt
        │
        └─ cmake --build ─► deployments/<demo>/imem.mem + dmem.mem
                                 │
                                 └─ vivado build.tcl ─► Bitstream ─► FPGA
```

C-Quelle ──`gcc`──► `.elf` ──`objcopy`──► `.bin` ──`bin2mem.py`──► `imem.mem`/`dmem.mem`

## Eine Firmware bauen

Aus dem Firmware-Ordner eines Deployments, z. B. `deployments/demo_ibex_seg7/firmware/`:

```bash
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=../../../toolchain/riscv-toolchain.cmake
cmake --build build
```

Ergebnis:
- `deployments/demo_ibex_seg7/imem.mem` / `dmem.mem`  (ins Deployment geschrieben)
- im `build/`-Ordner zusätzlich `firmware.elf`, `firmware.lst` (Disassembly),
  `firmware.map` (Symbole). Die `size`-Ausgabe am Ende zeigt `text`/`data`/`bss`
  – `.text` muss in den IMEM passen, `.rodata`+`.data`+`.bss`+Stack ins DMEM,
  sonst bricht `bin2mem.py` bzw. der Linker ab.

Danach Bitstream bauen wie gewohnt:

```bash
vivado -mode batch -source deployments/demo_ibex_seg7/scripts/build.tcl
```

## add_firmware() – Schnittstelle

`firmware.cmake` stellt `add_firmware(<name> <quellen...>)` bereit. Das
Deployment-CMakeLists muss vor dem `include` folgende Variablen setzen:

| Variable | Bedeutung |
|---|---|
| `SW_COMMON_DIR` | Pfad zu diesem `sw/`-Ordner |
| `LINKER_SCRIPT` | Linker-Script des Deployments (Memory-Map) |
| `IMEM_WORDS` / `DMEM_WORDS` | Speichertiefen (müssen zur RTL `ram`-`AddrWidth` passen) |
| `MEM_OUTPUT_DIR` | Zielordner für `imem.mem`/`dmem.mem` (i. d. R. der Deployment-Ordner) |

## Speicher-Layout (vom Linker-Script gesteuert)

**Echte Harvard-Trennung:** IMEM enthält nur Code, DMEM alle Daten. Der
Daten-Bus des Ibex greift nie aufs IMEM zu. Beide Speicher werden getrennt
per `objcopy -j <section>` aus der ELF extrahiert und über `imem.mem` /
`dmem.mem` beim FPGA-Bitstream (`$readmemh`) initialisiert.

| C-Konstrukt | Section | liegt in | in welcher `.mem` |
|---|---|---|---|
| Code, Funktionen | `.text` | IMEM | `imem.mem` |
| `const`, String-Literale | `.rodata` | DMEM | `dmem.mem` |
| globale Variablen mit Initialwert | `.data` | DMEM | `dmem.mem` |
| globale Variablen ohne/0-Init | `.bss` | DMEM | – (von `crt0` genullt) |
| lokale Variablen, Stack | – | DMEM | – (Laufzeit) |

`crt0.S` nullt nur noch `.bss` und ruft dann `main()` auf – rodata und
initialisierte `.data`-Globals sind bereits resident im DMEM (kein Copy).

> **Reset-Hinweis:** Da `.data`/rodata nur bei der FPGA-Konfiguration
> (BRAM-Init aus `dmem.mem`) gesetzt werden, setzt ein **Warm-Reset (BTNC)**
> veränderte globale `.data`-Variablen *nicht* auf ihren Initialwert zurück.
> Für echtes Re-Init bei jedem Reset müsste man zum crt0-Copy-Muster
> (Init-Abbild im IMEM) zurückkehren.
