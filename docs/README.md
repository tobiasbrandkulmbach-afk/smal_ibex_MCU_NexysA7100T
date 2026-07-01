# RISC-V-Mikrocontroller – Forschungsmaster

Zentrale Doku des selbstgebauten RISC-V-SoC (LowRISC **Ibex** + eigene
Peripherie in SystemVerilog) auf dem **Nexys A7-100T**. Dieses Dokument ist die
alleinige Projektdoku (Architektur, Ziel-Hardware, Bibliothek, Deployments,
Build-/Flash-Workflow, Konventionen).

---

## 1. Projektziel

Entwicklung eines vollständigen RISC-V-Mikrocontrollers. Als **CPU-Core** wird
der von LowRISC bereitgestellte **Ibex-Core unverändert** übernommen
(Standalone-Variante, ohne OpenTitan-Wrapper). Die gesamte **Peripherie** wird
von Grund auf selbst geschrieben und an das **native Ibex-Memory-Interface**
angebunden.

---

## 2. Ziel-Hardware

| Merkmal | Detail |
|---|---|
| Board | Digilent Nexys A7-100T |
| FPGA | AMD/Xilinx Artix-7 **XC7A100T-1CSG324C** (63.400 LUTs, 126.800 FF, 1.188 Kb BRAM, 240 DSP) |
| Takt | 100 MHz Onboard-Oszillator (Pin **E3**, LVCMOS33) |
| RAM / Flash | 128 MB DDR2 / 16 MB Quad-SPI |
| Schnittstellen | UART, USB, 10/100 Ethernet, VGA, JTAG, 5× Pmod |

### Relevante I/O
| Peripherie | Details |
|---|---|
| Buttons | BTNC, BTNU, BTNL, BTNR, BTND – alle **active-HIGH** |
| Switches / LEDs | 16× `SW[15:0]` / 16× `LED[15:0]` |
| 7-Segment | 8 Stellen, **common-anode**; Segmente CA–CG + DP und Anoden `AN[7:0]` **active-LOW** |

**7-Segment-Multiplexing:** Alle Segmentleitungen sind zwischen den 8 Stellen
geteilt; immer nur eine Stelle wird über `AN[7:0]` aktiviert, die Logik rotiert
zyklisch durch alle Stellen (~1 kHz pro Stelle). Implementiert in `lib/seg7`.

I/O-Standard aller Nexys-A7-Pins: **LVCMOS33**.

---

## 3. Architektur

### CPU – LowRISC Ibex
- RV32IMC, 2-stufige Pipeline; unverändert als git-submodule in `lib/ibex/`
  (Wrapper `ibex_top`).
- Zwei **getrennte native Memory-Interfaces**: Instruktions-Bus (nur Fetch) und
  Daten-Bus (Load/Store).
- Boot: Reset-PC = `BootAddr + 0x80`, Trap-Vektor-Basis = `BootAddr + 0x00`.
  In allen Deployments ist `BootAddr = 0` → `_start` bei `0x0000_0080`.

### Ibex-Memory-Interface (nativ, kein AXI/TileLink)
Zweiphasiger Handshake pro Bus:
1. **Request:** Core hält `*_req_o` + Adresse stabil, bis `*_gnt_i` einen Takt
   high ist.
2. **Response:** Speicher antwortet ≥1 Takt später mit `*_rvalid_i` + Daten.

| Instruction-Bus | Data-Bus |
|---|---|
| `instr_req_o`, `instr_gnt_i` | `data_req_o`, `data_gnt_i` |
| `instr_addr_o` (32) | `data_addr_o` (32), `data_we_o`, `data_be_o` (4) |
| `instr_rvalid_i`, `instr_rdata_i` (32) | `data_rvalid_i`, `data_rdata_i`/`data_wdata_o` (32) |
| `instr_err_i` | `data_err_i` |

### Speichermodell (echte Harvard-Trennung)
Der Ibex-Datenbus kann das **IMEM nicht lesen**. Deshalb:
- **IMEM** (`0x0000_0000`) = nur **Code**, nur Instruktions-Bus, Init `imem.mem`.
- **DMEM** (`0x0001_0000`) = **alle Daten** (rodata, `.data`, `.bss`, Stack),
  Datenbus-R/W, Init `dmem.mem`.
- Beide werden beim FPGA-Bitstream per `$readmemh` initialisiert; `crt0` kopiert
  nichts, sondern nullt nur `.bss` (Details: [`../sw/README.md`](../sw/README.md)).
