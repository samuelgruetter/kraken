/-
Kraken - Proof Tactics

Core tactics and theorems for stepping through assembly proofs.
Compatible with Lean 4.22.0+.

For semantics, see Kraken/Semantics.lean.
For advanced tactics (SymM), see kraken-experimental/KrakenExp/Tactics.lean.
-/

import Kraken.Theorems

-- PROOF INFRASTRUCTURE

def Post := MachineState → Prop

-- step1: evaluate one step from state s, yielding post-condition.
-- The program is now contained in s.memory, so no separate Program parameter is needed.
def step1 (s: MachineState) (post: Post) :=
  eval1 (m:={ throw _ := False }) s post

inductive eventually (p: MachineState → Prop): MachineState -> Prop
  | done (initial: MachineState):
      p initial →
      eventually p initial
  | step (initial: MachineState):
      (mid_p: Post) ->
      step1 initial mid_p →
      (forall (mid: MachineState), mid_p mid → eventually p mid) →
      eventually p initial

-- THEOREMS

theorem step_cps (post: Post) (initial: MachineState):
  step1 initial (fun mid => eventually post mid) → eventually post initial :=
  by
    intro
    apply eventually.step
    <;> try assumption
    grind

theorem eventually_trans (p q: Post) (initial: MachineState)
  (e: eventually p initial)
  (h: forall s, p s → eventually q s):
    eventually q initial
  := by
    induction e with
    | done =>
        grind
    | step initial mid_p step pred ind_h =>
        apply eventually.step
        <;> assumption -- Q: why does `grind` not work here?

theorem eventually_weaken (p q: Post)
  (h: forall s, p s → q s):
    eventually p initial → eventually q initial
  := by
    intro hp
    induction ih: hp -- Q: why does this not work with `induction ... with`?
    . apply eventually.done
      grind
    . apply eventually.step
      <;> try assumption
      grind

-- A loop down to 0
theorem reg_dec_loop (post: Post) (initial: MachineState) (invariant: Nat → Post) (n: Nat):
  -- if:
  -- invariant holds before entering the loop
  invariant n initial ∧
  -- final iteration allows proving `post`
  (forall state, invariant 0 state → eventually post state) ∧
  -- while iterating, we eventually re-establish the invariant
  (forall state k, k ≠ 0 → invariant k state → eventually (invariant (k - 1)) state) →
  -- then: we can prove the post
  eventually post initial
  := by
    intro misc
    rcases misc with ⟨ initial_invariant, case_zero, case_nonzero ⟩
    if n = 0 then
      apply case_zero
      grind
    else
      apply eventually_trans (invariant (n - 1)) post
      grind
      intros srec _
      apply reg_dec_loop post srec invariant (n - 1)
      grind

-- TACTIC MACROS

-- Example 2: fine-grained tactics to step through the goal without un-necessary
-- steps, and relying only on low-level tactics

-- STEP TACTIC: reduce a match
syntax "step_match" : tactic
macro_rules
  | `(tactic|step_match) =>
  `(tactic|
    -- JP: looks like reducing a match needs both beta and iota?
    -- the match in the goal below does not reduce properly if I remove beta := true
    dsimp (config := { beta := true, zeta := false, iota := true, proj := false, eta := false })
  )

-- STEP TACTIC: reduce the lookup of the next instruction
-- TODO: bail if the state's .rip is not a constant
syntax "step_instr" : tactic
macro_rules
  | `(tactic|step_instr) =>
  `(tactic|
    delta step1 eval1 fetch;
    dsimp only [Instr.is_ctrl];
    dsimp only [Bool.false_eq_true, ↓dreduceIte]; -- special simproc for if https://github.com/leanprover/lean4/blob/master/src/Lean/Meta/Tactic/Simp/BuiltinSimprocs/Core.lean#L25-L40
    delta next
  )

-- NOTES: why is the right way of doing this? Ideally, we would not ask to
-- simplify anything that is not an internal definition, because it is not
-- modular. Problematic things here include, e.g., List.findIdx? (what if the
-- user uses this very function in their post-condition?).
--
-- Something equivalent to `match goal with` might work. Alternatively, we could
-- have copies of definitions, e.g. `def my_findIdx := normalize List.findIdx?`.
-- TODO: determine how to do that in Lean.
--
-- Furthermore, it would be nice to be able to specify that reducing e.g. a
-- projector should only be done if the left-hand side is not a variable.
syntax "step_one" : tactic
macro_rules
  | `(tactic|step_one) =>
  `(tactic|
    simp [
      step1,Instr.is_ctrl,eval1,fetch,
      -- works for calls to strt1
      strt1,eval_operand,eval_reg_or_mem,set_reg,set_reg_or_mem,effective_addr,eval_imm,sub_with_borrow,add_with_carry,sub_overflow,add_overflow,MachineState.setReg,next,Registers.set,pure,bind,next,MachineState.getReg,Registers.get,
      -- or calls to ctrl
      ctrl,lookup,jump_if,next] <;> try native_decide)
