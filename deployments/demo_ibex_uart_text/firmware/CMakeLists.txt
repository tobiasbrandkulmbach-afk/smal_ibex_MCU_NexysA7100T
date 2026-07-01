# ===========================================================================
# Firmware fuer das Deployment demo_ibex_uart_text.
#
# Bauen (aus diesem Ordner):
#   cmake -B build -S . \
#         -DCMAKE_TOOLCHAIN_FILE=../../../toolchain/riscv-toolchain.cmake
#   cmake --build build
#
# Ergebnis: ../imem.mem und ../dmem.mem (werden vom Vivado-build.tcl
# dieses Deployments per $readmemh eingelesen).
# ===========================================================================
cmake_minimum_required(VERSION 3.20)
project(demo_ibex_uart_text_fw C ASM)

get_filename_component(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../.. ABSOLUTE)

# Allgemeine, wiederverwendbare SW-Bausteine (crt0.S, bin2mem.py, add_firmware)
set(SW_COMMON_DIR ${PROJECT_ROOT}/sw)

# --- Deployment-spezifische Konfiguration ---------------------------------
set(LINKER_SCRIPT  ${CMAKE_CURRENT_SOURCE_DIR}/ibex_soc.ld)
set(MEM_OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/..)   # -> Deployment-Ordner
set(IMEM_WORDS 256)    # muss zu ram #(.AddrWidth(8))  im Top passen
set(DMEM_WORDS 4096)   # muss zu ram #(.AddrWidth(12)) im Top passen

include(${SW_COMMON_DIR}/firmware.cmake)

# --- Programm(e) dieses Deployments ---------------------------------------
add_firmware(firmware main.c)
