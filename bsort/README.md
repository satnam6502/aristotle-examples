# Bitonic sorter: sorted and permutation, checked by SBY, EBMC and Aristotle

`bsort.sv` is a combinational bitonic sorter of 2**N elements of 8 bits. This
experiment states two SVA properties of it and checks them with SymbiYosys
(SBY), EBMC and Aristotle, for N = 2 to 8.

All three tools agree wherever they finish. Aristotle proves both properties
at every size. SBY and EBMC prove them only for small N, then run out of time.

## Files

| File | What it is |
|---|---|
| `bsort.sv` | The design: `bsort #(T, N)`, a `butterfly` module and an unused `ArrayUtils` class |
| `bsorter_tb.sv` | Simulation testbench for N = 3 |
| `bsort.eqy` | Equivalence check. Its gate file, `bsort_verific_rtl_tv.sv`, is not here |
| `bsort_formal.sv` | Formal top. It instantiates `bsort` and holds the two assertions |
| `bsort_formal.f` | Filelist for the formal top |
| `bsort.sby.in` | SBY template, one task per assertion |
| `PROMPT.md` | The prompt for Aristotle |
| `Makefile` | Lint, SBY, EBMC and Aristotle targets |

## Properties

`bsort_formal.sv` holds two immediate assertions over `out_data`, the
sorter's output.

- `assert_sorted`: `out_data` is in non-decreasing order.
- `assert_permutation`: a value `v` occurs as often in `out_data` as in
  `in_data`.

`v` is a free input of `bsort_formal`. The tools must prove
`assert_permutation` for every `v`, so `out_data` is a permutation of
`in_data`. There are no assumptions, no clock and no state. Each check covers
every input at once.

The properties live in a separate formal top, not in `bsort.sv`, for one
reason: the permutation check needs the free input `v`.

## Running

```bash
make lint N=5                 # Verilator, --Wall
make sby N=4                  # both assertions with SBY
make ebmc N=4                 # both assertions with EBMC
make proof N=4                # both of the above
make -j3 -k sby-all           # every size; three SBY licences, so -j3
make -j -k ebmc-all           # every size; EBMC has no licence limit
make aristotle N=6            # a paid Aristotle run, saved in build/
make aristotle-dry-run N=6    # what would be uploaded
```

`SIZES`, `SBY_TIMEOUT` and `EBMC_TIMEOUT` override the defaults: N = 2 to 8,
and 3600 s per job.

## Results

Each SBY and EBMC job checks one assertion at one size, with a 3600 s
timeout. Times are wall-clock seconds. The SBY jobs ran three at a time and
the EBMC jobs fourteen at a time, on an 88-core machine.

| N | Elements | SBY sorted | SBY permutation | EBMC sorted | EBMC permutation |
|---|---|---|---|---|---|
| 2 | 4 | proved, 1 s | proved, 1 s | proved, 0.09 s | proved, 0.16 s |
| 3 | 8 | proved, 13 s | proved, 614 s | proved, 1.5 s | proved, 128 s |
| 4 | 16 | proved, 3034 s | timeout | proved, 148 s | timeout |
| 5 | 32 | timeout | timeout | timeout | timeout |
| 6 | 64 | timeout | timeout | timeout | timeout |
| 7 | 128 | timeout | timeout | timeout | timeout |
| 8 | 256 | timeout | timeout | timeout | timeout |

No job found a counterexample. A timeout is no verdict either way.

These runs used `bsort_formal.sv` with both assertions in one `always_comb`
block. After the split described below, N = 2 and N = 3 were checked again
with both tools and both assertions. All eight results still hold.

### Mutation check

Two broken copies of `bsort.sv` show each assertion catches a bug the other
misses. Both runs are at N = 2, and SBY and EBMC agree on every result.

| Change to the first compare-and-swap (`bsort.sv:198-199`) | `assert_sorted` | `assert_permutation` |
|---|---|---|
| `<=` becomes `>=`, so it sorts the wrong way | fails | holds |
| The maximum output always takes `in_data[J]`, so a value can be lost | holds | fails |

All 14 Aristotle properties are proved and machine-checked, with no
assumptions. Times run from project creation to the end of the run. All seven
runs were submitted together.

