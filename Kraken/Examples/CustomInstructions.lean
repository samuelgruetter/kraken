import Kraken.Semantics
import Kraken.Parser

structure ExtraState where
  bells: UInt64
  whistles: UInt64
  deriving Repr, BEq, DecidableEq, Hashable, Lean.ToExpr

abbrev SystemState := MachineState × ExtraState

-- Note: We do not get access to rip here.
-- We also don't need it here, but other unsupported-instruction handlers might
-- need it in order to jump to a handler implemented in assembly (rather
-- than a handler modeled in Lean like here).
def handle_bells_and_whistles (s : MachineData) (extra : ExtraState)
  (i : Instr) (ok : MachineData → ExtraState → Except String SystemState)
  : Except String SystemState :=
  match i.operation with
  | Operation.generic mnemonic operands =>
    let mn := mnemonic.toLower
    if mn = "rdbells" && operands = [] then
      -- bells are always 64-bit, and rdbells' implicit dest is %rax
      ok (s.setReg Reg.rax extra.bells.toBitVec) extra
    else if mn.startsWith "rdwhistles" &&
            mn.length = "rdwhistles_".length then
      -- whistles are accessible as 8/16/32/64 bit
      match operands with
      | [.regOrMem (.reg r)] =>
          ok (s.setReg r (extra.whistles.toBitVec.setWidth _)) extra
      | _ => .error s!"wrong number of operands for rdwhistles"
    else if mn = "wrbells" && operands = [] then
      -- bells are always 64-bit, and wdbells' implicit source is %rax
      ok s { extra with bells := s.regs.rax }
    else if mn.startsWith "wrwhistles" &&
            mn.length = "wrwhistles_".length then
      -- whistles are accessible as 8/16/32/64 bit
      match operands with
      | [.regOrMem (.reg r)] =>
        ok s { extra with whistles := UInt64.ofBitVec ((s.regs.get r).setWidth _) }
      | _ => .error s!"wrong number of operands for wrwhistles"
    else .error s!"unsupported instruction {repr i}"
  | _ => .error s!"unsupported instruction {repr i}"

def handle_effects (extra : ExtraState) (es : Effects)
  (ok : SystemState → Except String SystemState)
: Except String SystemState :=
  match es with
  | .done ms => ok (.mk ms extra)
  | .undefined msg => .error msg
  | .unimplemented msg => .error msg
  | unimplemented_instruction s i resume =>
       handle_bells_and_whistles s extra i (fun s' extra' =>
         handle_effects extra' (resume s') ok)
  | .can_read _ _ cont => handle_effects extra (cont true) ok
  | .can_write _ _ cont => handle_effects extra (cont true) ok
  | .can_exec _ cont => handle_effects extra (cont true) ok
  | .nonmem_load addr .. => .error s!"Load at unmapped address {repr addr}"
  | .nonmem_store addr .. => .error s!"Store at unmapped address {repr addr}"
  | @Effects.pick _ t cont => handle_effects extra (cont (t.from_hash (hash extra))) ok

partial def Executable.eval_with_bells_and_whistles (e : Executable)
  (until_ : SystemState → Bool) (s : SystemState) : Except String SystemState :=
  if until_ s then .ok s
  else handle_effects s.2 (e.straightline s.1 .done)
          (Executable.eval_with_bells_and_whistles e until_)

def _start: String := "_start"
def _end: String := "_end"

def finishCriterion (p: Program) (s: SystemState): Bool :=
  s.1.2 = p.fakeLayout.labels.label _end

def runKraken (asmCode : String) : Except String SystemState := do
  let prog ← Kraken.Parser.parse_lenient (_start ++ ":" ++ asmCode ++ "\n" ++ _end ++ ":")
  let initState: SystemState := (({dmem := ∅, regs := {
    rax := 42,
    rbx := 43,
    rcx := 44,
  }}, prog.fakeLayout.labels.label _start), {
    bells := 0xB3115,
    whistles := 0x1141571E5,
  })
  prog.fakeLayout.eval_with_bells_and_whistles (finishCriterion prog) initState

def simple_swap : String :=
 "mov %rax, %rcx
  mov %rbx, %rax
  mov %rcx, %rbx"

def run_and_get_rax_and_rbx (prog : String): UInt64 × UInt64 :=
  match runKraken prog with
  | .ok s => (s.1.1.regs.rax, s.1.1.regs.rbx)
  | .error _ => (-1, -1)

example : run_and_get_rax_and_rbx simple_swap = (43, 42) := by native_decide

def parse_or_nil (s : String) : List Directive :=
  match Kraken.Parser.parse_lenient s with
  | .ok l => l
  | .error _ => []

example : parse_or_nil "lol %eax, %ebx, $42" = [Directive.instr
   { address_size := .W32,
     operation_size := .W32,
     operation := .generic "lol" [Reg.eax, Reg.ebx, ConstExpr.int64 42] }] :=
  by native_decide

def swap_bells_and_whistles_TODO_why_does_this_not_parse : String :=
 "rdbells            # bells are always 64-bit, and rdbells' implicit dest is %rax
  rdwhistlesl %ebx   # whistles are accessible as 8/16/32/64 bit, here we use the l suffix to get 32 bits
  wrwhistlesq %rax   # q suffix means we write 64 bits
  mov %rbx, %rax     # need to move to implicit argument register first
  wrbells            # always writes 64 bits from %rax"

-- #eval runKraken swap_bells_and_whistles_TODO_why_does_this_not_parse

def swap_bells_and_whistles : String :=
 "# bells are always 64-bit, and rdbells' implicit dest is %rax
  rdbells
  # whistles are accessible as 8/16/32/64 bit, here we use the l suffix to get 32 bits
  rdwhistlesl %ebx
  # q suffix means we write 64 bits
  wrwhistlesq %rax
  # need to move to implicit argument register first
  mov %rbx, %rax
  # always writes 64 bits from %rax
  wrbells"

def run_and_get_bells_and_whistles (prog : String): ExtraState :=
  match runKraken prog with
  | .ok s => s.2
  | .error _ => { bells := -1, whistles := -1 }

example : run_and_get_bells_and_whistles swap_bells_and_whistles = {
   bells := 0x141571E5, -- rdwhistlesl only read 32 bits, so the first 1 got truncated!
   whistles := 0xB3115
} := by native_decide
