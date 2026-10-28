// Formal top for bsort. bsort is combinational, so there is no clock and
// every check covers all inputs at once.
module bsort_formal #(
    parameter int N = 3  // Sorts 2**N elements
) (
    input logic [7:0] in_data [2**N],
    // An unconstrained value. assert_permutation must hold for every v.
    input logic [7:0] v
);
    localparam int SIZE = 2**N;

    logic [7:0] out_data [SIZE];

    bsort #(.T(logic [7:0]), .N(N)) dut (
        .in_data(in_data),
        .out_data(out_data)
    );

    // sorted: out_data is in non-decreasing order.
    // count_in, count_out: how many times v occurs in each array.
    logic       sorted;
    logic [N:0] count_in;
    logic [N:0] count_out;

    always_comb begin
        sorted = 1'b1;
        for (int i = 0; i < SIZE - 1; i++)
            if (out_data[i] > out_data[i+1]) sorted = 1'b0;
        count_in  = (N+1)'(0);
        count_out = (N+1)'(0);
        for (int i = 0; i < SIZE; i++) begin
            count_in  = count_in  + (N+1)'(in_data[i]  == v);
            count_out = count_out + (N+1)'(out_data[i] == v);
        end
    end

    // One assertion per block, the only form Aristotle reads.
    always_comb begin
        assert_sorted: assert (sorted);
    end

    // Every value occurs as often in out_data as in in_data, so out_data is
    // a permutation of in_data.
    always_comb begin
        assert_permutation: assert (count_in == count_out);
    end

endmodule: bsort_formal