- Reset-Hinweis: `.data`/rodata werden nur bei der FPGA-Konfiguration gesetzt;
  ein Warm-Reset (BTNC) setzt veränderte globale `.data`-Variablen **nicht**
  zurück.

### Peripherie-Bus (interne Signatur)
Alle Peripherie-/Speichermodule nutzen dieselbe Signatur wie `lib/ram` /
`lib/peri_reg`:

| Signal | Richtung | Bedeutung |
|---|---|---|
| `req_i` | → Slave | Chip-Select (vom Parent dekodiert) |
| `we_i` / `be_i` | → Slave | Write-Enable / Byte-Enables |
| `addr_i` | → Slave | interne Registerauswahl (falls mehrere) |
| `wdata_i` / `rdata_o` | ↔ | 32-Bit Schreib-/Lesedaten |

- **Read-Latenz: 1 Takt** (registriert). Das **Address-Decoding macht der
  Deployment-Top** (`sel_*`); der Top verzögert den `sel`-Vektor um 1 Takt und
  muxt daraus `data_rdata`, `gnt`/`rvalid` folgen aus `req`.

### Typische Speicher-Map (Ibex-Deployment)
| Region | Adresse | Zugriff |
|---|---|---|
| IMEM | `0x0000_0000..0x0000_03FC` | Instr-Bus, read-only |
| DMEM | `0x0001_0000..0x0001_3FFC` | Datenbus, R/W |
| SEG7 | `0x8000_0000` / `0x8000_0004` | 2 Register (je 4 ASCII-Zeichen) |
| UART | `0x9000_0000` (DATA) / `0x9000_0004` (STATUS) | Byte-Gerät |

---

## 4. Bibliothek (`lib/`)

Jedes Modul liegt flach unter `lib/<name>/` mit `rtl/`, `tb/`, `sim/` und ist
**einzeln per Questa simulierbar** (`cd lib/<name>/sim && vsim -c -do sim.do`,
gibt `PASS`/`FAIL`).

| Modul | Zweck |
|---|---|
| `ram` | Synchrones Single-Port-RAM (parametrierbar, `$readmemh`-Init) |
| `peri_reg` | Memory-mapped 32-Bit-Register (RW oder read-only/hw-getrieben), Byte-Enables |
| `debouncer` | Synchroner Tasten-Entpreller |
| `counter` | Up/Down-Zähler (entprellte Eingänge) |
| `seg7` | **Zeichen**-7-Segment-Controller: 8 ASCII-Bytes → Segmente, Hardware-Font, Multiplexing aller 8 Stellen |
| `seg7_hex` | Adapter: 32-Bit-Wert → 8 Hex-Ziffern → `seg7` (port-kompatibel zum früheren Hex-`seg7`) |
| `seg7_periph` | Bus-Wrapper um `seg7`: zwei Register `CHARS_LO`/`CHARS_HI` (8 Zeichen) |
| `uart_tx` / `uart_rx` | UART-Sender/-Empfänger (parametrierbare Baudrate) |
| `uart_periph` | Bus-Wrapper: `DATA`/`STATUS`-Register (tx_ready/rx_valid/overrun) |
| `ibex` | LowRISC Ibex-Core (submodule + `files.f` + `ibex.tcl`) |

