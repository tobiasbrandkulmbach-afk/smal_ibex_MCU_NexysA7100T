#!/usr/bin/env bash
# =====================================================================
#  Live-Demo fuer die Abschlusspraesentation
#
#  Laedt nacheinander alle Deployments per JTAG auf die Nexys A7-100T.
#  Nach jedem ENTER wird das naechste Deployment programmiert.
#
#  Aufruf (aus einem beliebigen Ordner):
#     ./presentations/abschlusspraesentation/demo_fpga.sh
#
#  Vivado-Umgebung wird bei Bedarf automatisch geladen; Pfad ggf. per
#  Umgebungsvariable ueberschreiben:
#     VIVADO_SETTINGS=/pfad/zu/settings64.sh ./demo_fpga.sh
# =====================================================================
set -u

# --- Verzeichnisse (relativ zum Skript, damit ortsunabhaengig) -------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_DIR="$REPO_ROOT/deployments"

# --- Reihenfolge der Deployments (einfach -> komplex) ----------------
DEPLOYMENTS=(
  demo_counter_seg7
  demo_counter_ram_seg7
  demo_ibex_seg7
  demo_ibex_uart_seg7
  demo_ibex_uart_text
)

# --- Vivado bereitstellen --------------------------------------------
VIVADO_SETTINGS="${VIVADO_SETTINGS:-$HOME/AMD/2025.2/Vivado/settings64.sh}"
if ! command -v vivado >/dev/null 2>&1; then
  if [[ -f "$VIVADO_SETTINGS" ]]; then
    echo "Lade Vivado-Umgebung: $VIVADO_SETTINGS"
    # shellcheck disable=SC1090
    source "$VIVADO_SETTINGS"
  fi
fi
if ! command -v vivado >/dev/null 2>&1; then
  echo "FEHLER: 'vivado' nicht im PATH gefunden." >&2
  echo "        settings64.sh sourcen oder VIVADO_SETTINGS setzen." >&2
  exit 1
fi

# --- Logs sammeln, damit die Konsole waehrend der Demo ruhig bleibt --
LOG_DIR="$(mktemp -d -t fpga_demo.XXXXXX)"
echo "Vivado-Logs: $LOG_DIR"

total=${#DEPLOYMENTS[@]}
i=0
for name in "${DEPLOYMENTS[@]}"; do
  i=$((i + 1))
  tcl="$DEPLOY_DIR/$name/scripts/program.tcl"
  bit="$DEPLOY_DIR/$name/out/$name.bit"

  echo
  echo "=================================================================="
  echo "  [$i/$total]  $name"
  echo "=================================================================="

  if [[ ! -f "$tcl" ]]; then
    echo "  ! program.tcl fehlt ($tcl) -- uebersprungen."
    continue
  fi
  if [[ ! -f "$bit" ]]; then
    echo "  ! Bitstream fehlt ($bit) -- uebersprungen."
    continue
  fi

  # Auf ENTER warten (Ctrl-C bricht die ganze Demo ab).
  read -rp "  >> ENTER = aufs FPGA laden ... " _ || { echo; echo "Abgebrochen."; exit 0; }

  echo "  Programmiere $name ..."
  log="$LOG_DIR/$name.log"
  if vivado -mode batch -nolog -nojournal -notrace -source "$tcl" >"$log" 2>&1; then
    echo "  OK -> $name laeuft jetzt auf dem FPGA."
  else
    echo "  FEHLER beim Programmieren von $name (siehe $log):"
    tail -n 15 "$log" | sed 's/^/      /'
  fi
done

echo
echo "Alle Deployments durch. Demo beendet."
