# RISC-V Mikrocontroller – Forschungsmaster

## Projektziel

Entwicklung eines vollständigen RISC-V-basierten Mikrocontrollers im Rahmen des Forschungsmasters. Als **CPU-Core** wird der von **LowRISC bereitgestellte Ibex-Core** (OpenTitan) unverändert übernommen. Die gesamte **Peripherie** wird von Grund auf selbst in SystemVerilog geschrieben und muss mit dem LowRISC TL-UL-Bus kompatibel sein.

---

## Ziel-Hardware

| Merkmal | Detail |
|---|---|
| Board | Digilent Nexys A7-100T |
| FPGA | AMD/Xilinx Artix-7 **XC7A100T-1CSG324C** |
| LUTs | 63.400 |
| Flip-Flops | 126.800 |
| Block RAM | 1.188 Kb |
| DSP Slices | 240 |
| Takt | 100 MHz Onboard-Oszillator (Pin **E3**, LVCMOS33) |
| RAM | 128 MB DDR2 |
| Flash | 16 MB Quad-SPI |
| Schnittstellen | UART, USB, 10/100 Ethernet, VGA, JTAG, 5× Pmod |

### Nexys A7 – relevante I/O für dieses Projekt

| Peripherie | Details |
|---|---|
| Buttons | 5 Stück: BTNC, BTNU, BTNL, BTNR, **BTND** – alle Active-HIGH |
| Switches | 16× SW[15:0] |
| LEDs | 16× LED[15:0] |
| 7-Segment | 8 Stellen, **Common-Anode**, Segmente CA–CG + DP (Active-LOW), Anoden AN[7:0] (Active-LOW) |

**7-Segment-Multiplexing:** Alle Segmentleitungen (CA–CG, DP) sind zwischen allen 8 Stellen geteilt. Immer nur eine Stelle wird über AN[7:0] aktiviert; die Schaltlogik muss zyklisch durch alle Stellen rotieren (typisch ~1 kHz pro Stelle).

---

## LowRISC Ibex-Core

