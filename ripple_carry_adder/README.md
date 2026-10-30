# Ripple-carry adder: a structural N-bit adder in SystemVerilog and Lean

`ripple_carry_adder.sv` is a parameterized N-bit ripple-carry adder. The
width defaults to 8. The design is fully structural: gate primitives only,
with no `assign` statements and no behavioural `+`.

`ripple_carry_adder_sva.sv` binds an SVA assertion to the design, and EBMC
proves it.

`ripple_carry_adder.lean` is the same design, gate for gate, written as
Boolean functions in plain Lean 4 with no Mathlib. It proves the adder
correct for every width.

## Files

| File | What it is |
|---|---|
| `ripple_carry_adder.sv` | The design: `half_adder`, `full_adder` and `ripple_carry_adder #(N)` |
| `ripple_carry_adder_tb.sv` | A self-checking testbench |
| `ripple_carry_adder_sva.sv` | An SVA assertion that the output is the sum of the inputs, bound to `ripple_carry_adder` |
| `ripple_carry_adder.lean` | The same design as Boolean functions, a proof that it adds, and checks like the testbench's |
| `lean-toolchain` | Pins Lean `v4.34.1` for `ripple_carry_adder.lean` |
| `README.md` | This file |

## The design

- **`half_adder`.** An `xor` gate makes the sum, and an `and` gate makes the
  carry.
- **`full_adder`.** Two half adders and an `or` gate. The first half adder
  adds `a` and `b`. The second adds that sum to `cin`. The `or` combines
  the two carries.
- **`ripple_carry_adder #(N)`.** A `for` loop inside a `generate` block makes
  N full adders, `g_bit[0].fa` to `g_bit[N-1].fa`. `carry[i]` is the carry
  into bit `i`. Two `buf` gates connect `cin` to `carry[0]` and `carry[N]`
  to `cout`.

```
       a[N-1] b[N-1]       a[1] b[1]       a[0] b[0]
          |    |              |   |           |   |
        +--------+         +--------+      +--------+
 cout <-|   fa   |<- ... <-|   fa   |<-----|   fa   |<- cin
        +--------+         +--------+      +--------+
            |                  |               |
         sum[N-1]            sum[1]          sum[0]
```

Synthesized with Yosys at N = 8, the adder has 16 `xor`, 16 `and` and 8 `or`
gates, which is 2, 2 and 1 for each full adder. The `buf` gates become
wires.

## The testbench

`ripple_carry_adder_tb` compares `{cout, sum}` with `a + b + cin` computed at
N+1 bits. It uses `!==`, so X or Z outputs also fail.

- **N ≤ 10.** It tries every `a`, `b` and `cin`. At the default N = 8 that
  is 131,072 tests.
- **N > 10.** It tries every pair from seven corner values, with `cin` 0
  and 1. The values are all zeros, one, all ones, `0111...1`, `1000...0`,
  alternating bits with bit 0 set, and its complement. Then it runs
  100,000 random tests.

It prints `PASS` and calls `$finish`. If any test fails, it prints up to 10
failures and calls `$fatal`, so the simulator exits with a non-zero status.
The parameters `EXHAUSTIVE_MAX_N` and `RANDOM_TESTS` change the limits.

## The SVA assertion

`ripple_carry_adder_sva.sv` holds a checker module, `ripple_carry_adder_sva`,
and a `bind` that puts an instance of it, `u_sva`, inside every
`ripple_carry_adder`. The bind passes on the adder's `N`, so the checker
always has the adder's width.

```systemverilog
always_comb begin
  assert_sum: assert ({cout, sum} == (N+1)'(a) + (N+1)'(b) + (N+1)'(cin));
end
```

The output `{cout, sum}` must be the (N+1)-bit sum of `a`, `b` and `cin`.
With `cin` = 0, that is the sum of the two inputs.

