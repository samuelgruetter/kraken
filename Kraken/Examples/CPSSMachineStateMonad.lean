import Kraken.Semantics

def CPSMachineState (α : Type) : Type 1 :=
  MachineState → (α → MachineState → Effects) → Effects

-- --- Monad Instance Implementation ---

instance : Pure CPSMachineState where
  pure x := fun s k => k x s

instance : Bind CPSMachineState where
  bind ma f := fun s k => ma s (fun a s' => (f a) s' k)

instance : Monad CPSMachineState where
  pure x := fun s k => k x s
  bind ma f := fun s k => ma s (fun a s' => (f a) s' k)

-- --- State Operations ---

instance : MonadStateOf MachineState CPSMachineState where
  get        := fun s k => k s s
  set s'     := fun _ k => k () s'
  modifyGet f := fun s k => let (a, s') := f s; k a s'

-- --- Execution ---

def run (ma : CPSMachineState Unit) (initialState : MachineState) : Effects :=
  ma initialState (fun _ s => Effects.done s)

-- --- Example Usage ---

def ex1 : CPSMachineState Unit := do
  let start ← get
  modify (λ s => { s with 1 := { s.1 with regs := s.1.regs.set64 Reg64.rax 42 } })
  let middle ← get
  set { middle with 1 := { middle.1 with regs := start.1.regs.set64 Reg64.rbx 84 }}
  let finalState ← get
  set finalState

#eval match run ex1 ({}, 1234) with
      | .done s => s
      | _ => ({}, 4321)
