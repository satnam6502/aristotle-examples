class ArrayUtils #(
    type T = logic [31:0], 
    int N = 8
);

    // Type Definitions
    typedef T input_array_t [N];
    localparam int HalfN = (N < 2) ? 1 : (N / 2);
    typedef T half_t        [HalfN];
    typedef half_t      split_t [2]; // Two-element array of halves

    // --- Halve Function ---
    static function split_t halve(input input_array_t in_arr);
        split_t result;
        for (int i = 0; i < N/2; i++) begin
            result[0][i] = in_arr[i];
            result[1][i] = in_arr[i + N/2];
        end
        return result;
    endfunction

    // --- Unhalve Function (Inverse) ---
    static function input_array_t unhalve(input split_t halves);
        input_array_t result;
        for (int i = 0; i < N/2; i++) begin
            result[i]       = halves[0][i];
            result[i + N/2] = halves[1][i];
        end
        return result;
    endfunction

    typedef T array_t [N];  

    // --- Reverse Function ---
    static function array_t reverse(input array_t in_arr);
        array_t result;
        for (int i = 0; i < N; i++) begin
            result[i] = in_arr[N - 1 - i];
        end
        return result;
    endfunction

    typedef T pair_t [2];

    // Returns a sorted two-element array [min, max]
    static function pair_t two_sorter(input pair_t in_arr);
        pair_t result;
        
        if (in_arr[0] <= in_arr[1]) begin
            result[0] = in_arr[0];
            result[1] = in_arr[1];
        end else begin
            result[0] = in_arr[1];
            result[1] = in_arr[0];
        end
        
        return result;
    endfunction

    typedef pair_t array_of_pairs_t [HalfN];

    // --- Pair Function ---
    // Maps [a, b, c, d] to [[a, b], [c, d]]
    static function array_of_pairs_t pair(input array_t in_arr);
        array_of_pairs_t result;

        if (N % 2 != 0) begin
            $error("Error: N must be even to create pairs.");
        end

        for (int i = 0; i < N/2; i++) begin
            result[i][0] = in_arr[2*i];
            result[i][1] = in_arr[2*i + 1];
        end
        
        return result;
    endfunction

     // --- Unpair Function ---
    // Maps [[1, 2], [3, 4]] back to [1, 2, 3, 4]
    static function input_array_t unpair(input array_of_pairs_t in_pairs);
        input_array_t result;
        for (int i = 0; i < N/2; i++) begin
            result[2*i]     = in_pairs[i][0];
            result[2*i + 1] = in_pairs[i][1];
        end
        return result;
    endfunction

    typedef pair_t output_zip_t [N];

    // --- Zip Function ---
    // Takes [ [a0, a1...], [b0, b1...] ] 
    // Returns [ [a0, b0], [a1, b1]... ]
    static function array_of_pairs_t zip(input split_t in_halves);
        array_of_pairs_t result;

        for (int i = 0; i < HalfN; i++) begin
            result[i][0] = in_halves[0][i];
            result[i][1] = in_halves[1][i];
        end
        
        return result;
    endfunction

    // --- Unzip Function ---
    // Takes [ [a0, b0], [a1, b1]... ]
    // Returns [ [a0, a1...], [b0, b1...] ]
    static function split_t unzip(input array_of_pairs_t in_pairs);
        split_t result;

        for (int i = 0; i < HalfN; i++) begin
            result[0][i] = in_pairs[i][0];
            result[1][i] = in_pairs[i][1];
        end
        
        return result;
    endfunction

    // --- Riffle Function ---
    // Interleaves the first and second halves of the array. A perfect shuffle.
    static function array_t riffle(input array_t in_arr);
        return unpair (zip (halve (in_arr)));
    endfunction

    // --- Unriffle Function ---
    // Reverses the riffle by de-interleaving the array
    static function array_t unriffle(input array_t in_arr);
        return unhalve (unzip (pair (in_arr)));
    endfunction


endclass: ArrayUtils

