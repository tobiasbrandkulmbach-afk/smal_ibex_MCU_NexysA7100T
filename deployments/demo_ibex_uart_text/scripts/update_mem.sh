#!/usr/bin/env bash
# ===========================================================================
# Programm (imem.mem) per updatemem in den fertigen Bitstream patchen -
# OHNE Vivado-Synthese/P&R. Dauert Sekunden statt Minuten.
#
# Voraussetzung: build.tcl lief einmal und hat erzeugt:
#   out/demo_ibex_uart_text.bit   (Bitstream)
#   out/demo_ibex_uart_text.mmi   (Memory-Map, via write_mem_info)
#
# Ablauf zum Programm-Wechsel:
#   1) C neu bauen  -> deployments/.../firmware: cmake --build build
#      (schreibt deployments/demo_ibex_uart_text/imem.mem)
#   2) dieses Skript:           scripts/update_mem.sh
#   3) auf das Board (JTAG):    vivado -mode batch -source scripts/program.tcl
#
# updatemem muss im PATH sein (Vivado settings64.sh sourcen).
# ===========================================================================
set -euo pipefail

top=demo_ibex_uart_text
proc_inst=u_imem/xpm_memory_base_inst   # aus der .mmi (InstPath des XPM-IMEM)

script_dir=$(cd "$(dirname "$0")" && pwd)
deploy_dir=$(dirname "$script_dir")
out_dir=$deploy_dir/out

command -v updatemem >/dev/null 2>&1 || {
    echo "FEHLER: 'updatemem' nicht im PATH. Vivado-Umgebung laden, z.B.:"
    echo "  source ~/AMD/2025.2/Vivado/settings64.sh"
    exit 1
}
for f in "$out_dir/$top.bit" "$out_dir/$top.mmi" "$deploy_dir/imem.mem"; do
    [ -f "$f" ] || { echo "FEHLER: fehlt: $f (build.tcl bzw. Firmware bauen)"; exit 1; }
done

# imem.mem ($readmemh, ein Wort/Zeile) -> updatemem-Format (@0 + Worte).
# updatemem verlangt die Endungen .mem (Daten) bzw. .bit (Ausgabe).
data=$(mktemp --suffix=.mem)
out=$(mktemp -u --suffix=.bit)
{ echo "@0"; cat "$deploy_dir/imem.mem"; } > "$data"

updatemem -force \
    -meminfo "$out_dir/$top.mmi" \
    -data    "$data" \
    -bit     "$out_dir/$top.bit" \
    -proc    "$proc_inst" \
    -out     "$out"

mv -f "$out" "$out_dir/$top.bit"
rm -f "$data"

echo "OK: $out_dir/$top.bit gepatcht (neues Programm)."
echo "    -> programmieren: vivado -mode batch -source $script_dir/program.tcl"
