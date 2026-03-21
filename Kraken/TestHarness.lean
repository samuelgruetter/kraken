/-
Kraken TestHarness - Compare Kraken semantics with real x86 execution

This module provides a test harness that:
1. Takes raw assembly code (AT&T syntax) as input
2. Parses it through Kraken and runs the semantics
3. Appends a capture epilogue to read final state
4. Compares the final machine states (registers, flags, and memory)

The input assembly should set up its own initial state - the harness only
adds the epilogue to capture and output final state.

Compatible with Lean 4.22.0+.
-/

import Kraken.Semantics
import Kraken.Parser

namespace Kraken.TestHarness

-- ============================================================================
-- Memory Region Definition
-- ============================================================================

/-- A memory region to track during test execution.
    base must be 8-byte aligned; size is number of 8-byte words. -/
structure MemRegion where
  base : UInt64   -- Starting address (must be 8-byte aligned)
  size : Nat      -- Number of 8-byte words to track
  deriving Repr, BEq

-- ============================================================================
-- Capture Epilogue Generation
-- ============================================================================

/-- Generate .data section for storing final register state. -/
def genCaptureDataRegs : String :=
  ".data\n" ++
  ".align 8\n" ++
  "# Final register state (filled by capture epilogue)\n" ++
  "_kraken_final_rax: .quad 0\n" ++
  "_kraken_final_rbx: .quad 0\n" ++
  "_kraken_final_rcx: .quad 0\n" ++
  "_kraken_final_rdx: .quad 0\n" ++
  "_kraken_final_rsi: .quad 0\n" ++
  "_kraken_final_rdi: .quad 0\n" ++
  "_kraken_final_rsp: .quad 0\n" ++
  "_kraken_final_rbp: .quad 0\n" ++
  "_kraken_final_r8: .quad 0\n" ++
  "_kraken_final_r9: .quad 0\n" ++
  "_kraken_final_r10: .quad 0\n" ++
  "_kraken_final_r11: .quad 0\n" ++
  "_kraken_final_r12: .quad 0\n" ++
  "_kraken_final_r13: .quad 0\n" ++
  "_kraken_final_r14: .quad 0\n" ++
  "_kraken_final_r15: .quad 0\n" ++
  "_kraken_final_flags: .quad 0\n"

/-- Generate .data section for memory region tracking. -/
def genCaptureDataMem (regions : List MemRegion) : String :=
  if regions.isEmpty then ""
  else
    let regionData := regions.zipIdx.map fun (r, i) =>
      s!"# Memory region {i}: base={r.base}, size={r.size} words\n" ++
      s!"_kraken_mem_region_{i}_base: .quad {r.base.toNat}\n" ++
      s!"_kraken_mem_region_{i}_size: .quad {r.size}\n" ++
      s!"_kraken_mem_region_{i}_data: .space {r.size * 8}\n"
    "\n# Memory regions to track\n" ++
    s!"_kraken_mem_region_count: .quad {regions.length}\n" ++
    String.intercalate "\n" regionData

/-- Generate full .data section for capture (registers + optional memory). -/
def genCaptureData (memRegions : List MemRegion := []) : String :=
  genCaptureDataRegs ++ genCaptureDataMem memRegions

/-- Generate assembly to save registers to .data section. -/
def genSaveRegisters : String :=
  "    # Save all registers to .data section\n" ++
  "    movq %rax, _kraken_final_rax(%rip)\n" ++
  "    movq %rbx, _kraken_final_rbx(%rip)\n" ++
  "    movq %rcx, _kraken_final_rcx(%rip)\n" ++
  "    movq %rdx, _kraken_final_rdx(%rip)\n" ++
  "    movq %rsi, _kraken_final_rsi(%rip)\n" ++
  "    movq %rdi, _kraken_final_rdi(%rip)\n" ++
  "    movq %rsp, _kraken_final_rsp(%rip)\n" ++
  "    movq %rbp, _kraken_final_rbp(%rip)\n" ++
  "    movq %r8,  _kraken_final_r8(%rip)\n" ++
  "    movq %r9,  _kraken_final_r9(%rip)\n" ++
  "    movq %r10, _kraken_final_r10(%rip)\n" ++
  "    movq %r11, _kraken_final_r11(%rip)\n" ++
  "    movq %r12, _kraken_final_r12(%rip)\n" ++
  "    movq %r13, _kraken_final_r13(%rip)\n" ++
  "    movq %r14, _kraken_final_r14(%rip)\n" ++
  "    movq %r15, _kraken_final_r15(%rip)\n" ++
  "    # Save flags\n" ++
  "    pushfq\n" ++
  "    popq %rax\n" ++
  "    movq %rax, _kraken_final_flags(%rip)\n"

