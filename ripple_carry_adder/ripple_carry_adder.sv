// A parameterized N-bit ripple-carry adder, written structurally: gate
// primitives make a half adder, two half adders and an OR gate make a full
// adder, and a generate loop chains N full adders through their carries.

// sum = a ^ b, carry = a & b
module half_adder (input  wire a,
                   input  wire b,
                   output wire sum,
                   output wire carry);
  xor g_sum   (sum, a, b);
  and g_carry (carry, a, b);
endmodule: half_adder

// sum = a ^ b ^ cin, cout = majority(a, b, cin)
module full_adder (input  wire a,
                   input  wire b,
                   input  wire cin,
                   output wire sum,
                   output wire cout);
  wire s1, c1, c2;
  half_adder ha1 (.a(a),  .b(b),   .sum(s1),  .carry(c1));
  half_adder ha2 (.a(s1), .b(cin), .sum(sum), .carry(c2));
  or g_cout (cout, c1, c2);
endmodule: full_adder

// {cout, sum} = a + b + cin
module ripple_carry_adder #(parameter int N = 8)
                           (input  wire [N-1:0] a,
                            input  wire [N-1:0] b,
                            input  wire         cin,
                            output wire [N-1:0] sum,
                            output wire         cout);
  // carry[i] is the carry into bit i. carry[N] is the carry out.
  wire [N:0] carry;
  buf g_cin  (carry[0], cin);
  buf g_cout (cout, carry[N]);

  generate
    for (genvar i = 0; i < N; i++) begin : g_bit
      full_adder fa (.a(a[i]), .b(b[i]), .cin(carry[i]),
                     .sum(sum[i]), .cout(carry[i+1]));
    end: g_bit
  endgenerate
endmodule: ripple_carry_adder