module butterfly #(
    parameter type T = logic[7:0],
    parameter int  N = 3  // Degree of the butterfly (Total elements = 2^N)
)(
    input  T in_data  [2**N],
    output T out_data [2**N]
);

    // Iterative bitonic merge: N stages of parallel compare-and-swap.
    // Stage s operates on blocks of size 2^(N-s) with compare distance 2^(N-s-1).
    localparam int TOTAL = 2**N;

    generate
        for (genvar s = 0; s < N; s++) begin : stage
            localparam int BLOCK = 1 << (N - s);
            localparam int HALF  = BLOCK >> 1;
            T data [TOTAL];

            for (genvar b = 0; b < TOTAL / BLOCK; b++) begin : blk
                for (genvar k = 0; k < HALF; k++) begin : cmp
                    localparam int LO = b * BLOCK + k;
                    localparam int HI = LO + HALF;
                    if (s == 0) begin : first
                        assign data[LO] = (in_data[LO] <= in_data[HI]) ? in_data[LO] : in_data[HI];
                        assign data[HI] = (in_data[LO] <= in_data[HI]) ? in_data[HI] : in_data[LO];
                    end else begin : chain
                        assign data[LO] = (stage[s-1].data[LO] <= stage[s-1].data[HI]) ? stage[s-1].data[LO] : stage[s-1].data[HI];
                        assign data[HI] = (stage[s-1].data[LO] <= stage[s-1].data[HI]) ? stage[s-1].data[HI] : stage[s-1].data[LO];
                    end
                end
            end
        end
    endgenerate

    assign out_data = stage[N-1].data;

endmodule: butterfly

module bsort #(
    parameter type T = logic[7:0],
    parameter int  N = 3
)(
    input  T in_data  [2**N],
    output T out_data [2**N]
);

    // Iterative bitonic sort: N*(N+1)/2 stages of parallel compare-and-swap.
    // Phase p (0..N-1) builds sorted runs of length 2^(p+1).
    // Sub-stage q (p..0) within each phase performs the merge at distance 2^q.
    // Direction alternates: ascending if bit (p+1) of element index is 0.
    localparam int TOTAL = 2**N;

    generate
        for (genvar p = 0; p < N; p++) begin : phase
            for (genvar q = p; q >= 0; q--) begin : sub
                localparam int D = 1 << q;
                T data [TOTAL];

                for (genvar i = 0; i < TOTAL; i++) begin : elem
                    localparam int J = i ^ D;
                    if (J > i) begin : pair
                        if (((i >> (p + 1)) & 1) == 0) begin : asc
                            if (p == 0 && q == 0) begin : s0
                                assign data[i] = (in_data[i] <= in_data[J]) ? in_data[i] : in_data[J];
                                assign data[J] = (in_data[i] <= in_data[J]) ? in_data[J] : in_data[i];
                            end else if (q == p) begin : ph
                                assign data[i] = (phase[p-1].sub[0].data[i] <= phase[p-1].sub[0].data[J]) ? phase[p-1].sub[0].data[i] : phase[p-1].sub[0].data[J];
                                assign data[J] = (phase[p-1].sub[0].data[i] <= phase[p-1].sub[0].data[J]) ? phase[p-1].sub[0].data[J] : phase[p-1].sub[0].data[i];
                            end else begin : ch
                                assign data[i] = (sub[q+1].data[i] <= sub[q+1].data[J]) ? sub[q+1].data[i] : sub[q+1].data[J];
                                assign data[J] = (sub[q+1].data[i] <= sub[q+1].data[J]) ? sub[q+1].data[J] : sub[q+1].data[i];
                            end
                        end else begin : desc
                            if (p == 0 && q == 0) begin : s0
                                assign data[i] = (in_data[i] >= in_data[J]) ? in_data[i] : in_data[J];
                                assign data[J] = (in_data[i] >= in_data[J]) ? in_data[J] : in_data[i];
                            end else if (q == p) begin : ph
                                assign data[i] = (phase[p-1].sub[0].data[i] >= phase[p-1].sub[0].data[J]) ? phase[p-1].sub[0].data[i] : phase[p-1].sub[0].data[J];
                                assign data[J] = (phase[p-1].sub[0].data[i] >= phase[p-1].sub[0].data[J]) ? phase[p-1].sub[0].data[J] : phase[p-1].sub[0].data[i];
                            end else begin : ch
                                assign data[i] = (sub[q+1].data[i] >= sub[q+1].data[J]) ? sub[q+1].data[i] : sub[q+1].data[J];
                                assign data[J] = (sub[q+1].data[i] >= sub[q+1].data[J]) ? sub[q+1].data[J] : sub[q+1].data[i];
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    assign out_data = phase[N-1].sub[0].data;

endmodule: bsort

