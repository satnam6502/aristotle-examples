Formally verify the two SystemVerilog assertions in bsort_formal.sv.
bsort_formal is the top module. It instantiates bsort from bsort.sv, a
combinational bitonic sorter of 2**N elements of 8 bits each. Check the N
that the -G N option sets.

Prove both assertions for every value of the inputs in_data and v:

- assert_sorted: out_data is in non-decreasing order.
- assert_permutation: v occurs as often in out_data as in in_data. Since
  this holds for every v, out_data is a permutation of in_data.

Use exactly these conditions:

- The design has no clock, no reset and no state elements.
- in_data and v are unconstrained.
- There are no environment assumptions. Do not add assumptions and do not
  weaken, remove or edit any property.
- The ArrayUtils class in bsort.sv is not used by bsort or bsort_formal.

If a property is false, report a concrete counterexample and say whether
the defect is in the RTL or in the property.