/-- Generate assembly to copy memory regions to dump buffers. -/
def genCopyMemoryRegions (regions : List MemRegion) : String :=
  if regions.isEmpty then ""
  else
    let copies := regions.zipIdx.map fun (r, i) =>
      s!"    # Copy memory region {i}\n" ++
      s!"    movq _kraken_mem_region_{i}_base(%rip), %rsi  # source = base\n" ++
      s!"    leaq _kraken_mem_region_{i}_data(%rip), %rdi  # dest = buffer\n" ++
      s!"    movq ${r.size}, %rcx                  # count = size words\n" ++
      s!"    rep movsq                             # copy\n"
    "\n    # Copy memory regions to dump buffers\n" ++
    String.intercalate "\n" copies

/-- Calculate total output size: registers (136) + memory regions. -/
def calcOutputSize (regions : List MemRegion) : Nat :=
  136 + -- 16 regs + 1 flags = 17 * 8 = 136 bytes
  (if regions.isEmpty then 0
   else 8 + -- mem_region_count
        regions.foldl (fun acc r => acc + 8 + 8 + r.size * 8) 0) -- base + size + data per region

/-- Generate assembly to write output to stdout and exit. -/
def genWriteAndExit (regions : List MemRegion) : String :=
  let memHeaderSize := if regions.isEmpty then 0 else 8 -- _kraken_mem_region_count
  let memDataSize := regions.foldl (fun acc r => acc + 16 + r.size * 8) 0 -- base + size + data per region

  -- Write registers first
  "    # Write register state to stdout (136 bytes)\n" ++
  "    movq $1, %rax         # sys_write\n" ++
  "    movq $1, %rdi         # stdout\n" ++
  "    leaq _kraken_final_rax(%rip), %rsi  # buffer start\n" ++
  "    movq $136, %rdx       # 17 quads = 136 bytes\n" ++
  "    syscall\n" ++
  (if regions.isEmpty then ""
   else
    "\n    # Write memory region data to stdout\n" ++
    "    movq $1, %rax\n" ++
    "    movq $1, %rdi\n" ++
    "    leaq _kraken_mem_region_count(%rip), %rsi\n" ++
    s!"    movq ${memHeaderSize + memDataSize}, %rdx\n" ++
    "    syscall\n") ++
  "\n    # Exit with code 0\n" ++
  "    movq $60, %rax\n" ++
  "    xorq %rdi, %rdi\n" ++
  "    syscall\n"

/-- Generate the full capture epilogue with optional memory tracking. -/
def genCaptureEpilogue (memRegions : List MemRegion := []) : String :=
  "\n" ++
  "# ====== KRAKEN CAPTURE EPILOGUE ======\n" ++
  "_kraken_capture:\n" ++
  genSaveRegisters ++
  genCopyMemoryRegions memRegions ++
  "\n" ++
  genWriteAndExit memRegions

-- ============================================================================
-- Assembly Modification
-- ============================================================================

/-- Wrap user's assembly code with capture infrastructure.

    The user's code should be a complete program (with .text, .globl _start, etc.)
    that ends by jumping/falling through to _kraken_capture.

    Optional: specify memory regions to track. -/
def wrapAssembly (userAsm : String) (memRegions : List MemRegion := []) : String :=
  genCaptureData memRegions ++ "\n" ++ userAsm ++ genCaptureEpilogue memRegions

/-- Generate a minimal test program from just the instructions to test.
    Creates a complete program with _start that runs the instructions
    and then captures state.

    Example: makeTestProgram "addq $1, %rax" -/
def makeTestProgram (instructions : String) (memRegions : List MemRegion := []) : String :=
  genCaptureData memRegions ++ "\n" ++
  ".text\n" ++
  ".globl _start\n" ++
  "_start:\n" ++
  instructions ++ "\n" ++
  genCaptureEpilogue memRegions

-- ============================================================================
-- Result Parsing
-- ============================================================================

