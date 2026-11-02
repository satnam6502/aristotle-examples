// A parameterized semi-systolic FIR filter, after the Lava example at
// https://raintown.org/lava/fir.html. The x samples move left to right
// through a register in each processing element. The accumulated sums move
// right to left with no registers, so the critical path goes through every
// processing element. That is what makes the filter semi-systolic.
//
// y[t] = WEIGHTS[0]*x[t-1] + WEIGHTS[1]*x[t-2] + ... + WEIGHTS[N-1]*x[t-N]

// xout = x delayed by one cycle, yout = y + A * xout
module pe #(parameter int INPUT_WIDTH  = 8,
            parameter int WEIGHT_WIDTH = 4,
            parameter int Y_WIDTH      = INPUT_WIDTH + WEIGHT_WIDTH,
            parameter logic [WEIGHT_WIDTH-1:0] A = 1)
           (input  logic                   clk,
            input  logic                   rst,
            input  logic [INPUT_WIDTH-1:0] x,
            input  logic [Y_WIDTH-1:0]     y,
            output logic [INPUT_WIDTH-1:0] xout,
            output logic [Y_WIDTH-1:0]     yout);
  always_ff @(posedge clk)
    if (rst) xout <= '0;
    else     xout <= x;

  // A constant coefficient multiplier and an adder, both unsigned. The sum
  // wraps if it doesn't fit in Y_WIDTH bits.
  assign yout = y + Y_WIDTH'(A) * Y_WIDTH'(xout);
endmodule: pe

// y = sum of WEIGHTS[k] * x[t-1-k] for k = 0 .. N-1. The default weights are
// the ones in the Lava example. rst is synchronous and clears every tap.
// To change N, override WEIGHTS with a typed localparam. Verilator 5.044
// checks an inline '{...} override against the default N and WEIGHT_WIDTH,
// though 5.054 doesn't.
module semisystolic_filter
  #(parameter int N            = 5,
    parameter int INPUT_WIDTH  = 8,
    parameter int WEIGHT_WIDTH = 4,
    parameter logic [WEIGHT_WIDTH-1:0] WEIGHTS [N] = '{3, 9, 15, 7, 5},
    // Wide enough that the sum of N products can't overflow.
    localparam int Y_WIDTH = INPUT_WIDTH + WEIGHT_WIDTH + $clog2(N))
   (input  logic                   clk,
    input  logic                   rst,
    input  logic [INPUT_WIDTH-1:0] x,
    output logic [Y_WIDTH-1:0]     y);
  // xs[i] is the x input of pe i and ys[i] is its yout. ys[N] is the y input
  // of the rightmost pe. xs[N], the xout of the rightmost pe, isn't used.
  logic [INPUT_WIDTH-1:0] xs [N+1];
  logic [Y_WIDTH-1:0]     ys [N+1];

  assign xs[0] = x;
  assign ys[N] = '0;
  assign y     = ys[0];

  generate
    for (genvar i = 0; i < N; i++) begin : g_pe
      pe #(.INPUT_WIDTH(INPUT_WIDTH), .WEIGHT_WIDTH(WEIGHT_WIDTH),
           .Y_WIDTH(Y_WIDTH), .A(WEIGHTS[i]))
        u_pe (.clk(clk), .rst(rst), .x(xs[i]), .y(ys[i+1]),
              .xout(xs[i+1]), .yout(ys[i]));
    end: g_pe
  endgenerate
endmodule: semisystolic_filter
