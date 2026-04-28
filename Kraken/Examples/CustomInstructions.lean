import Kraken.Semantics
import Kraken.Parser

def _start: String := "_start"
def _end: String := "_end"

def finishCriterion (p: Program) (s: MachineState): Bool :=
  s.2 = p.fakeLayout.labels.label _end

def runKraken (asmCode : String) : Except String MachineState := do
  let prog ← Kraken.Parser.parse_lenient (_start ++ ":" ++ asmCode ++ "\n" ++ _end ++ ":")
  let initState: MachineState := ({dmem := ∅, regs := {
    rax := 42,
    rbx := 43,
    rcx := 44,
  }}, prog.fakeLayout.labels.label _start)
  prog.fakeLayout.eval initState (finishCriterion prog)

def simple_swap : String :=
 "mov %rax, %rcx
  mov %rbx, %rax
  mov %rcx, %rbx"

def run_and_get_rax_and_rbx (prog : String): UInt64 × UInt64 :=
  match runKraken prog with
  | .ok s => (s.1.regs.rax, s.1.regs.rbx)
  | .error _ => (-1, -1)

-- #eval Kraken.Parser.parse_lenient simple_swap

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

def swap_bells_and_whistles_TODO_why_does_this_not_work : String :=
 "rdbells            # bells are always 64-bit, and rdbells' implicit dest is %rax
  rdwhistlesl %ebx   # whistles are accessible as 8/16/32/64 bit, here we use the l suffix to get 32 bits
  wrwhistlesq %rax   # q suffix means we write 64 bits
  mov %rbx, %rax     # need to move to implicit argument register first
  wrbells            # always writes 64 bits from %rax"

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

def run_and_get_bells_and_whistles (prog : String): UInt64 × UInt64 :=
  match runKraken prog with
  | .ok s => (s.1.regs.rax, s.1.regs.rbx)
  | .error _ => (-1, -1)

def run_and_get_error (prog : String): String :=
  match runKraken prog with
  | .ok _ => "actually, no error"
  | .error msg => msg

-- #eval runKraken swap_bells_and_whistles

-- example : run_and_get_bells_and_whistles swap_bells_and_whistles = (43, 42) := by native_decide
example : run_and_get_error swap_bells_and_whistles = "unsupported instruction { address_size := Width.W64, operation_size := Width.W64, operation := Operation.generic \"rdbells\" [] }" := by native_decide