| N | Elements | `assert_sorted` | `assert_permutation` | Time | Project |
|---|---|---|---|---|---|
| 2 | 4 | proved | proved | 19 min 42 s | [0d902db1](https://aristotle.harmonic.fun/projects/0d902db1-e0d4-4498-9660-ea15aa9ad011) |
| 3 | 8 | proved | proved | 23 min 49 s | [836adc15](https://aristotle.harmonic.fun/projects/836adc15-233a-4918-8e2e-5c7ea4dded45) |
| 4 | 16 | proved | proved | 44 min 32 s | [442443bc](https://aristotle.harmonic.fun/projects/442443bc-57cf-44c5-b9dc-4682db0a3e3e) |
| 5 | 32 | proved | proved | 27 min 13 s | [46d63f9e](https://aristotle.harmonic.fun/projects/46d63f9e-7ce1-4a06-815f-6971f7e9db7b) |
| 6 | 64 | proved | proved | 34 min 07 s | [953aec27](https://aristotle.harmonic.fun/projects/953aec27-6f0c-4f67-a100-3311a4d274e6) |
| 7 | 128 | proved | proved | 37 min 24 s | [a77821e9](https://aristotle.harmonic.fun/projects/a77821e9-b699-4cd8-bfcc-8ffa25acc315) |
| 8 | 256 | proved | proved | 41 min 39 s | [cecd977b](https://aristotle.harmonic.fun/projects/cecd977b-91e8-4662-9a36-e56a745626ae) |

### How Aristotle proves them

The model checkers search the input space. Aristotle reasons about the
network instead, so its time grows slowly with N.

- **Sorted.** It shows `bsort` computes the standard bitonic network. It
  then applies the 0-1 principle: a compare-and-swap network sorts every
  input if it sorts every 0/1 input. The 0/1 case follows by induction over
  the merge phases.
- **Permutation.** Each compare-and-swap passes its two values through or
  swaps them. So each stage keeps the count of `v`, and so does the network.
  The N+1-bit counters cannot overflow.
- **Trust.** Every run reports its proofs as fully machine-checked. The N = 6
  run checks each merge phase on 64-bit 0/1 vectors with "the checker's own
  trusted bit-level evaluation". That step trusts more than Lean's kernel.
  The N = 7 run states it uses only Lean's standard axioms.

Every run asked one question. Aristotle only reads an immediate assertion that
is alone in its `always_comb` block, and the two assertions shared one. Six
runs split the block in Aristotle's copy, keeping each label and expression.
The N = 5 run kept the file as it was and stated the two checks by hand,
exactly as the assertions read. Either way, the statement is the assertion.
`bsort_formal.sv` now has one assertion per block, so a new run won't ask.

## Tool findings

- **EBMC can't read `bsort.sv`.** EBMC 6.1 rejects the `ArrayUtils` class
  ("unknown identifier N"). It loops forever on the `genvar q` that counts
  down past 0. It also rejects references into generate blocks, such as
  `phase[p-1].sub[0].data` ("unknown identifier"). So EBMC reads a netlist
  of `bsort_formal`, assertions included, that Verific writes. The Makefile
  checks the netlist has no flip-flops or latches. With no state, EBMC's
  "PROVED up to bound 0" is a complete proof.
- **EBMC `--aig` gives a false counterexample.** On the N = 3 permutation
  netlist, `--aig --cadical` reports REFUTED with `v` = 127. The input holds
  127 four times and so does the output, but EBMC's trace says `count_in` is
  3. The default word-level path proves the same netlist. The Makefile uses
  `--cadical` without `--aig`.
- **Permutation is the hard property for the model checkers.** At N = 3,
  `assert_sorted` takes 1.5 s in EBMC and `assert_permutation` 128 s. Counting
  through the network defeats the SAT solvers sooner than ordering does.
- **SBY engines.** On both assertions at N = 3, `smtbmc boolector` took
  284 s and `smtbmc bitwuzla` 329 s. `smtbmc yices` and `abc pdr` didn't
  finish in 900 s.
- **SBY hangs after a timeout.** All nine timed-out jobs printed
  `DONE (TIMEOUT, rc=8)`, but the `sby` process didn't exit. Each one held a
  `-j3` slot until it was stopped with SIGTERM, two by hand and seven by a
  watcher script. Their status files and logs were already written.
- **The testbench doesn't build with Verilator 5.052.** `verilator --binary`
  stops on an IMPLICITSTATIC warning at `bsorter_tb.sv:94`.
