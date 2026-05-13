# RISC-V Mikrocontroller – Forschungsmaster

## Projektziel

Entwicklung eines vollständigen RISC-V-basierten Mikrocontrollers im Rahmen des Forschungsmasters. Als **CPU-Core** wird der von **LowRISC bereitgestellte Ibex-Core** unverändert übernommen (Standalone-Variante, ohne OpenTitan-Wrapper). Die gesamte **Peripherie** wird von Grund auf selbst in SystemVerilog geschrieben und an das **native Ibex-Memory-Interface** angebunden.

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
- **Bus-Interface:** Natives Ibex-Memory-Protokoll (Request/Grant/Valid-Handshake), getrennt für Instruktions- und Datenseite
- Repository: [github.com/lowRISC/ibex](https://github.com/lowRISC/ibex)

---

## Ibex Memory-Interface

Der Standalone-Ibex exponiert zwei voneinander unabhängige, einfache Memory-Interfaces (kein TileLink, kein AXI). Alle selbst geschriebenen Peripheriemodule werden über einen kleinen Adress-Dekoder hinter diesen Interfaces angesprochen.

### Instruction-Interface (read-only)

| Signal | Richtung | Breite | Beschreibung |
|---|---|---|---|
| `instr_req_o` | Core → Mem | 1 | Request gültig, bleibt high bis `instr_gnt_i` |
| `instr_addr_o` | Core → Mem | 32 | Adresse (wortaligniert) |
| `instr_gnt_i` | Mem → Core | 1 | Request angenommen (1 Takt) |
| `instr_rvalid_i` | Mem → Core | 1 | Lesedaten gültig |
| `instr_rdata_i` | Mem → Core | 32 | Gelesene Instruktion |
| `instr_err_i` | Mem → Core | 1 | Memory-Fehler |

### Data-Interface (Load/Store)

| Signal | Richtung | Breite | Beschreibung |
|---|---|---|---|
| `data_req_o` | Core → Mem | 1 | Request gültig |
| `data_gnt_i` | Mem → Core | 1 | Request angenommen |
| `data_we_o` | Core → Mem | 1 | Write Enable |
| `data_be_o` | Core → Mem | 4 | Byte-Enables |
| `data_addr_o` | Core → Mem | 32 | Adresse |
| `data_wdata_o` | Core → Mem | 32 | Schreibdaten |
| `data_rvalid_i` | Mem → Core | 1 | Lesedaten gültig |
| `data_rdata_i` | Mem → Core | 32 | Lesedaten |
| `data_err_i` | Mem → Core | 1 | Memory-Fehler |

### Handshake (zweiphasig)

1. **Request:** Core hält `*_req_o` + Adresse stabil, bis `*_gnt_i` einen Takt high ist. Request wird damit angenommen, der Core darf in derselben oder einer späteren Taktflanke einen Folge-Request starten.
2. **Response:** Speicher antwortet ≥1 Takt später mit `*_rvalid_i` und den Daten. Mehrere Requests dürfen outstanding sein.

Referenz: [Ibex Load-Store Unit](https://ibex-core.readthedocs.io/en/latest/03_reference/load_store_unit.html), [Ibex Instruction Fetch](https://ibex-core.readthedocs.io/en/latest/03_reference/instruction_fetch.html)

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
│   ├── ibex/          # LowRISC Ibex-Core (git submodule + Filelists)
│   │   ├── upstream/  # git submodule → github.com/lowRISC/ibex
│   │   ├── files.f    # Dateiliste für Questa/Simulation
│   │   └── ibex.tcl  # Vivado-Snippet (source aus build.tcl)
│   ├── ram/
│   ├── peri_reg/
│   ├── debouncer/
│   ├── counter/
│   ├── seg7/
│   ├── seg7_periph/
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
- **Ausnahme `lib/ibex/`:** Der Ibex-Core ist ein externes git submodule und folgt nicht dem üblichen `rtl/sim/tb`-Muster. Stattdessen: `upstream/` (submodule), `files.f` (Dateiliste), `ibex.tcl` (Vivado-Snippet). Kein eigener Simulationstest – der Core wird unverändert übernommen.

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
| Peripherie-Register | `lib/peri_reg/` | Memory-mapped 32-Bit-Register, RW oder READ_ONLY (hw_i-getrieben), Byte-Enables |

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

### Phase 3: Ibex-Anbindung (geplant)

| Schritt | Beschreibung |
|---|---|
| Ibex-Core | `lib/ibex/` – git submodule, bereits integriert |
| Ibex-Mem-Adapter | Adapter Ibex-native-Interface ↔ interne Req/We/Be-Signatur (Instruction + Data) |
| System-Top | Ibex + RAM + Peripherie hinter einem Adressdekoder |
| FPGA-Deployment | Vollständiges SoC-Demo auf Nexys A7-100T |

### Phase 4: Weitere Peripherie (geplant)

- GPIO-Controller
- UART
- Timer / PWM
- Interrupt-Controller

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
- Peripherie-Bus: einfache We/Be/WData/RData-Signatur (siehe `lib/ram`, `lib/peri_reg`); Address-Decoding macht der Parent, `we_i` ist beim Register bereits vorgefiltert. Anbindung an Ibex erfolgt später über einen Adapter auf das native Ibex-Memory-Interface
- I/O-Standard aller Nexys A7 Pins: **LVCMOS33**
