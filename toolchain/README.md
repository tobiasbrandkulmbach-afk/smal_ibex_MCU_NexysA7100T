# toolchain/ – RISC-V Cross-Compiler

Dieser Ordner enthält **ausschließlich die Toolchain-Konfiguration**, d. h. die
Auswahl und Einstellung des RISC-V-Cross-Compilers. Er ist projekt- und
deployment-unabhängig.

```
toolchain/
└── riscv-toolchain.cmake   # CMake-Toolchain-Datei (Compiler, ISA/ABI)
```

## Voraussetzungen (Arch Linux)

```bash
sudo pacman -S riscv64-elf-gcc riscv64-elf-newlib riscv64-elf-binutils cmake
```

> Der Paketname `riscv64-elf-gcc` ist korrekt – das newlib-Multilib enthält die
> 32-Bit-Variante. Gebaut wird für den Ibex mit `-march=rv32imc -mabi=ilp32`.
> Andere Präfixe (`riscv32-unknown-elf-`, `riscv-none-elf-`, …) erkennt die
> Toolchain-Datei automatisch; überschreibbar mit `-DRISCV_PREFIX=…`.

## Verwendung

Wird **nicht direkt** aufgerufen, sondern beim Konfigurieren einer
Deployment-Firmware übergeben:

```bash
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=<pfad>/toolchain/riscv-toolchain.cmake
```

## Zusammenhang

| Ordner | Inhalt |
|---|---|
| `toolchain/` | **nur** die Compiler-Konfiguration (dieser Ordner) |
| `sw/` | allgemeine, wiederverwendbare SW-Bausteine (`crt0.S`, `bin2mem.py`, `firmware.cmake`) |
| `deployments/<demo>/firmware/` | projektspezifische Firmware (`main.c`, `soc.h`, `ibex_soc.ld`, `CMakeLists.txt`) → erzeugt `imem.mem`/`dmem.mem` im Deployment |

Siehe `sw/README.md` für den kompletten Build-Ablauf.
