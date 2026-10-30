/-!
# An N-bit ripple-carry adder as Boolean functions

The same design as `ripple_carry_adder.sv`, gate for gate. There is no time:
each wire is a `Bool`, and an N-bit bus is a function from bit index to
`Bool`, like `wire [N-1:0]`. Each gate primitive is a Boolean function, and
each module is a function from its inputs to its outputs.
-/

namespace RippleCarryAdder

/-! ## Gate primitives -/

def xorGate (a b : Bool) : Bool := a ^^ b
def andGate (a b : Bool) : Bool := a && b
def orGate  (a b : Bool) : Bool := a || b
def bufGate (a : Bool)   : Bool := a

/-! ## `half_adder` -/

structure HalfAdderOut where
  sum   : Bool
  carry : Bool

/-- `half_adder`: sum = a ^ b, carry = a & b. -/
def halfAdder (a b : Bool) : HalfAdderOut :=
  { sum := xorGate a b, carry := andGate a b }

/-! ## `full_adder` -/

structure FullAdderOut where
  sum  : Bool
  cout : Bool

/-- `full_adder`: two half adders and an `or` gate.
sum = a ^ b ^ cin, cout = majority(a, b, cin). -/
def fullAdder (a b cin : Bool) : FullAdderOut :=
  let ⟨s1, c1⟩  := halfAdder a b
  let ⟨sum, c2⟩ := halfAdder s1 cin
  { sum := sum, cout := orGate c1 c2 }

/-! ## `ripple_carry_adder` -/

/-- An N-bit bus, like `wire [N-1:0]`: bit `i` is `bus i`. -/
abbrev Bus (n : Nat) := Fin n → Bool

/-- The default width, as in `parameter int N = 8`. -/
def defaultWidth : Nat := 8

/-- The carry wires. `carry a b cin i` is `carry[i]`, the carry into bit `i`,
for `i ≤ n`. `carry[0]` is `cin` through a `buf`, and `carry[i+1]` is the
carry out of the full adder at bit `i`. `carry[n]` is the carry out. -/
def carry (a b : Bus n) (cin : Bool) : (i : Nat) → i ≤ n → Bool
  | 0,     _ => bufGate cin
  | i + 1, h => (fullAdder (a ⟨i, h⟩) (b ⟨i, h⟩) (carry a b cin i (by omega))).cout

/-- The full adder at bit `i`, `g_bit[i].fa`. -/
def stage (a b : Bus n) (cin : Bool) (i : Fin n) : FullAdderOut :=
  fullAdder (a i) (b i) (carry a b cin i (Nat.le_of_lt i.isLt))

structure RippleCarryAdderOut (n : Nat) where
  sum  : Bus n
  cout : Bool

/-- `ripple_carry_adder #(n)`: n full adders chained through their carries,
and a `buf` from `carry[n]` to `cout`. {cout, sum} = a + b + cin, as
`rippleCarryAdder_correct` proves. -/
def rippleCarryAdder (n : Nat) (a b : Bus n) (cin : Bool) : RippleCarryAdderOut n :=
  { sum  := fun i => (stage a b cin i).sum
    cout := bufGate (carry a b cin n (Nat.le_refl n)) }

/-- The carry out of stage `i` is the carry into bit `i + 1`. -/
theorem stage_cout (a b : Bus n) (cin : Bool) (i : Fin n) :
    (stage a b cin i).cout = carry a b cin (i + 1) i.isLt := rfl

/-! ## Buses as numbers -/

/-- The bus holding the low `n` bits of `x`. -/
def Bus.ofNat (n x : Nat) : Bus n := fun i => x.testBit i

/-- Bits 1 to n of an (n+1)-bit bus. -/
def Bus.tail (v : Bus (n + 1)) : Bus n := fun i => v i.succ

/-- The number a bus holds, with bit 0 least significant. -/
def Bus.toNat : {n : Nat} → Bus n → Nat
  | 0,     _ => 0
  | _ + 1, v => (v 0).toNat + 2 * Bus.toNat v.tail

/-- `{cout, sum}` as a number. -/
def RippleCarryAdderOut.toNat (o : RippleCarryAdderOut n) : Nat :=
  o.sum.toNat + 2 ^ n * o.cout.toNat

theorem Bus.toNat_succ (v : Bus (n + 1)) : v.toNat = (v 0).toNat + 2 * v.tail.toNat := rfl

/-! ## Correctness -/

/-- A full adder adds its three inputs. -/
theorem fullAdder_toNat (a b cin : Bool) :
    (fullAdder a b cin).sum.toNat + 2 * (fullAdder a b cin).cout.toNat
      = a.toNat + b.toNat + cin.toNat := by
  cases a <;> cases b <;> cases cin <;> rfl