/-- Extract a 64-bit value from binary data at given offset (little-endian). -/
def extractUInt64 (data : ByteArray) (offset : Nat) : UInt64 :=
  if offset + 7 >= data.size then 0
  else
    let b0 := data.get! offset
    let b1 := data.get! (offset + 1)
    let b2 := data.get! (offset + 2)
    let b3 := data.get! (offset + 3)
    let b4 := data.get! (offset + 4)
    let b5 := data.get! (offset + 5)
    let b6 := data.get! (offset + 6)
    let b7 := data.get! (offset + 7)
    b0.toUInt64 + (b1.toUInt64 <<< 8) + (b2.toUInt64 <<< 16) + (b3.toUInt64 <<< 24) +
    (b4.toUInt64 <<< 32) + (b5.toUInt64 <<< 40) + (b6.toUInt64 <<< 48) + (b7.toUInt64 <<< 56)

/-- Parse final register/flag state from binary output (first 136 bytes). -/
def parseRegisterState (data : ByteArray) : Option (Registers × Flags) :=
  if data.size < 136 then none
  else
    let regs : Registers := {
      rax := extractUInt64 data 0,
      rbx := extractUInt64 data 8,
      rcx := extractUInt64 data 16,
      rdx := extractUInt64 data 24,
      rsi := extractUInt64 data 32,
      rdi := extractUInt64 data 40,
      rsp := extractUInt64 data 48,
      rbp := extractUInt64 data 56,
      r8  := extractUInt64 data 64,
      r9  := extractUInt64 data 72,
      r10 := extractUInt64 data 80,
      r11 := extractUInt64 data 88,
      r12 := extractUInt64 data 96,
      r13 := extractUInt64 data 104,
      r14 := extractUInt64 data 112,
      r15 := extractUInt64 data 120
    }
    let flagsVal := extractUInt64 data 128
    let flags : Flags := {
      zf := (flagsVal &&& 0x40) != 0,  -- Bit 6: ZF
      cf := (flagsVal &&& 0x01) != 0,  -- Bit 0: CF
      of := (flagsVal &&& 0x800) != 0  -- Bit 11: OF
    }
    some (regs, flags)

/-- Parse memory region data from binary output (after register state).
    Returns list of (base, values) pairs. -/
def parseMemoryRegions (data : ByteArray) : List (UInt64 × Array UInt64) :=
  if data.size <= 136 then []
  else
    let regionCount := extractUInt64 data 136
    parseRegionsAux data 144 regionCount.toNat []
where
  parseRegionsAux (data : ByteArray) (offset : Nat) (remaining : Nat)
      (acc : List (UInt64 × Array UInt64)) : List (UInt64 × Array UInt64) :=
    match remaining with
    | 0 => acc
    | n + 1 =>
      if offset + 16 > data.size then acc
      else
        let base := extractUInt64 data offset
        let size := extractUInt64 data (offset + 8)
        let valuesOffset := offset + 16
        let values := Array.range size.toNat |>.map fun i =>
          if valuesOffset + i * 8 + 8 > data.size then 0
          else extractUInt64 data (valuesOffset + i * 8)
        let newOffset := valuesOffset + size.toNat * 8
        parseRegionsAux data newOffset n (acc ++ [(base, values)])

-- ============================================================================
-- State Comparison
-- ============================================================================

/-- Compare two register states, returning list of differences.
    Skips rsp since Kraken initializes it to 0 but real execution has a stack. -/
def compareRegisters (expected actual : Registers) : List String :=
  let checks := [
    ("rax", expected.rax, actual.rax), ("rbx", expected.rbx, actual.rbx),
    ("rcx", expected.rcx, actual.rcx), ("rdx", expected.rdx, actual.rdx),
    ("rsi", expected.rsi, actual.rsi), ("rdi", expected.rdi, actual.rdi),
    -- Skip rsp: Kraken initializes to 0, real execution has stack pointer
    -- ("rsp", expected.rsp, actual.rsp),
    ("rbp", expected.rbp, actual.rbp),
    ("r8",  expected.r8,  actual.r8),  ("r9",  expected.r9,  actual.r9),
    ("r10", expected.r10, actual.r10), ("r11", expected.r11, actual.r11),
    ("r12", expected.r12, actual.r12), ("r13", expected.r13, actual.r13),
    ("r14", expected.r14, actual.r14), ("r15", expected.r15, actual.r15)
  ]
  checks.filterMap fun (name, exp, act) =>
    if exp != act then some s!"{name}: expected {exp}, got {act}"
    else none

