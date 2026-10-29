# 8-bit Gray-code counter in Lean

`GrayCode.lean` models a small synchronous circuit, an 8-bit Gray-code
counter, in plain Lean 4 with no Mathlib. It simulates the first 10 cycles,
checks the outputs, and proves the counter correct for every cycle.

## Files

| File | What it is |
|---|---|
| `GrayCode.lean` | The circuit model, the counter, a simulation, its checks and proofs |
| `lean-toolchain` | Pins Lean `v4.34.1` |
| `README.md` | This file |
| `../.github/workflows/gray-code-lean.yml` | CI: compiles `GrayCode.lean` when a pull request or a push to main changes this directory |

## The model

A wire is a map from clock cycle to the value it carries in that cycle:

```lean
abbrev Wire := Nat → BitVec 8
```

- **Gates.** `gate1` and `gate2` turn functions on `BitVec 8` into gates on
  wires. `xorGate` and `shr1` are built from them.
- **Register.** `reg init d` outputs `init` in cycle 0, then whatever `d`
  carried one cycle earlier.
- **Feedback.** Lean has no general fixpoint on wires. So `loopReg init f`
  builds a register whose input is its own output passed through `f`, one
  cycle at a time. `f` has type `BitVec 8 → BitVec 8`, not `Wire → Wire`,
  so the loop body can only be combinational logic.

## The circuit

The counter is a binary counter followed by a binary-to-Gray encoder:

```
        +-----+     +-----+   count   +-----------+   gray
   +--->| inc |---->| reg |-----+---->| bin2gray  |------->
   |    +-----+     +-----+     |     +-----------+
   +----------------------------+
```

- `counter` is `loopReg 0 inc`, a register fed back through the incrementer
  `inc b = b + 1`.
- `bin2gray` is built from an XOR gate and a shift-right gate. Each cycle it
  computes `gray b = b ^^^ (b >>> 1)`.
- `grayCounter` is `bin2gray counter`.

## Running

```bash
lean GrayCode.lean
```

Run it from this directory so elan picks up `lean-toolchain`. Without the
pin, elan's default `stable` makes it look for a new toolchain over the
network, and `lean` can hang.

It takes a few seconds. The output is the first 10 Gray codes, then a trace
of each cycle:

```
[0, 1, 3, 2, 6, 7, 5, 4, 12, 13]
cycle 0:  count 00000000  gray 00000000
cycle 1:  count 00000001  gray 00000001
cycle 2:  count 00000010  gray 00000011
cycle 3:  count 00000011  gray 00000010
cycle 4:  count 00000100  gray 00000110
cycle 5:  count 00000101  gray 00000111
cycle 6:  count 00000110  gray 00000101
cycle 7:  count 00000111  gray 00000100
cycle 8:  count 00001000  gray 00001100
cycle 9:  count 00001001  gray 00001101
```

Each value on a wire is recomputed from cycle 0, so simulating n cycles takes
O(n²) steps. That is fine for short traces.

## Checks

The file fails to compile if any of these fails. The theorems use only Lean's
standard axioms, `propext` and `Quot.sound`.

- **Expected codes.** A `#guard` compares the first 10 outputs with a list
  written out by hand. The theorem `first10` proves the same equation with
  `decide`, so the kernel checks it.
- **Wraparound.** A `#guard` checks that cycle 255 outputs `10000000` and
  cycle 256 outputs `00000000`.
- **Feedback.** `loopReg_spec` proves that `loopReg init f` equals
  `reg init (gate1 f (loopReg init f))`, for every `init` and `f`.
- **Counter.** `counter_eq` proves that cycle `t` of `counter` holds `t`
  modulo 256. `grayCounter_eq` proves that cycle `t` of `grayCounter` holds
  `gray` of that value.
- **One bit per step.** `gray_oneBitApart` proves by `decide`, over all 256
  values of `b`, that `gray b` and `gray (b + 1)` differ in exactly one bit.
  The case `b = 255` is the wrap to 0. `grayCounter_oneBitApart` follows: in
  every cycle, the next output differs from the current one in exactly one
  bit.
