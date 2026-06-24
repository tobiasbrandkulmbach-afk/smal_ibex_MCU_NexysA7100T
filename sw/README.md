# sw/ – Allgemeine Firmware-Bausteine

Wiederverwendbare, **deployment-unabhängige** Bestandteile zum Bauen von
C-Firmware für den Ibex-SoC. Hier liegt nichts Projektspezifisches – Memory-Map,
Peripherie-Adressen und das eigentliche Programm gehören ins jeweilige
Deployment (`deployments/<demo>/firmware/`).

```
sw/
├── crt0.S          # C-Runtime-Startup: Stack, .data kopieren, .bss nullen, main()
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
  – `text + data` muss in den IMEM passen, sonst bricht `bin2mem.py` ab.

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

| C-Konstrukt | Section | liegt in | in welcher `.mem` |
|---|---|---|---|
| Code, Funktionen | `.text` | IMEM | `imem.mem` |
| `const`, String-Literale | `.rodata` | IMEM | `imem.mem` |
| globale Variablen mit Initialwert | `.data` | DMEM (Init-Wert im IMEM) | Init-Wert in `imem.mem` |
| globale Variablen ohne/0-Init | `.bss` | DMEM | – (von `crt0` genullt) |
| lokale Variablen, Stack | – | DMEM | – (Laufzeit) |

`crt0.S` kopiert beim Start `.data` vom IMEM-Ladeabbild ins DMEM und nullt
`.bss`, bevor `main()` aufgerufen wird.
