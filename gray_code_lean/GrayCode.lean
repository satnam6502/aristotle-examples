/-!
# An 8-bit Gray-code counter

A small synchronous circuit model. A wire is a map from clock cycle (`Nat`)
to the 8-bit value it carries in that cycle. Gates are pointwise functions on
wires. A register delays its input by one cycle.

The counter is a binary counter (a register fed back through an incrementer)
followed by a combinational binary-to-Gray encoder:

```
        +-----+     +-----+   count   +-----------+   gray
   +--->| inc |---->| reg |-----+---->| bin2gray  |------->
   |    +-----+     +-----+     |     +-----------+
   +----------------------------+
```
-/

namespace GrayCode

/-- A wire: the value it carries at each clock cycle. -/
abbrev Wire := Nat → BitVec 8

/-! ## Primitives -/

/-- Lift a one-input combinational function to a gate on wires. -/
def gate1 (f : BitVec 8 → BitVec 8) (a : Wire) : Wire := fun t => f (a t)

/-- Lift a two-input combinational function to a gate on wires. -/
def gate2 (f : BitVec 8 → BitVec 8 → BitVec 8) (a b : Wire) : Wire :=
  fun t => f (a t) (b t)

def xorGate : Wire → Wire → Wire := gate2 (· ^^^ ·)
def shr1    : Wire → Wire := gate1 (· >>> 1)

/-- A register with reset value `init`: it outputs `init` in cycle 0, then
its input from the previous cycle. -/
def reg (init : BitVec 8) (d : Wire) : Wire
  | 0     => init
  | t + 1 => d t

/-- A register whose input is its own output passed through the combinational
logic `f`: `loopReg init f = reg init (gate1 f (loopReg init f))` (see
`loopReg_spec`). Lean has no general fixpoint on wires, so this unrolls the
feedback loop one cycle at a time. `f` maps values, not wires, so the loop
body cannot hold state. -/
def loopReg (init : BitVec 8) (f : BitVec 8 → BitVec 8) : Wire
  | 0     => init
  | t + 1 => f (loopReg init f t)

/-! ## The circuit -/

/-- The incrementer. -/
def inc (b : BitVec 8) : BitVec 8 := b + 1

/-- Binary counter: a register fed back through an incrementer. -/
def counter : Wire := loopReg 0 inc

/-- The Gray code of one value: `b ^^^ (b >>> 1)`. -/
def gray (b : BitVec 8) : BitVec 8 := b ^^^ (b >>> 1)

/-- Binary-to-Gray encoder, built from gates: it computes `gray` each cycle. -/
def bin2gray (b : Wire) : Wire := xorGate b (shr1 b)

/-- The Gray-code counter. -/
def grayCounter : Wire := bin2gray counter

/-! ## Simulation -/

/-- The first `n` cycles of a wire. Each cycle is recomputed from cycle 0, so
this takes O(n²) steps, which is fine for short traces. -/
def simulate (w : Wire) (n : Nat) : List (BitVec 8) := (List.range n).map w

/-- Render a byte as 8 binary digits, MSB first. -/
def toBin (b : BitVec 8) : String :=
  String.ofList ((List.range 8).reverse.map fun i => if b.getLsbD i then '1' else '0')

-- The first 10 Gray codes as numbers: [0, 1, 3, 2, 6, 7, 5, 4, 12, 13]
#eval (simulate grayCounter 10).map BitVec.toNat

-- A cycle-by-cycle trace of the counter and its Gray code.
#eval (List.range 10).forM fun t =>
  IO.println s!"cycle {t}:  count {toBin (counter t)}  gray {toBin (grayCounter t)}"

/-! ## Checks -/

/-- The expected first 10 Gray codes. -/
def expected : List (BitVec 8) :=
  [0b00000000, 0b00000001, 0b00000011, 0b00000010, 0b00000110,
   0b00000111, 0b00000101, 0b00000100, 0b00001100, 0b00001101]

-- The simulation produces the expected codes.
#guard simulate grayCounter 10 == expected

-- The counter wraps from 255 back to 0.
#guard grayCounter 255 == 0b10000000 && grayCounter 256 == 0

/-- The same check as a kernel-checked theorem. -/
theorem first10 : simulate grayCounter 10 = expected := by decide

/-- `loopReg` meets its specification. -/
theorem loopReg_spec (init : BitVec 8) (f : BitVec 8 → BitVec 8) :
    loopReg init f = reg init (gate1 f (loopReg init f)) := by
  funext t
  cases t <;> rfl

/-- In cycle `t` the counter holds `t` modulo 256. -/
theorem counter_eq (t : Nat) : counter t = BitVec.ofNat 8 t := by
  induction t with
  | zero => rfl
  | succ t ih =>
    show counter t + 1 = _
    rw [ih, BitVec.ofNat_add]
    rfl

/-- In cycle `t` the Gray-code counter outputs the Gray code of `t` modulo 256. -/
theorem grayCounter_eq (t : Nat) : grayCounter t = gray (BitVec.ofNat 8 t) := by
  rw [← counter_eq]
  rfl

/-- Two values differ in exactly one bit. -/
def oneBitApart (a b : BitVec 8) : Bool :=
  ((List.range 8).filter fun i => (a ^^^ b).getLsbD i).length == 1

/-- The Gray codes of `b` and `b + 1` differ in exactly one bit, for all 256
values of `b`, including the wrap from 255 to 0. -/
theorem gray_oneBitApart : ∀ b : BitVec 8, oneBitApart (gray b) (gray (b + 1)) := by
  decide

/-- Each step of the Gray-code counter flips exactly one bit, in every cycle. -/
theorem grayCounter_oneBitApart (t : Nat) :
    oneBitApart (grayCounter t) (grayCounter (t + 1)) :=
  gray_oneBitApart (counter t)

end GrayCode
