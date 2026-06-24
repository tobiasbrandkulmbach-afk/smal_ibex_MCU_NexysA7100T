# ===========================================================================
# firmware.cmake - wiederverwendbare Bausteine zum Bauen von Ibex-Firmware.
#
# Wird von der CMakeLists.txt eines Deployments inkludiert. Diese Datei ist
# bewusst projekt-unabhaengig: alles Spezifische (Memory-Map, Peripherie-
# Adressen, Programm) liegt im jeweiligen Deployment.
#
# Vor dem include muessen gesetzt sein:
#   SW_COMMON_DIR   - Pfad zu diesem sw/-Ordner (enthaelt crt0.S, bin2mem.py)
#   LINKER_SCRIPT   - Linker-Script des Deployments (Memory-Map)
#   IMEM_WORDS      - IMEM-Tiefe in 32-Bit-Woertern (muss zur RTL passen)
#   DMEM_WORDS      - DMEM-Tiefe in 32-Bit-Woertern
#   MEM_OUTPUT_DIR  - Zielordner fuer imem.mem / dmem.mem (Deployment-Ordner)
#
# RISCV_ARCH / RISCV_ABI / CMAKE_OBJCOPY / ... kommen aus der Toolchain-Datei.
# ===========================================================================
find_package(Python3 COMPONENTS Interpreter REQUIRED)

add_compile_options(-Os -g -Wall -Wextra -ffunction-sections -fdata-sections)

# ---------------------------------------------------------------------------
# add_firmware(<name> <quellen...>)
#   Baut <name>.elf (crt0 + Linker-Script) und erzeugt daraus die
#   $readmemh-Abbilder imem.mem / dmem.mem in MEM_OUTPUT_DIR.
#   soc.h o.ae. werden aus dem aufrufenden Deployment-Ordner gefunden.
# ---------------------------------------------------------------------------
function(add_firmware name)
    add_executable(${name} ${ARGN} ${SW_COMMON_DIR}/crt0.S)
    set_target_properties(${name} PROPERTIES
        SUFFIX ".elf"
        LINK_DEPENDS ${LINKER_SCRIPT})
    target_include_directories(${name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_options(${name} PRIVATE
        -nostartfiles -nostdlib
        -T ${LINKER_SCRIPT}
        -Wl,--gc-sections
        -Wl,--no-warn-rwx-segments   # .data-Ladeabbild liegt im IMEM neben dem Code
        -Wl,-Map=${name}.map
        -march=${RISCV_ARCH} -mabi=${RISCV_ABI} -mno-relax)

    # imem.mem / dmem.mem als echte CMake-Outputs fuehren: dadurch werden sie
    # automatisch neu erzeugt, sobald sie fehlen ODER die ELF neuer ist - auch
    # bei einem ganz normalen "cmake --build" (kein --clean-first noetig).
    add_custom_command(
        OUTPUT  ${MEM_OUTPUT_DIR}/imem.mem ${MEM_OUTPUT_DIR}/dmem.mem
        DEPENDS ${name}
        COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${name}> ${name}.bin
        COMMAND ${Python3_EXECUTABLE} ${SW_COMMON_DIR}/bin2mem.py
                ${name}.bin -o ${MEM_OUTPUT_DIR}/imem.mem --words ${IMEM_WORDS}
        COMMAND ${Python3_EXECUTABLE} ${SW_COMMON_DIR}/bin2mem.py
                --zero      -o ${MEM_OUTPUT_DIR}/dmem.mem --words ${DMEM_WORDS}
        COMMAND ${CMAKE_OBJDUMP} -d -S $<TARGET_FILE:${name}> > ${name}.lst
        COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${name}>
        BYPRODUCTS ${name}.bin ${name}.lst
        COMMENT "Erzeuge ${MEM_OUTPUT_DIR}/imem.mem + dmem.mem fuer ${name}")

    # ALL-Target, das die .mem-Outputs einfordert -> bei jedem Build geprueft.
    add_custom_target(${name}_mem ALL
        DEPENDS ${MEM_OUTPUT_DIR}/imem.mem ${MEM_OUTPUT_DIR}/dmem.mem)
endfunction()
