// A behavioral specification of semisystolic_filter, after the Haskell
// model semisystolicFIR at https://raintown.org/lava/fir.html. It keeps the
// last N samples in a shift register and sums their products with the
// weights directly, with no processing elements. It has the same parameters
// and ports as semisystolic_filter, so a testbench or an SVA property can
// compare the two outputs.
//
// y[t] = WEIGHTS[0]*x[t-1] + WEIGHTS[1]*x[t-2] + ... + WEIGHTS[N-1]*x[t-N]

module semisystolic_filter_spec
  #(parameter int N            = 5,
    parameter int INPUT_WIDTH  = 8,
    parameter int WEIGHT_WIDTH = 4,
    parameter logic [WEIGHT_WIDTH-1:0] WEIGHTS [N] = '{3, 9, 15, 7, 5},
    // Each product is less than 2**(INPUT_WIDTH + WEIGHT_WIDTH), so the sum
    // of N of them can't overflow.
    localparam int Y_WIDTH = INPUT_WIDTH + WEIGHT_WIDTH + $clog2(N))
   (input  logic                   clk,
    input  logic                   rst,
    input  logic [INPUT_WIDTH-1:0] x,
    output logic [Y_WIDTH-1:0]     y);
  // xs[k] is x[t-1-k], the last N samples with the newest first. These are
  // xvals in the Haskell model, and each cycle shifts in x as in
  // xin : init xvals. rst is synchronous and clears every sample.
  logic [INPUT_WIDTH-1:0] xs [N];

  always_ff @(posedge clk)
    if (rst) begin
      foreach (xs[k]) xs[k] <= '0;
    end else begin
      xs[0] <= x;
      for (int k = 1; k < N; k++) xs[k] <= xs[k-1];
    end

  // sum [w * x | (w, x) <- zip weights xvals]
  always_comb begin
    y = '0;
    foreach (xs[k]) y += Y_WIDTH'(WEIGHTS[k]) * Y_WIDTH'(xs[k]);
  end
endmodule: semisystolic_filter_spec