/-- Compare two flag states, returning list of differences. -/
def compareFlags (expected actual : Flags) : List String :=
  let checks := [
    ("ZF", expected.zf, actual.zf),
    ("CF", expected.cf, actual.cf),
    ("OF", expected.of, actual.of)
  ]
  checks.filterMap fun (name, exp, act) =>
    if exp != act then some s!"{name}: expected {exp}, got {act}"
    else none

/-- Extract memory values from Kraken's unified memory for comparison.
    Only reads MemCell.data entries; uninitialized or code cells yield 0. -/
def extractKrakenMemory (mem : Memory) (regions : List MemRegion)
    : List (UInt64 × Array UInt64) :=
  regions.map fun r =>
    let values := Array.range r.size |>.map fun i =>
      (readDataCell mem (r.base + i.toUInt64 * 8)).getD 0
    (r.base, values)

/-- Compare memory regions, returning list of differences. -/
def compareMemory (expected actual : List (UInt64 × Array UInt64)) : List String :=
  let pairs := expected.zip actual
  pairs.foldl (fun acc ((expBase, expVals), (actBase, actVals)) =>
    if expBase != actBase then
      acc ++ [s!"memory base mismatch: expected {expBase}, got {actBase}"]
    else
      let valDiffs := expVals.toList.zip actVals.toList |>.zipIdx.filterMap fun ((e, a), i) =>
        if e != a then some s!"mem[{expBase}+{i*8}]: expected {e}, got {a}"
        else none
      acc ++ valDiffs
  ) []

-- ============================================================================
-- Kraken Execution
-- ============================================================================

/-- Build a MachineState from a ProgramWithDataSection.
    Instructions are placed at addresses 0, 1, 2, … (1-byte-per-instruction TODO).
    Data labels are placed at 8-byte-aligned addresses after the instruction region. -/
def buildMachineStateWithData (pwds : Kraken.Parser.ProgramWithDataSection) : MachineState :=
  let s := programToMachineState pwds.prog
  -- Data starts at the first 8-byte-aligned address after all instructions
  let dataBase := ((pwds.prog.length.toUInt64 + 7) / 8) * 8
  let (mem', lbls', _) := pwds.dataLabels.foldl (fun (m, a, off) (lbl, val) =>
    let addr := dataBase + off.toUInt64
    let m' := m.insert addr (.data val)
    let a' := if lbl.isEmpty then a else a.insert lbl addr
    (m', a', off + 8)
  ) (s.memory, s.labelAddrs, 0)
  { s with memory := mem', labelAddrs := lbls' }

/-- Run assembly through Kraken's semantics.
    Parses the full assembly file (extracting user instructions and data labels),
    builds a MachineState, and evaluates until the program terminates. -/
def runKraken (asmCode : String) (initState : MachineState := {})
    : Except String MachineState := do
  let pwds ← Kraken.Parser.parse asmCode
  let s := buildMachineStateWithData pwds
  -- Set rip to _start label (insertionsort may appear before _start in .text)
  let startRip := s.labelAddrs["_start"]?.getD 0
  let s := { s with rip := startRip }
  -- Overlay any caller-supplied initial register/flag state
  let s := { s with regs := initState.regs, flags := initState.flags }
  runBounded s 10000
where
  runBounded (s : MachineState) (fuel : Nat) : Except String MachineState :=
    match fuel with
    | 0 => .error "execution exceeded step limit"
    | fuel' + 1 =>
      -- Stop when the PC points past the instruction region (program has terminated)
      match (s.memory[s.rip]? : Option MemCell) with
      | some (MemCell.instr ..) =>
        match eval1 (m := { throw := Except.error }) s (fun s => .ok s) with
        | .ok s' => runBounded s' fuel'
        | .error e => .error e
      | _ => .ok s

-- ============================================================================
-- Test Result Type
-- ============================================================================

inductive TestResult
  | success : TestResult
  | mismatch : List String → TestResult  -- List of differences
  | krakenError : String → TestResult
  | execError : String → TestResult
  deriving Repr

/-- Compare Kraken's expected final state with actual execution result (registers only). -/
def compareStates (krakenState : MachineState) (actualRegs : Registers) (actualFlags : Flags)
    : TestResult :=
  let regDiffs := compareRegisters krakenState.regs actualRegs
  let flagDiffs := compareFlags krakenState.flags actualFlags
  let allDiffs := regDiffs ++ flagDiffs
  if allDiffs.isEmpty then .success
  else .mismatch allDiffs

