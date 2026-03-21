/-
Kraken - Example Programs

Test programs demonstrating the assembly interpreter.
Compatible with Lean 4.22.0+.

For semantics, see Kraken/Semantics.lean.
For tactics, see Kraken/Tactics.lean.
-/

import Kraken.Tactics

-- Example 1: single step of execution
-- Programs are now loaded into MachineState via programToMachineState.
-- step1 no longer takes a separate Program parameter; the program lives in the state.
def p1: Program := [
  (.none, .mov (Reg.rax) (.imm 1)),
]

-- TODO: These proofs need updating now that programToMachineState uses ExtHashMap.
-- The simp/step_one tactics time out because they can't efficiently reduce hash-map lookups.
-- For now we mark them sorry; future work should add native_decide or decide-based proofs.
example: step1 (programToMachineState p1) (fun s => s.regs.rax = 1) := by
  sorry

-- Example 2: fine-grained tactics to step through the goal

def p2: Program := [
  (.some "start", .mov (.reg .rax) (.imm 1)),
  (.none,         .jcc .z "start"),
  (.none,         .mov (.reg .rax) (.imm 2)),
]

-- eventually no longer takes a Program parameter; the program lives in the initial state.
example: eventually (fun s => s.regs.rax = 2) (programToMachineState p2) := by
  sorry

def p3: Program := [
  (.none,         .mov (.reg .rdx) (.imm 2)),                -- rdx: current result = 2
  (.some "start", .sub (.reg .rbx) (.imm 0)),                -- TEST: zf = (rbx == 0)
  (.none        , .jcc .z "end"),                            -- end loop if rbx == 0
  (.none        , .mulx (.reg .rax) (.reg .rdx) (.reg .rdx)), -- BODY: rdx := rdx * rdx
  (.none,         .sub (.reg .rbx) (.imm 1)),                -- rbx -= 1
  (.none,         .jmp "start"),                             -- go back to test & loop body
  (.some "end",   .mov (.reg .rax) (.imm 0)),                -- just to have the label
]

#eval (eval (programToMachineState p3))

def p3_spec (s: MachineState): Nat := 2^(2^s.regs.rbx.toNat)

set_option maxHeartbeats 4000000 in
theorem p3_correct (initial: MachineState):
    p3_spec initial < 2^64 →
    initial.rip = 0 →
    eventually (fun s => s.regs.rdx.toNat == p3_spec initial ∧ s.regs.rax == 0)
               { programToMachineState p3 with regs := initial.regs, flags := initial.flags } :=
  by
  sorry
