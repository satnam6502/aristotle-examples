// Testbench for semisystolic_filter. Each filter_check drives one
// configuration of the filter, and of semisystolic_filter_spec with the same
// parameters, and checks that their outputs match every cycle. The samples
// are random, with bursts of all-ones samples that drive the sum to its
// maximum. In the default configuration it also checks the spec against the
// trace on the Lava page. The taps start full of junk and are reset again
// halfway through, so rst has to clear every tap. It ends with PASS, or with
// $fatal on any error.
//
// The configurations that change N override WEIGHTS with typed localparams,
// since Verilator 5.044 (but not 5.054) checks an inline '{...} override
// against the default N and WEIGHT_WIDTH. Icarus Verilog 13 can't run this
// testbench because it doesn't support unpacked array parameters.

module filter_check
  #(parameter int N            = 5,
    parameter int INPUT_WIDTH  = 8,
    parameter int WEIGHT_WIDTH = 4,
    parameter logic [WEIGHT_WIDTH-1:0] WEIGHTS [N] = '{3, 9, 15, 7, 5},
    parameter int CYCLES       = 10000,
    parameter bit LAVA_TRACE   = 0,  // Only for the default configuration
    parameter string NAME      = "")
   (input  logic clk,
    output logic done,
    output int   errors);
  localparam int Y_WIDTH = INPUT_WIDTH + WEIGHT_WIDTH + $clog2(N);

  // The first ten sine samples and filter outputs on the Lava page.
  localparam int unsigned LAVA_X [10] = '{0, 9, 18, 26, 35, 43, 52, 60, 67, 75};
  localparam int unsigned LAVA_Y [10] =
    '{0, 0, 27, 135, 375, 672, 1005, 1340, 1668, 1997};

  logic                   rst;
  logic [INPUT_WIDTH-1:0] x;
  logic [Y_WIDTH-1:0]     y, y_spec;

  semisystolic_filter #(.N(N), .INPUT_WIDTH(INPUT_WIDTH),
                        .WEIGHT_WIDTH(WEIGHT_WIDTH), .WEIGHTS(WEIGHTS))
    dut (.clk(clk), .rst(rst), .x(x), .y(y));

  semisystolic_filter_spec #(.N(N), .INPUT_WIDTH(INPUT_WIDTH),
                             .WEIGHT_WIDTH(WEIGHT_WIDTH), .WEIGHTS(WEIGHTS))
    spec (.clk(clk), .rst(rst), .x(x), .y(y_spec));

  int checks;

  // One cycle of synchronous reset. Call it just after a clock edge.
  task automatic reset();
    rst = 1;
    @(posedge clk);
    #1 rst = 0;
  endtask

  // Drive one sample, compare y with the spec, and clock the sample in. x
  // changes just after an edge, so neither filter samples it in the same
  // time step.
  task automatic step(input logic [INPUT_WIDTH-1:0] sample, input int t);
    x = sample;
    #1;
    checks++;
    if (y !== y_spec) begin
      errors++;
      if (errors <= 10)
        $display("FAIL: %s: cycle %0d gave y = %0d, the spec gives %0d",
                 NAME, t, y, y_spec);
    end
    if (LAVA_TRACE && t < 10 && y_spec !== Y_WIDTH'(LAVA_Y[t])) begin
      errors++;
      $display("FAIL: %s: cycle %0d, the spec gives y = %0d, the Lava page says %0d",
               NAME, t, y_spec, LAVA_Y[t]);
    end
    @(posedge clk);
    #1;
  endtask

  initial begin
    done   = 0;
    errors = 0;
    checks = 0;
    rst = 0;
    x   = '1;
    repeat (N + 1) @(posedge clk);
    #1 reset();
    for (int t = 0; t < CYCLES; t++) begin
      if (t == CYCLES / 2) reset();
      if (LAVA_TRACE && t < 10) step(INPUT_WIDTH'(LAVA_X[t]), t);
      else if (t % 64 < N + 2)  step('1, t);
      else                      step(INPUT_WIDTH'({$urandom, $urandom}), t);
    end
    $display("%s: N = %0d, INPUT_WIDTH = %0d, WEIGHT_WIDTH = %0d: %0d checks, %0d errors",
             NAME, N, INPUT_WIDTH, WEIGHT_WIDTH, checks, errors);
    done = 1;
  end
endmodule

module semisystolic_filter_tb;
  parameter int CYCLES = 10000;

  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Weights that give the largest sum for their N.
  localparam logic [3:0] W1 [1] = '{15};
  localparam logic [3:0] W2 [2] = '{15, 15};
  localparam logic [3:0] W8 [8] = '{15, 15, 15, 15, 15, 15, 15, 15};
  // Weights for N = 9, where $clog2(N) rounds up, and for wider samples and
  // weights.
  localparam logic [3:0]  W9  [9] = '{1, 2, 3, 4, 5, 6, 7, 8, 15};
  localparam logic [7:0]  W3  [3] = '{255, 0, 129};
  localparam logic [11:0] W4  [4] = '{4095, 1, 2048, 4095};

  logic [6:0] done;
  int         errors [7];
  int         total;

  filter_check #(.CYCLES(CYCLES), .LAVA_TRACE(1), .NAME("default"))
    c_default (.clk(clk), .done(done[0]), .errors(errors[0]));
  filter_check #(.N(1), .WEIGHTS(W1), .CYCLES(CYCLES), .NAME("n1"))
    c_n1 (.clk(clk), .done(done[1]), .errors(errors[1]));
  filter_check #(.N(2), .WEIGHTS(W2), .CYCLES(CYCLES), .NAME("n2"))
    c_n2 (.clk(clk), .done(done[2]), .errors(errors[2]));
  filter_check #(.N(8), .WEIGHTS(W8), .CYCLES(CYCLES), .NAME("n8"))
    c_n8 (.clk(clk), .done(done[3]), .errors(errors[3]));
  filter_check #(.N(9), .WEIGHTS(W9), .CYCLES(CYCLES), .NAME("n9"))
    c_n9 (.clk(clk), .done(done[4]), .errors(errors[4]));
  filter_check #(.N(3), .INPUT_WIDTH(16), .WEIGHT_WIDTH(8), .WEIGHTS(W3),
                 .CYCLES(CYCLES), .NAME("in16_w8"))
    c_in16_w8 (.clk(clk), .done(done[5]), .errors(errors[5]));
  filter_check #(.N(4), .INPUT_WIDTH(40), .WEIGHT_WIDTH(12), .WEIGHTS(W4),
                 .CYCLES(CYCLES), .NAME("in40_w12"))
    c_in40_w12 (.clk(clk), .done(done[6]), .errors(errors[6]));

  initial begin
    wait (&done);
    total = 0;
    foreach (errors[i]) total += errors[i];
    if (total != 0)
      $fatal(1, "FAIL: %0d errors", total);
    $display("PASS: %0d cycles for each of %0d configurations", CYCLES, $bits(done));
    $finish;
  end
endmodule
