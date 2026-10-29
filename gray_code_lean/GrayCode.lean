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

/-- A constant wire. -/
def const (v : BitVec 8) : Wire := fun _ => v

/-- Lift a one-input combinational function to a gate on wires. -/
def gate1 (f : BitVec 8 → BitVec 8) (a : Wire) : Wire := fun t => f (a t)

/-- Lift a two-input combinational function to a gate on wires. -/
def gate2 (f : BitVec 8 → BitVec 8 → BitVec 8) (a b : Wire) : Wire :=
  fun t => f (a t) (b t)

def xorGate : Wire → Wire → Wire := gate2 (· ^^^ ·)
def addGate : Wire → Wire → Wire := gate2 (· + ·)
def shr1    : Wire → Wire := gate1 (· >>> 1)

/-- A register with reset value `init`: it outputs `init` in cycle 0, then
its input from the previous cycle. -/
def reg (init : BitVec 8) (d : Wire) : Wire
  | 0     => init
  | t + 1 => d t

/-- A register whose input is its own output passed through the circuit `f`.
Lean has no general fixpoint on wires, so this unrolls the feedback loop one
cycle at a time: `loopReg init f = reg init (f (loopReg init f))`, provided
`f` is combinational (see `loopReg_spec`). -/
def loopReg (init : BitVec 8) (f : Wire → Wire) : Wire
  | 0     => init
  | t + 1 => f (const (loopReg init f t)) 0

/-! ## The circuit -/

/-- Binary counter: a register fed back through an incrementer. -/
def counter : Wire := loopReg 0 (fun q => addGate q (const 1))

/-- Binary-to-Gray encoder: `g = b ^^^ (b >>> 1)`. -/
def bin2gray (b : Wire) : Wire := xorGate b (shr1 b)

/-- The Gray-code counter. -/
def grayCounter : Wire := bin2gray counter

/-! ## Simulation -/

/-- The first `n` cycles of a wire. -/
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

/-- Consecutive values differ in exactly one bit. -/
def oneBitApart (a b : BitVec 8) : Bool :=
  ((List.range 8).filter fun i => (a ^^^ b).getLsbD i).length == 1

-- Each step of the first 10 cycles flips exactly one bit.
#guard (List.range 9).all fun t => oneBitApart (grayCounter t) (grayCounter (t + 1))

/-- The same check as a kernel-checked theorem. -/
theorem first10 : simulate grayCounter 10 = expected := by decide

/-- `loopReg` meets its specification for a combinational loop body. -/
theorem loopReg_spec (init : BitVec 8) (g : BitVec 8 → BitVec 8) :
    loopReg init (gate1 g) = reg init (gate1 g (loopReg init (gate1 g))) := by
  funext t
  cases t <;> rfl

end GrayCode