### 7-Segment-Zeichenanzeige im Detail
- **Font** (`lib/seg7/rtl/seg7.sv`, `ascii_to_segs`): `0–9`, darstellbare
  Buchstaben (`A b C d E F G H I J L n o P q r S t U y`, `Z` als „2"), `-`, `_`.
  Groß-/Kleinschreibung gleich; nicht darstellbare Zeichen (K M V W X, Space,
  Steuerzeichen) → leer.
- **`seg7_periph`-Registermap** (`addr_i` = Wort-Offset-Bit):
  - `+0x0` `CHARS_LO`: Byte0 = Stelle 0 (AN0, rechts) … Byte3 = Stelle 3
  - `+0x4` `CHARS_HI`: Byte0 = Stelle 4 … Byte3 = Stelle 7 (AN7, links)
- **C-Nutzung** (Deployment-`soc.h`): `seg7_show(buf)` für 8 Zeichen bzw.
  `seg7_show_hex32(v)` für einen Zahlwert.

---

## 5. Deployments (`deployments/`)

Je Deployment: `rtl/` (Top), `constraints/` (Nexys-XDC), `scripts/` (Vivado
TCL) und **`befehle.txt`** (Befehlsfolge). Ibex-Demos zusätzlich `firmware/` (C).

| Deployment | CPU | Zeigt | Besonderheit |
|---|---|---|---|
| `demo_counter_seg7` | — (reine Logik) | Hochzähler in Hex | Zähler → `seg7_hex` |
| `demo_counter_ram_seg7` | — | Zähler über RAM → Hex | Counter→RAM→`seg7_hex` (RAM aus `anim.mem`) |
| `demo_ibex_seg7` | Ibex | Hochzähler (Hex-Ziffern) | Ibex + C, `seg7_show_hex32` |
| `demo_ibex_uart_seg7` | Ibex | Zähler auf 7-Seg **und** UART | + `uart_periph` |
| `demo_ibex_uart_text` | Ibex | UART-Zeichen als **Lauftext** | RX → Scrollpuffer → `seg7_periph` |

---

## 6. Software-/Firmware-Workflow

Gemeinsame, deployment-unabhängige Bausteine in [`../sw/`](../sw/):
`crt0.S` (Startup: Stack, `.bss` nullen, `main`), `firmware.cmake`
(`add_firmware()`), `bin2mem.py` (Binär → `$readmemh`). RISC-V-Cross-Toolchain
in [`../toolchain/riscv-toolchain.cmake`](../toolchain/riscv-toolchain.cmake)
(RV32IMC/ilp32, Prefix wird automatisch gesucht).

Firmware bauen (aus einem Deployment-`firmware/`-Ordner):
```bash
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=../../../toolchain/riscv-toolchain.cmake
cmake --build build      # erzeugt ../imem.mem + ../dmem.mem, zeigt size
```
Code-/Daten-Split: IMEM = `.text`, DMEM = `.rodata`+`.data`+`.bss`;
`imem.mem`/`dmem.mem` werden per `objcopy -j <section>` erzeugt (Details in
[`../sw/README.md`](../sw/README.md)).

---

## 7. Simulation & FPGA-Deployment

### Simulation (Questa/ModelSim, CLI)
```bash
cd lib/<modul>/sim && vsim -c -do sim.do     # erwartet PASS
```

### FPGA (Vivado, Batch)
Vivado-Aufrufe **aus dem `out/`-Ordner** des Deployments starten, damit alle
Nebendateien (`vivado.jou`/`.log`, `clockInfo.txt`, `tight_setup_hold_pins.txt`,
`.Xil/`) dort landen und sich nicht im Deployment-/Hauptordner stapeln. Die
`build.tcl` wechselt selbst nach `out/` und spiegelt die `.mem`-Dateien dorthin.
```bash
source ~/AMD/2025.2/Vivado/settings64.sh
mkdir -p deployments/<demo>/out && cd deployments/<demo>/out
vivado -mode batch -source ../scripts/build.tcl     # Synthese→Bitstream
vivado -mode batch -source ../scripts/program.tcl   # JTAG (flüchtig)
vivado -mode batch -source ../scripts/flash.tcl     # QSPI-Flash (.mcs, autonomer Boot)
../scripts/update_mem.sh                             # nur Programm patchen (nur Ibex-Demos)
cd - >/dev/null
```
Schneller Programm-Wechsel (Ibex-Demos): Firmware neu bauen, dann
`update_mem.sh` (patcht `imem.mem` per `updatemem` in den fertigen Bitstream,
ohne Synthese), dann `program.tcl`.

UART mitlesen/senden:
```bash
screen /dev/ttyUSB1 115200
```

Die genaue Befehlsfolge je Deployment steht in der jeweiligen `befehle.txt`.

---

## 8. Entwicklungsstrategie & Konventionen
- Jedes Bibliotheksmodul wird **einzeln in Questa simuliert**, bevor es in ein
  Deployment integriert wird; Deployments in gröberen Integrationsschritten.
- RTL nur **SystemVerilog**, `snake_case`, Dateiname = Modulname.
- Testbench `tb_<modul>.sv`, endet mit `PASS`/`FAIL` + `$finish`.
- Constraints: `deployments/<demo>/constraints/Nexys-A7-100T-Master.xdc`.
- Alle Nexys-A7-Pins **LVCMOS33**; 7-Segment common-anode, active-LOW.
- Keine proprietären IP-Cores außer dem LowRISC Ibex-Core.