/-- Above bit 0, the carries of an (n+1)-bit adder are those of an n-bit
adder on bits 1 to n, whose carry in is the carry out of bit 0. -/
theorem carry_succ (a b : Bus (n + 1)) (cin : Bool) (i : Nat)
    (h₁ : i + 1 ≤ n + 1) (h₂ : i ≤ n) :
    carry a b cin (i + 1) h₁ = carry a.tail b.tail (fullAdder (a 0) (b 0) cin).cout i h₂ := by
  induction i with
  | zero => rfl
  | succ i ih =>
    show (fullAdder (a ⟨i + 1, _⟩) (b ⟨i + 1, _⟩) (carry a b cin (i + 1) _)).cout =
      (fullAdder (a.tail ⟨i, _⟩) (b.tail ⟨i, _⟩) (carry a.tail b.tail _ i _)).cout
    rw [ih (by omega) (by omega)]
    rfl

theorem sum_zero (a b : Bus (n + 1)) (cin : Bool) :
    (rippleCarryAdder (n + 1) a b cin).sum 0 = (fullAdder (a 0) (b 0) cin).sum := rfl

/-- Above bit 0, the sum bits of an (n+1)-bit adder are those of an n-bit
adder on bits 1 to n, whose carry in is the carry out of bit 0. -/
theorem sum_tail (a b : Bus (n + 1)) (cin : Bool) :
    (rippleCarryAdder (n + 1) a b cin).sum.tail =
      (rippleCarryAdder n a.tail b.tail (fullAdder (a 0) (b 0) cin).cout).sum := by
  funext i
  show (fullAdder (a i.succ) (b i.succ) (carry a b cin (i + 1) _)).sum =
    (fullAdder (a.tail i) (b.tail i) (carry a.tail b.tail _ i _)).sum
  rw [carry_succ _ _ _ _ _ (Nat.le_of_lt i.isLt)]
  rfl

/-- The carry out of an (n+1)-bit adder is the carry out of an n-bit adder
on bits 1 to n, whose carry in is the carry out of bit 0. -/
theorem cout_succ (a b : Bus (n + 1)) (cin : Bool) :
    (rippleCarryAdder (n + 1) a b cin).cout =
      (rippleCarryAdder n a.tail b.tail (fullAdder (a 0) (b 0) cin).cout).cout :=
  carry_succ a b cin n _ (Nat.le_refl n)

/-- The adder adds: `{cout, sum}`, read as a number, is `a + b + cin`. -/
theorem rippleCarryAdder_correct (n : Nat) (a b : Bus n) (cin : Bool) :
    (rippleCarryAdder n a b cin).toNat = a.toNat + b.toNat + cin.toNat := by
  induction n generalizing cin with
  | zero => cases cin <;> rfl
  | succ n ih =>
    have hfa := fullAdder_toNat (a 0) (b 0) cin
    have hih := ih a.tail b.tail (fullAdder (a 0) (b 0) cin).cout
    unfold RippleCarryAdderOut.toNat at hih ⊢
    rw [Bus.toNat_succ (rippleCarryAdder _ a b cin).sum, sum_tail, sum_zero, cout_succ,
      Bus.toNat_succ a, Bus.toNat_succ b, Nat.pow_succ, Nat.mul_comm (2 ^ n) 2,
      Nat.mul_assoc]
    generalize 2 ^ n * _ = carryOut at hih ⊢
    omega

/-- With no carry in, the adder's output is the sum of its two inputs. -/
theorem rippleCarryAdder_add (n : Nat) (a b : Bus n) :
    (rippleCarryAdder n a b false).toNat = a.toNat + b.toNat :=
  rippleCarryAdder_correct n a b false

/-! ## Checks, as in `ripple_carry_adder_tb.sv` -/

/-- Whether the n-bit adder agrees with `+` on `a`, `b` and `cin`, where
`a` and `b` are below `2 ^ n`. -/
def check (n a b : Nat) (cin : Bool) : Bool :=
  (rippleCarryAdder n (.ofNat n a) (.ofNat n b) cin).toNat == a + b + cin.toNat

/-- Every input of the n-bit adder: `2 ^ (2n + 1)` cases. -/
def exhaustive (n : Nat) : Bool :=
  (List.range (2 ^ n)).all fun a =>
    (List.range (2 ^ n)).all fun b =>
      [false, true].all fun cin => check n a b cin

/-- Every pair of corner values, with `cin` 0 and 1: all zeros, one, all
ones, `0111...1`, `1000...0`, alternating bits with bit 0 set, and its
complement. -/
def corners (n : Nat) : Bool :=
  let ones := 2 ^ n - 1
  let alt  := (List.range n).foldl (fun acc i => if i % 2 == 0 then acc + 2 ^ i else acc) 0
  let vs   := [0, 1, ones, ones / 2, ones - ones / 2, alt, ones - alt]
  vs.all fun a => vs.all fun b => [false, true].all fun cin => check n a b cin

-- The default width, every input: 131,072 cases.
#guard exhaustive defaultWidth

-- Other widths, every input.
#guard exhaustive 1
#guard exhaustive 2

-- Wide adders, corner values.
#guard corners 11
#guard corners 32
#guard corners 33
#guard corners 64
#guard corners 100

-- One addition at the default width: 200 + 100 + 1 = 301 = 256 + 45.
#eval
  let o := rippleCarryAdder defaultWidth (.ofNat 8 200) (.ofNat 8 100) true
  (o.cout, o.sum.toNat)

end RippleCarryAdder