- **An immediate assertion, not a concurrent `property`.** A concurrent
  assertion needs a clock, and the adder has none. EBMC proves an unclocked
  `assert property`, but slang rejects it ("sequence has no explicit
  clocking event") and Verilator won't run it ("Unsupported: Unclocked
  assertion"). The immediate assertion works in all three. It is also alone
  in its `always_comb` block, the only assertion form Aristotle reads.
- **Named connections.** The bind connects the ports by name. EBMC 6.1
  rejects `.*` ("no support for wildcard port connection").

### The EBMC proof

```bash
ebmc ripple_carry_adder.sv ripple_carry_adder_sva.sv --top ripple_carry_adder
```

This needs EBMC 6.1 or later. EBMC 6.0 doesn't support `bind`, and it can't
parse the label on `end: g_bit`.

EBMC proves `ripple_carry_adder.u_sva.0.assert_sum` with its transition
property engine. The adder has no state, so one transition covers every
input: this is a full proof, not a bounded one.

```
** Results:
[ripple_carry_adder.u_sva.0.assert_sum] always {...: PROVED (transition property)
```

EBMC has no option to set a parameter. To prove another width, add a small
top module that instantiates `ripple_carry_adder #(.N(...))`, and pass it to
EBMC with `--top`. The bind follows the instance.

## The Lean model

`ripple_carry_adder.lean` has no notion of time. Each wire is a `Bool`, and
an N-bit bus is a `Bus n := Fin n → Bool`, so bit `i` of `a` is `a i`.

| SystemVerilog | Lean |
|---|---|
| `xor`, `and`, `or`, `buf` primitives | `xorGate`, `andGate`, `orGate`, `bufGate` |
| `half_adder` | `halfAdder a b`, returning `sum` and `carry` |
| `full_adder` | `fullAdder a b cin`, returning `sum` and `cout`, built from two `halfAdder`s and an `orGate` |
| `wire [N:0] carry` | `carry a b cin i`, defined by recursion on `i`: `bufGate cin` at 0, and the full adder's `cout` at `i + 1` |
| `g_bit[i].fa` | `stage a b cin i` |
| `ripple_carry_adder #(N)` | `rippleCarryAdder n a b cin`, returning `sum` and `cout` |
| `N = 8` | `defaultWidth` |

The theorem `stage_cout` states, by `rfl`, that the carry out of stage `i`
is `carry[i+1]`.

### The proof

`Bus.toNat` reads a bus as a number, with bit 0 least significant, and
`RippleCarryAdderOut.toNat` reads `{cout, sum}` as `sum + 2^n * cout`.

```lean
theorem rippleCarryAdder_correct (n : Nat) (a b : Bus n) (cin : Bool) :
    (rippleCarryAdder n a b cin).toNat = a.toNat + b.toNat + cin.toNat

theorem rippleCarryAdder_add (n : Nat) (a b : Bus n) :
    (rippleCarryAdder n a b false).toNat = a.toNat + b.toNat
```

`rippleCarryAdder_correct` holds for every width `n`, every pair of inputs
and either carry in. `rippleCarryAdder_add` is the case with no carry in:
the output is the sum of the two inputs.

The proof is by induction on `n`, peeling off bit 0.

- `fullAdder_toNat` checks all 8 inputs: `sum + 2 * cout = a + b + cin`.
- `carry_succ` shows that above bit 0, the carry chain of an (n+1)-bit adder
  is the carry chain of an n-bit adder on bits 1 to n. That adder's carry in
  is the carry out of bit 0. It is proved by induction on the bit index.
- `sum_zero`, `sum_tail` and `cout_succ` follow. Bit 0 of the sum comes
  from the full adder at bit 0. The other sum bits and the carry out are
  those of the n-bit adder.
- The induction step combines `fullAdder_toNat` for bit 0 with the induction
  hypothesis for the n-bit adder, and `omega` does the arithmetic.

Both theorems use only Lean's standard axioms, `propext` and `Quot.sound`.

### The checks

The checks follow the testbench. `check` compares `{cout, sum}` with
`a + b + cin` as natural numbers. Each `#guard` fails compilation if it
fails:

- every input at the default width of 8 (131,072 cases), and at 1 and 2 bits;
- every pair of the testbench's seven corner values, with `cin` 0 and 1, at
  11, 32, 33, 64 and 100 bits.

There are no random tests. The proof covers every input anyway; the checks
also test `Bus.ofNat`, the conversion from numbers to buses.

## Running

Icarus Verilog:

```bash
iverilog -g2012 -o tb.vvp ripple_carry_adder.sv ripple_carry_adder_tb.sv
vvp -n tb.vvp
```

Verilator:

```bash
verilator --binary --top-module ripple_carry_adder_tb \
  ripple_carry_adder.sv ripple_carry_adder_tb.sv
obj_dir/Vripple_carry_adder_tb
```

To test another width, add `-Pripple_carry_adder_tb.N=32` to `iverilog` or
`-GN=32` to `verilator`.

Lint:

```bash
verilator --lint-only -Wall -Wno-DECLFILENAME --top-module ripple_carry_adder_tb \
  ripple_carry_adder.sv ripple_carry_adder_tb.sv
```

`-Wno-DECLFILENAME` is needed because `half_adder` and `full_adder` live in
a file named after `ripple_carry_adder`.

To check the SVA assertion during simulation, add `ripple_carry_adder_sva.sv`
to the Verilator command, and add `--assert`. Icarus Verilog doesn't support
`bind`, so leave the file out for Icarus.

Lean, from this directory so elan picks up `lean-toolchain`:

```bash
lean ripple_carry_adder.lean
```

It takes about 5 seconds. It prints `(true, 45)`, the carry out and sum of
200 + 100 + 1 at 8 bits.

## Results

Icarus Verilog 13.0 (devel) and Verilator 5.044 both pass at N = 1, 2, 8 and
10, every input, and at N = 11, 32, 33, 64 and 100, corner and random
inputs. Verilator `-Wall` (except `DECLFILENAME`) and slang 9.1 report no
warnings.

EBMC 6.1 proves the SVA assertion at N = 8, and at N = 1, 2, 16, 32, 64 and
128 through top modules like the one described above. Each proof takes about
a second. These runs used the WebAssembly build from the EBMC 6.1 release,
under Node.js. With the assertion bound in, Verilator `--assert` passes the
testbench at N = 1, 8, 10, 64 and 100, and slang and Verilator `-Wall`
report no warnings.

Three broken copies of the design check that the testbench and the SVA
assertion find bugs. Each one fails the testbench at N = 8 and N = 64. EBMC
refutes the assertion for each one and gives a counterexample:

| Change | Tests failed at N = 8 | EBMC counterexample, N = 8 |
|---|---|---|
| `full_adder`: `or` for the carry out becomes `and` | 122,324 of 131,072 | 9 + 1 + 0 gives `sum` 8, `cout` 0 |
| `half_adder`: `xor` for the sum becomes `or` | 121,230 of 131,072 | 192 + 183 + 0 gives `sum` 247, `cout` 1 |
| `ripple_carry_adder`: `cout` comes from `carry[N-1]`, not `carry[N]` | 32,768 of 131,072 | 64 + 64 + 0 gives `sum` 128, `cout` 1 |

With the first change, Verilator `--assert` also stops on the SVA assertion
at the first failing test.

`lean ripple_carry_adder.lean` passes with Lean v4.34.1, proof included.
Making the same three changes to the Lean model breaks the proof and all
eight `#guard`s. The two gate changes break `fullAdder_toNat`, and the
`carry[N-1]` change breaks `cout_succ`.
