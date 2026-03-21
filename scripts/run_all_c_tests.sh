#!/bin/bash
# Run all C-based assembly equivalence tests.
#
# For each test in C_TESTS:
#   1. Build the C program and run its self-test via the c-tests Makefile
#   2. Generate the Kraken-instrumented .s file (mkc<test>test executable)
#   3. Compare Kraken's eval against real x86 execution (run_asm_test.sh)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KRAKEN_ROOT="$SCRIPT_DIR/.."

(cd "$KRAKEN_ROOT" && lake build krakentest)

# List of C tests to run
C_TESTS=(insertionsort)

# Step 1: Build all C tests and run their self-tests
echo "=== Building c-tests ==="
make -C "$KRAKEN_ROOT/c-tests"

echo "=== Running c-tests self-tests ==="
make -C "$KRAKEN_ROOT/c-tests" test

# Step 2 & 3: For each test, generate instrumented assembly and run krakentest
for TEST in "${C_TESTS[@]}"; do
    echo ""
    echo "=== Kraken equivalence test: $TEST ==="

    MKEXE="$KRAKEN_ROOT/.lake/build/bin/mkc${TEST}test"
    INSTRUMENTED="$KRAKEN_ROOT/c-tests/${TEST}_tests_instrumented.s"

    echo "--- Generating instrumented assembly ---"
    (cd "$KRAKEN_ROOT" && lake build mkc${TEST}test && "$MKEXE")

    echo "--- Running krakentest ---"
    "$SCRIPT_DIR/run_asm_test.sh" "$INSTRUMENTED"
done
