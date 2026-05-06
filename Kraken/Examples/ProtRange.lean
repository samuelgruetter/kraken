/- This example will show how Kraken can be used to model an x86 extension
   with a custom syscall-like instruction and how to run assembly programs
   against a high-level specification of a custom operating system implementing
   the custom syscall-like instruction. -/

import Kraken.Semantics
import Kraken.Parser
open Kraken.Parser


--- Syntax ---

inductive XInstr
  | instr (_ : Instr)
  | protrange
  deriving BEq, DecidableEq, Repr, Hashable, Lean.ToExpr

inductive XDirective
  | instr (_ : XInstr)
  | label (_ : Label)
  -- contrary to regular Directive, we do not support byteArray, but
  -- we do support comments
  | comment (_ : String)
  deriving BEq, DecidableEq, Repr, Hashable, Lean.ToExpr


--- Parsing ---

-- Note: <|> (aka orElse) only picks the RHS if the LHS fails AND consumes no input,
-- so, often, you need (attempt LHS <|> RHS) to achieve what you meant!

/-- Parse a line comment starting with # or //.
    and return the string (rather than ignoring it) -/
def parseLineComment : Std.Internal.Parsec.String.Parser String := do
  skipHWs
  let marker ← Std.Internal.Parsec.String.pstring "#" <|>
               Std.Internal.Parsec.String.pstring "//"
  let comment ← Std.Internal.Parsec.many (Std.Internal.Parsec.satisfy fun c => c != '\n')
  pure (marker ++ String.ofList comment.toList)

def parseCustomInstr : Std.Internal.Parsec.String.Parser XInstr := do
  skipHWs
  let mnemonic ← parseName
  let mn := mnemonic.toLower
  match mn with
  | "protrange" => pure .protrange
  | _ => Std.Internal.Parsec.fail "not a custom instr"

def parseXInstr : Std.Internal.Parsec.String.Parser XInstr := do
  Std.Internal.Parsec.attempt parseCustomInstr <|>
  (do let i ← parseInstr; pure (.instr i))

/-- Parse 0 or 1 p, returning a list of 0 or 1 elements -/
def optionalSingleton {α} (p : Std.Internal.Parsec.String.Parser α) :
  Std.Internal.Parsec.String.Parser (List α) :=
    Std.Internal.Parsec.attempt (do let r ← p; pure [r]) <|> pure []

/-- A line of the form:
    label? instr? comment? EOF
    Each of the three items is optional, and all 8 possible combinations are allowed.
    Note that since we split the input line-by-line, each line is considered to
    end by an EOF. -/
def xparseLine : Std.Internal.Parsec.String.Parser (List XDirective) := do
  skipHWs
  let l ← optionalSingleton parseLabelDecl
  -- TODO: try to avoid swallowing the errors of instruction parsing,
  -- but also don't silently ignore instructions with missing operands
  let i ← optionalSingleton parseXInstr
  let c ← optionalSingleton parseLineComment
  Std.Internal.Parsec.eof -- we actually mean "end of line, not end of file"
  pure (l.map .label ++ i.map .instr ++ c.map .comment)

def xparse : String -> Except String (List XDirective) := parseLines xparseLine

/-- A version of `xparse` that runs at compile-time. -/
elab "xparse(" s:str ")" : term => do
  match xparse s.getString with
  | .ok p => return Lean.toExpr p
  | .error e => throwErrorAt s e


--- Sample code ---

def protectRegion : List XDirective := xparse("
  # protrange makes %rbx 4KB pages starting at %rax write-protected.
  # The lower 12 bits of the address in %rax are ignored
  mov $0x20000, %rax
  mov $16, %rbx
  protrange
")

def writeProtectedRegion : List XDirective := xparse("
  mov $0x20088, %rax
  movq $42, (%rax)
")

def writeUnProtectedRegion : List XDirective := xparse("
  mov $0x10088, %rbx
  movq $43, (%rbx)
")

def readProtectedRegion : List XDirective := xparse("
  mov $0x20088, %rax
  mov (%rax), %rcx
")

def readUnProtectedRegion : List XDirective := xparse("
  mov $0x10088, %rbx
  mov (%rbx), %rcx
")


--- Semantics ---

structure Range where
  start: BitVec 64
  endIncl: BitVec 64

-- extended machine state is a machine state and a list of write-protected ranges
abbrev XState := List Range
abbrev XMachineState := MachineState × XState

def Range.contains (r : Range) (addr : BitVec 64) (w : Width) : Bool :=
  r.start <= addr && addr <= r.endIncl - (w.bytesv - 1)