/-- Compare Kraken's expected final state with actual execution (including memory). -/
def compareStatesWithMem (krakenState : MachineState)
    (actualRegs : Registers) (actualFlags : Flags)
    (actualMem : List (UInt64 × Array UInt64))
    (memRegions : List MemRegion)
    : TestResult :=
  let regDiffs := compareRegisters krakenState.regs actualRegs
  let flagDiffs := compareFlags krakenState.flags actualFlags
  let expectedMem := extractKrakenMemory krakenState.memory memRegions
  let memDiffs := compareMemory expectedMem actualMem
  let allDiffs := regDiffs ++ flagDiffs ++ memDiffs
  if allDiffs.isEmpty then .success
  else .mismatch allDiffs

-- ============================================================================
-- High-Level Test API
-- ============================================================================

/-- Run a complete test: parse AS output, run Kraken eval, compare results.

    Arguments:
    - asmCode: Full assembly code (will extract testable portion)
    - asOutput: Binary output from running AS (136+ bytes)

    Returns TestResult indicating pass/fail with details. -/
def runTest (asmCode : String) (asOutput : ByteArray) : TestResult :=
  -- Parse AS output
  match parseRegisterState asOutput with
  | none => .execError "Failed to parse AS output (need 136 bytes)"
  | some (actualRegs, actualFlags) =>
    -- Pass full assembly to runKraken; it handles extraction and data-label parsing internally
    match runKraken asmCode with
    | .error e => .krakenError e
    | .ok krakenState =>
      let memData := parseMemoryRegions asOutput
      if memData.isEmpty then
        -- No memory regions: compare registers and flags directly.
        compareStates krakenState actualRegs actualFlags
      else
        -- Memory regions present (C-code test): compare only memory content.
        -- Pointer-valued registers differ between Kraken's abstract address model and
        -- real x86 virtual addresses, so register comparison is not meaningful here.
        -- Instead, compare the sorted data values stored in Kraken's data region
        -- against the actual sorted values captured from the real execution.
        let allActualValues : Array UInt64 := (memData.map Prod.snd).foldl Array.append #[]
        let n := allActualValues.size
        -- Find the base address of the program's data region: the minimum address
        -- among non-harness labels that point to a data cell (not an instruction).
        -- The _kraken_* harness labels occupy the first part of the data section;
        -- the program's own data labels (e.g. test_array) follow.
        -- Note: labelAddrs has no generic fold; we use a for-in loop via Id.run.
        let programBase : UInt64 := Id.run do
          let mut best : UInt64 := (0 : UInt64) - 1
          for (name, addr) in krakenState.labelAddrs do
            if !name.startsWith "_kraken_" && addr < best then
              match krakenState.memory[addr]? with
              | some (MemCell.data _) => best := addr
              | _ => ()
          return best
        if programBase == (0 : UInt64) - 1 then
          .krakenError "Kraken memory has no program-data labels after execution"
        else
          let krakenValues := Array.ofFn (n := n) fun i =>
            (readDataCell krakenState.memory (programBase + (i.val * 8).toUInt64)).getD 0
          let diffs := (krakenValues.toList.zip allActualValues.toList).zipIdx.filterMap
            fun ((exp, act), i) =>
              if exp != act then some s!"mem[{i}]: expected {exp}, got {act}"
              else none
          if diffs.isEmpty then .success
          else .mismatch diffs

/-- Format a TestResult for display. -/
def TestResult.toString : TestResult → String
  | .success => "PASS"
  | .mismatch diffs => "FAIL:\n" ++ String.intercalate "\n  " ("" :: diffs)
  | .krakenError e => s!"KRAKEN ERROR: {e}"
  | .execError e => s!"EXEC ERROR: {e}"

end Kraken.TestHarness

-- ============================================================================
-- Example Usage
-- ============================================================================

/-
WORKFLOW FOR MEMORY TESTING:

1. Define memory regions to track:

   def myRegions : List MemRegion := [
     { base := 0x600000, size := 8 },  -- Track 8 words starting at 0x600000
     { base := 0x601000, size := 4 }   -- Track 4 words starting at 0x601000
   ]

2. Generate test program with memory tracking:

   let prog := Kraken.TestHarness.makeTestProgram
     "movq $42, 0x600000\nmovq $99, 0x600008" myRegions

3. Run and capture output:

   $ as -o test.o test.S && ld -o test test.o && ./test > output.bin

4. Parse output and compare:

   let (regs, flags) := parseRegisterState outputBytes
   let memData := parseMemoryRegions outputBytes
   let result := compareStatesWithMem krakenState regs flags memData myRegions
-/
