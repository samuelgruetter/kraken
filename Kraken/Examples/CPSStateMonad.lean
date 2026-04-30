-- A scratch implementation of the State Monad using Continuation-Passing Style

/--
  StateCPS σ α is a function that takes:
  1. An initial state of type σ
  2. A continuation that accepts the result (α) and the final state (σ)
  It returns the result of the continuation (ω).
-/
structure StateCPS (σ α : Type) : Type 1 where
  apply : {ω : Type} → σ → (α → σ → ω) → ω

-- --- Monad Instance Implementation ---

instance (σ : Type) : Pure (StateCPS σ) where
  pure x := ⟨fun s k => k x s⟩

instance (σ : Type) : Bind (StateCPS σ) where
  bind ma f := ⟨fun s k => ma.apply s (fun a s' => (f a).apply s' k)⟩

instance (σ : Type) : Monad (StateCPS σ) where
  pure x := ⟨fun s k => k x s⟩
  bind ma f := ⟨fun s k => ma.apply s (fun a s' => (f a).apply s' k)⟩

-- --- State Operations ---

instance {σ : Type} : MonadStateOf σ (StateCPS σ) where
  get        := ⟨fun s k => k s s⟩
  set s'     := ⟨fun _ k => k () s'⟩
  modifyGet f := ⟨fun s k => let (a, s') := f s; k a s'⟩

-- --- Execution ---

/--
  To "run" the CPS monad, we provide a continuation that
  constructs a final tuple (α × σ).
-/
def run {σ α : Type} (ma : StateCPS σ α) (initialState : σ) : α × σ :=
  ma.apply initialState (fun a s => (a, s))

-- --- Example Usage ---

def counterExample : StateCPS Int String := do
  let start ← get
  modify (λ n => n + 10)
  let middle ← get
  set (middle * 2)
  let finalState ← get
  pure s!"Started at {start}, then was {middle}, ended at {finalState}"

#eval run counterExample 5
-- Result: ("Started at 5, then was 15, ended at 30", 30)
