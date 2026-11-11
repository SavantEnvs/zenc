#!/usr/bin/env bash
#
# mayhem/build.sh — build the zc-fuzz libFuzzer harness (upstream's fuzz/harness.c) plus the
# project's unit-test runner. Runs in the commit image as `mayhem` in /mayhem, offline-safe: the
# build needs only the base image's clang + libc headers.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
MK=(make -f Makefile -f mayhem/mayhem.mk WERROR=0 ZC_HAS_JIT=0)

# 1) Test suite first, with the project's NORMAL flags (no sanitizer, no -gdwarf-3): upstream's
#    own objects land in obj/, which upstream's .gitignore covers.
"${MK[@]}" -j"$MAYHEM_JOBS" CC="$CC $COVERAGE_FLAGS" zc mayhem-unit

# 2) Fuzz build: every compiler source (minus src/main.c) + fuzz/harness.c, compiled with the
#    sanitizers, DWARF 3 and SanCov (fuzzer-no-link, also when SANITIZER_FLAGS is empty). The
#    compiler is invoked by name; objects go to obj/fuzz/ (gitignored via obj/).
FUZZ_CC="$CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
"${MK[@]}" -j"$MAYHEM_JOBS" CC="$FUZZ_CC" OBJ_DIR=obj/fuzz mayhem-objs
OBJS=$("${MK[@]}" -s CC="$FUZZ_CC" OBJ_DIR=obj/fuzz mayhem-print-objs)

# 3) Leak sanitizer off (SPEC §6.2 item 15), then the fuzzer and standalone reproducer.
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o obj/fuzz/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o obj/fuzz/standalone_main.o
LIBS="-lm -lpthread -ldl"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $OBJS obj/fuzz/fuzz/harness.o obj/fuzz/lsan_off.o \
    $LIBS -o /mayhem/zc-fuzz
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link $OBJS obj/fuzz/fuzz/harness.o obj/fuzz/lsan_off.o \
    obj/fuzz/standalone_main.o $LIBS -o /mayhem/zc-fuzz-standalone
