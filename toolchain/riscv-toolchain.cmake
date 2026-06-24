# ===========================================================================
# CMake-Toolchain-Datei fuer den RISC-V-Cross-Build (RV32IMC, ilp32).
#
# Verwendung:
#   cmake -B build -S . \
#         -DCMAKE_TOOLCHAIN_FILE=cmake/riscv-toolchain.cmake
#
# Der Compiler-Praefix wird automatisch gesucht; ueberschreibbar mit
#   -DRISCV_PREFIX=riscv64-elf-
# ===========================================================================

set(CMAKE_SYSTEM_NAME      Generic)      # bare-metal, kein OS
set(CMAKE_SYSTEM_PROCESSOR riscv32)

# --- Compiler-Praefix finden ----------------------------------------------
if(NOT RISCV_PREFIX)
    set(_riscv_candidates
        riscv64-elf-              # Arch Linux: riscv64-elf-gcc + riscv64-elf-newlib
        riscv32-elf-
        riscv64-unknown-elf-      # riscv-gnu-toolchain (Standard)
        riscv32-unknown-elf-
        riscv-none-elf-)          # xPack
    foreach(_p ${_riscv_candidates})
        find_program(_riscv_gcc ${_p}gcc)
        if(_riscv_gcc)
            set(RISCV_PREFIX ${_p})
            break()
        endif()
        unset(_riscv_gcc CACHE)
    endforeach()
endif()

if(NOT RISCV_PREFIX)
    message(FATAL_ERROR
        "Kein RISC-V-GCC gefunden. Bitte installieren, z.B. unter Arch:\n"
        "  sudo pacman -S riscv64-elf-gcc riscv64-elf-newlib riscv64-elf-binutils\n"
        "oder Praefix angeben: -DRISCV_PREFIX=...")
endif()

set(CMAKE_C_COMPILER   ${RISCV_PREFIX}gcc)
set(CMAKE_ASM_COMPILER ${RISCV_PREFIX}gcc)
set(CMAKE_OBJCOPY      ${RISCV_PREFIX}objcopy CACHE FILEPATH "objcopy")
set(CMAKE_OBJDUMP      ${RISCV_PREFIX}objdump CACHE FILEPATH "objdump")
set(CMAKE_SIZE         ${RISCV_PREFIX}size    CACHE FILEPATH "size")

# Bare-metal: kein voller Link-Test beim Konfigurieren.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# --- ISA / ABI ------------------------------------------------------------
set(RISCV_ARCH "rv32imc" CACHE STRING "RISC-V ISA-String (Ibex: RV32IMC)")
set(RISCV_ABI  "ilp32"   CACHE STRING "RISC-V ABI")

# -mno-relax: GP-relative Linker-Relaxation aus -> kein global_pointer-Setup
# im crt0 noetig, robust fuer minimale bare-metal-Programme.
set(_arch_flags "-march=${RISCV_ARCH} -mabi=${RISCV_ABI} -mno-relax")
set(CMAKE_C_FLAGS_INIT   "${_arch_flags} -ffreestanding")
set(CMAKE_ASM_FLAGS_INIT "${_arch_flags}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
