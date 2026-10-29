# 8-bit Gray-code counter in Lean

`GrayCode.lean` models a small synchronous circuit, an 8-bit Gray-code
counter, in plain Lean 4 with no Mathlib. It simulates the first 10 cycles
and checks the outputs.

## Files

| File | What it is |
|---|---|
| `GrayCode.lean` | The circuit model, the counter, a simulation and its checks |
| `lean-toolchain` | Pins Lean `v4.34.1` |

## The model

A wire is a map from clock cycle to the value it carries in that cycle:

```lean
abbrev Wire := Nat → BitVec 8
```

- **Gates.** `gate1` and `gate2` turn functions on `BitVec 8` into gates on
  wires. `xorGate`, `addGate` and `shr1` are built from them.
- **Register.** `reg init d` outputs `init` in cycle 0, then whatever `d`
  carried one cycle earlier.
- **Feedback.** Lean has no general fixpoint on wires. So `loopReg init f`
  builds a register whose input is its own output passed through `f`, one
  cycle at a time.

## The circuit

The counter is a binary counter followed by a binary-to-Gray encoder:

```
        +-----+     +-----+   count   +-----------+   gray
   +--->| inc |---->| reg |-----+---->| bin2gray  |------->
   |    +-----+     +-----+     |     +-----------+
   +----------------------------+
```

- `counter` is a register fed back through an incrementer.
- `bin2gray b` is `b ^^^ (b >>> 1)`.
- `grayCounter` is `bin2gray counter`.

## Running

```bash
lean GrayCode.lean
```

Run it from this directory so elan picks up `lean-toolchain`. Without the
pin, elan's default `stable` makes it look for a new toolchain over the
network, and `lean` can hang.

The output is the first 10 Gray codes, then a trace of each cycle:

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

## Checks

The file fails to compile if any of these fails.

- **Expected codes.** A `#guard` compares the first 10 outputs with a list
  written out by hand. The theorem `first10` proves the same equation with
  `decide`, so the kernel checks it.
- **One bit per step.** A second `#guard` checks that each of the 9 steps
  flips exactly one bit.
- **Feedback.** The theorem `loopReg_spec` proves that `loopReg` agrees with
  `reg` with its output fed back. It covers only feedback through a `gate1`
  gate. The counter's incrementer is written with `addGate`, which computes
  the same function.