- **Typ:** 32-Bit RISC-V In-Order-Core (2–3 Stufen Pipeline)
- **ISA:** RV32IMC + optional B, Zcb, Zcmp
- **Performance:** bis zu 3,13 CoreMarks/MHz
- **Fläche (min):** ~15 kGates
- **Projekt:** OpenTitan Earl Grey (Dual-Lockstep-Konfiguration)
- **Bus-Interface:** Datenspeicher- und Instruktionsspeicher-Interface werden im `rv_core_ibex`-Wrapper auf **TL-UL** gemappt
- Repository: [github.com/lowRISC/ibex](https://github.com/lowRISC/ibex)

---

## TL-UL Bus (TileLink Uncached Lightweight)

Alle selbst geschriebenen Peripheriemodule müssen das TL-UL-Interface implementieren. Die Signale sind in zwei Structs organisiert:

### Host → Device (`tl_h2d_t`)

| Signal | Breite | Beschreibung |
|---|---|---|
| `a_valid` | 1 | Request gültig |
| `a_ready` | 1 | Device bereit (Rückkanal im Handshake) |
| `a_opcode` | 3 | `Get` (Lesen), `PutFullData`, `PutPartialData` |
| `a_param` | 3 | Protokollparameter (meist 0) |
| `a_size` | 2 | Transfergröße (2^n Bytes) |
| `a_source` | TL_AIW | Request-ID für Response-Routing |
| `a_address` | TL_AW | Zieladresse |
| `a_mask` | TL_DBW | Byte-Enable-Maske |
| `a_data` | TL_DW | Schreibdaten |
| `a_user` | – | OpenTitan-spezifische User-Bits |

### Device → Host (`tl_d2h_t`)

| Signal | Breite | Beschreibung |
|---|---|---|
| `d_valid` | 1 | Response gültig |
| `d_ready` | 1 | Host bereit (Rückkanal) |
| `d_opcode` | 3 | `AccessAck` (Write-ACK), `AccessAckData` (Read-Data) |
| `d_param` | 3 | Protokollparameter |
| `d_size` | 2 | Transfergröße |
| `d_source` | TL_AIW | Gespiegeltes Request-ID |
| `d_data` | TL_DW | Lesedaten |
| `d_error` | 1 | Fehlerflag |
| `d_user` | – | OpenTitan-spezifische User-Bits |

Referenz: [OpenTitan TL-UL Spec](https://opentitan.org/book/hw/ip/tlul/)

---

## Toolchain

| Tool | Zweck | Lizenz |
|---|---|---|
| **Questa Intel FPGA Starter Edition** | Simulation (CLI) | Kostenlos (ehem. ModelSim-Intel) |
| **AMD Vivado** (Standard Edition) | Synthese, P&R, Bitstream, Deployment | Kostenlos |

> Hinweis: Intel hat ModelSim-Intel offiziell durch **Questa-Intel FPGA Edition** ersetzt. Der Starter-Tier ist kostenlos; Kommandozeilen-Workflow (`vlib`, `vlog`, `vsim`) bleibt identisch.

---

## Projektstruktur

```
Forschungsmaster_main/
├── lib/               # SystemVerilog-Bibliothek – alle wiederverwendbaren Module (flach)
│   ├── ram/
│   ├── tl_adapter/
│   ├── debouncer/
│   ├── counter/
│   ├── seg7/
│   └── …
└── deployments/       # FPGA-Deployments – je Demo ein eigener Ordner
    ├── demo_memory/
    └── …
```

### `lib/` – Die SystemVerilog-Bibliothek

Alle selbst geschriebenen Module leben **flach** in `lib/`. Jedes Modul hat seinen eigenen Unterordner:

```
lib/<modulname>/
├── rtl/     # Synthesefähiger RTL-Code (<modulname>.sv)
├── sim/     # Questa/ModelSim-Skripte (.do / Makefile)
└── tb/      # Testbench (tb_<modulname>.sv)
```

- Module können andere Bibliotheksmodule instanziieren (Kombinationen erlaubt).
- Jedes Modul ist **eigenständig simulier- und testbar**.
- Kein Modul in `lib/` enthält FPGA-spezifische Constraints oder Top-Level-Logik.

### `deployments/` – FPGA-Deployments

```
deployments/<demo_name>/
├── rtl/                   # Top-Level SystemVerilog (instanziiert lib-Module)
├── constraints/           # Nexys-A7-100T-Master.xdc
└── scripts/               # Vivado TCL-Build-Skript (build.tcl)
```

- Kein Deployment-Ordner hat eine eigene `sim/` oder `tb/` – Simulation läuft auf Ebene der Einzelmodule in `lib/`.

---

## Entwicklungsstrategie

1. Jedes Bibliotheksmodul wird **einzeln entworfen und in Questa/ModelSim simuliert**, bevor es integriert wird.
2. Erst wenn alle benötigten Module verifiziert sind, wird ein Deployment zusammengestellt.
3. FPGA-Deployment erfolgt in **gröberen Integrationsschritten**.
4. Simulation ausschließlich **via Kommandozeile** – kein GUI-Workflow.

---

## Roadmap

### Phase 1: Speicher-Bibliotheksmodule

| Modul | Pfad | Beschreibung |
|---|---|---|
| RAM | `lib/ram/` | Synchrones Single-Port-RAM, parametrierbar (Breite, Tiefe) |
| TL-UL Adapter | `lib/tl_adapter/` | Anbindung des RAM an TL-UL (Get / PutFullData / PutPartialData) |

### Phase 2: Demo-Bibliotheksmodule

| Modul | Pfad | Beschreibung |
|---|---|---|
| Button-Debouncer | `lib/debouncer/` | Synchroner Entpreller, parametrierbare Filtertiefe |
| Adress-Counter | `lib/counter/` | Up/Down-Counter; Eingänge `btn_up`, `btn_dn` (entprellt) |
| 7-Segment-Controller | `lib/seg7/` | Hex→Segmente, Multiplexing aller 8 Stellen, Active-LOW |

### Phase 2b: FPGA-Deployment – Speicher-Demo

| Deployment | Pfad | Beschreibung |
|---|---|---|
| Speicher-Demo | `deployments/demo_memory/` | Counter → RAM → 7-Segment auf Nexys A7-100T |

### Phase 3: Weitere Peripherie (geplant)

- GPIO-Controller
- UART
- Timer / PWM
- Interrupt-Controller
- Vollständige Anbindung an LowRISC Ibex-Core

---

## Simulation mit Questa/ModelSim (Konsole)

```bash
# Beispiel für ein Bibliotheksmodul (aus lib/<modul>/sim/)
vlib work
vlog ../rtl/<modul>.sv ../tb/tb_<modul>.sv
vsim -c tb_<modul> -do "run -all; quit"
```

Jede Testbench gibt `PASS` oder `FAIL` auf der Konsole aus und endet mit `$finish`.

## Deployment mit Vivado (Batch)

```bash
vivado -mode batch -source deployments/<demo>/scripts/build.tcl
```

Das TCL-Skript übernimmt: Quellen einbinden, Constraints laden, Synthese, Implementation, Bitstream generieren.

---

## Konventionen

- RTL ausschließlich in **SystemVerilog**
- Modulnamen: `snake_case`, Dateiname = Modulname
- Testbench-Dateinamen: `tb_<modulname>.sv`
- Jede Testbench endet mit `PASS`/`FAIL`-Ausgabe und `$finish`
- Constraints-Datei: `deployments/<demo>/constraints/Nexys-A7-100T-Master.xdc`
- Keine proprietären IP-Cores – alles selbst geschrieben (außer LowRISC Ibex-Core)
- I/O-Standard aller Nexys A7 Pins: **LVCMOS33**
