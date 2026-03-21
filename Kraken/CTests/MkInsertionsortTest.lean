/-
MkInsertionsortTest - Generate a Kraken-instrumented assembly file for insertionsort.

Implements steps 1 and 2 of the WORKFLOW FOR MEMORY TESTING in Kraken/TestHarness.lean:
  1. Define memory regions to track (test_array: 5 int64_t values)
  2. Generate test program with memory tracking via Kraken.TestHarness.wrapAssembly

Output: ctests/insertionsort_tests_instrumented.s

The instrumented .s contains:
  - Kraken capture preamble (.data section for registers + memory region metadata)
  - The insertionsort function (from c-tests/insertionsort.s)
  - A test entry point (_start) that calls insertionsort then jumps to _kraken_capture
  - The Kraken capture epilogue (_kraken_capture label + register/memory dump + exit)
-/

import Kraken.TestHarness

open Kraken.TestHarness

-- Step 1: Define the memory region to track.
-- test_array has 5 int64_t values = 5 eight-byte words.
-- base = 0 is a placeholder; the actual address is resolved by the assembler
-- via the symbol reference ".quad test_array" we write below.
def testArrayRegion : MemRegion := { base := 0, size := 5 }

-- Generate the .data metadata for the memory region, using a symbol reference
-- for the base address so the linker fills it in correctly at link time.
def genMemRegionDataWithSymbol (symbol : String) (size : Nat) : String :=
  "\n# Memory regions to track\n" ++
  "_kraken_mem_region_count: .quad 1\n" ++
  s!"# Memory region 0: {symbol} ({size} int64_t values)\n" ++
  s!"_kraken_mem_region_0_base: .quad {symbol}\n" ++
  s!"_kraken_mem_region_0_size: .quad {size}\n" ++
  s!"_kraken_mem_region_0_data: .space {size * 8}\n"

-- Test stub: defines test_array and _start.
-- _start calls insertionsort then jumps to _kraken_capture (no write/exit syscall —
-- the capture epilogue handles output and termination).
-- Uses RIP-relative addressing for test_array to be position-independent.
def testStub : String :=
  "\n.data\n" ++
  ".globl test_array\n" ++
  ".align 8\n" ++
  ".type test_array, @object\n" ++
  ".size test_array, 40\n" ++
  "test_array:\n" ++
  "    .quad 1000000000000\n" ++
  "    .quad -5\n" ++
  "    .quad 42\n" ++
  "    .quad 42\n" ++
  "    .quad -1000000000000\n" ++
  "\n.text\n" ++
  ".globl _start\n" ++
  ".type _start, @function\n" ++
  "_start:\n" ++
  "    leaq test_array(%rip), %rdi\n" ++
  "    movq $5, %rsi\n" ++
  "    call insertionsort\n" ++
  "    jmp _kraken_capture\n"

def main : IO Unit := do
  -- Read the compiler-generated insertionsort function
  let insertionSortAsm ← IO.FS.readFile "c-tests/insertionsort.s"

  -- Step 2: Generate the instrumented assembly using the TestHarness infrastructure.
  -- We construct it manually to use a symbol reference for the memory region base
  -- (genCaptureDataMem only supports literal addresses).
  let memRegions := [testArrayRegion]
  let instrumented :=
    -- Preamble: register capture .data section
    genCaptureDataRegs ++
    -- Memory region metadata with symbol-based base address
    genMemRegionDataWithSymbol "test_array" 5 ++
    -- Compiler-generated insertionsort function
    insertionSortAsm ++
    -- Test entry point: test_array data + _start calling insertionsort
    testStub ++
    -- Capture epilogue: _kraken_capture label, save registers, copy memory, write, exit
    genCaptureEpilogue memRegions

  IO.FS.writeFile "ctests/insertionsort_tests_instrumented.s" instrumented
  IO.println "Generated ctests/insertionsort_tests_instrumented.s"
