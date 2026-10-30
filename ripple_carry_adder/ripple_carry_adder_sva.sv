// SVA checker for ripple_carry_adder, bound into every instance of it. The
// adder has no clock, so the check is an immediate assertion in always_comb,
// not a concurrent property, which would need a clock. It must hold for every
// value of a, b and cin.
//
// The assertion is deferred (assert final): a simulator checks it at the end
// of the time step, after the gates settle. A plain immediate assertion runs
// as soon as an input changes, before sum and cout update, so an
// event-driven simulator reports false failures.

module ripple_carry_adder_sva #(parameter int N = 8)
                              (input wire [N-1:0] a,
                               input wire [N-1:0] b,
                               input wire         cin,
                               input wire [N-1:0] sum,
                               input wire         cout);
  // The output {cout, sum} is the (N+1)-bit sum of the inputs a, b and cin.
  always_comb begin
    assert_sum: assert final ({cout, sum} == (N+1)'(a) + (N+1)'(b) + (N+1)'(cin));
  end
endmodule: ripple_carry_adder_sva

// N and the signals come from the bound instance of ripple_carry_adder. The
// connections are by name, not .*, because EBMC 6.1 does not support .*.
bind ripple_carry_adder ripple_carry_adder_sva #(.N(N))
  u_sva (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
