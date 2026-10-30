// Testbench for ripple_carry_adder. It checks {cout, sum} against a + b + cin.
//
// If N <= EXHAUSTIVE_MAX_N it tries every input. Otherwise it tries corner
// cases (carries that ripple the full width, alternating bits) and then
// RANDOM_TESTS random inputs. It ends with PASS, or with $fatal on any error.

module ripple_carry_adder_tb;
  parameter int N = 8;
  parameter int EXHAUSTIVE_MAX_N = 10;
  parameter int RANDOM_TESTS = 100000;

  logic [N-1:0] a, b;
  logic         cin;
  wire  [N-1:0] sum;
  wire          cout;

  int tests  = 0;
  int errors = 0;

  ripple_carry_adder #(.N(N)) dut (
    .a(a), .b(b), .cin(cin), .sum(sum), .cout(cout)
  );

  // Apply one input, let the carry ripple, and compare with +. The !== also
  // catches X and Z outputs.
  task automatic check(input logic [N-1:0] ta, input logic [N-1:0] tb,
                       input logic tcin);
    logic [N:0] expected;
    a   = ta;
    b   = tb;
    cin = tcin;
    #1;
    expected = (N+1)'(ta) + (N+1)'(tb) + (N+1)'(tcin);
    tests++;
    if ({cout, sum} !== expected) begin
      errors++;
      if (errors <= 10)
        $display("FAIL: %0d + %0d + %0d gave %0d, expected %0d",
                 ta, tb, tcin, {cout, sum}, expected);
    end
  endtask

  // An N-bit random value, built 32 bits at a time.
  function automatic logic [N-1:0] random_word();
    logic [N-1:0] w = '0;
    repeat ((N + 31) / 32) w = N'({w, $urandom});
    return w;
  endfunction

  // 0101...01, alternating bits with bit 0 set.
  function automatic logic [N-1:0] alternating();
    logic [N-1:0] w;
    for (int i = 0; i < N; i++) w[i] = (i % 2 == 0);
    return w;
  endfunction

  logic [N-1:0] corners[7];

  initial begin
    if (N <= EXHAUSTIVE_MAX_N) begin
      for (int i = 0; i < (1 << N); i++)
        for (int j = 0; j < (1 << N); j++)
          for (int c = 0; c < 2; c++)
            check(N'(i), N'(j), 1'(c));
    end else begin
      corners = '{'0, N'(1), '1, '1 >> 1, ~('1 >> 1),
                  alternating(), ~alternating()};
      foreach (corners[i])
        foreach (corners[j])
          for (int c = 0; c < 2; c++)
            check(corners[i], corners[j], 1'(c));
      repeat (RANDOM_TESTS)
        check(random_word(), random_word(), 1'($urandom));
    end

    if (errors != 0)
      $fatal(1, "FAIL: %0d of %0d tests failed for N = %0d", errors, tests, N);
    $display("PASS: %0d tests for N = %0d", tests, N);
    $finish;
  end
endmodule
