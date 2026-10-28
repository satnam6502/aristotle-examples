module bsort_tb;

    localparam int N = 3;
    localparam int SIZE = 2**N;

    logic [7:0] in_data [SIZE];
    logic [7:0] out_data [SIZE];

    bsort #(.T(logic [7:0]), .N(N)) bsort_inst (
        .in_data(in_data),
        .out_data(out_data)
    );

    function automatic bit is_sorted(logic [7:0] arr [SIZE]);
        for (int i = 0; i < SIZE - 1; i++)
            if (arr[i] > arr[i+1]) return 0;
        return 1;
    endfunction

    function automatic bit is_permutation(logic [7:0] a [SIZE], logic [7:0] b [SIZE]);
        logic [7:0] sa [SIZE];
        logic [7:0] sb [SIZE];
        sa = a; sb = b;
        // Bubble sort both copies, then compare
        for (int i = 0; i < SIZE; i++)
            for (int j = i+1; j < SIZE; j++) begin
                if (sa[i] > sa[j]) begin automatic logic [7:0] t = sa[i]; sa[i] = sa[j]; sa[j] = t; end
                if (sb[i] > sb[j]) begin automatic logic [7:0] t = sb[i]; sb[i] = sb[j]; sb[j] = t; end
            end
        for (int i = 0; i < SIZE; i++)
            if (sa[i] !== sb[i]) return 0;
        return 1;
    endfunction

    task automatic print_array(string label, logic [7:0] arr [SIZE]);
        $write("%s: [", label);
        for (int i = 0; i < SIZE; i++) begin
            if (i > 0) $write(", ");
            $write("%0d", arr[i]);
        end
        $display("]");
    endtask

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(string name);
        #1;
        print_array({name, " in "}, in_data);
        print_array({name, " out"}, out_data);
        if (!is_sorted(out_data)) begin
            $display("  FAIL: output is not sorted");
            fail_count++;
        end else if (!is_permutation(in_data, out_data)) begin
            $display("  FAIL: output is not a permutation of input");
            fail_count++;
        end else begin
            $display("  PASS");
            pass_count++;
        end
    endtask

    initial begin
        // Test 1: Reverse sorted
        in_data = '{8, 7, 6, 5, 4, 3, 2, 1};
        check("reverse    ");

        // Test 2: Already sorted
        in_data = '{1, 2, 3, 4, 5, 6, 7, 8};
        check("sorted     ");

        // Test 3: All identical
        in_data = '{42, 42, 42, 42, 42, 42, 42, 42};
        check("identical  ");

        // Test 4: Two distinct values
        in_data = '{1, 0, 1, 0, 1, 0, 1, 0};
        check("two-valued ");

        // Test 5: Single element differs
        in_data = '{5, 5, 5, 5, 5, 5, 5, 99};
        check("one-differ ");

        // Test 6: Arbitrary
        in_data = '{200, 3, 55, 128, 0, 255, 17, 42};
        check("arbitrary  ");

        // Test 7: Another arbitrary
        in_data = '{10, 90, 30, 70, 50, 50, 20, 80};
        check("arbitrary2 ");

        // Test 8-17: Pseudorandom (LFSR-style)
        begin
            logic [7:0] seed = 8'hA5;
            for (int t = 0; t < 10; t++) begin
                for (int i = 0; i < SIZE; i++) begin
                    seed = {seed[6:0], seed[7] ^ seed[5] ^ seed[4] ^ seed[3]};
                    in_data[i] = seed;
                end
                check($sformatf("random[%0d]  ", t));
            end
        end

        $display("---------------------------");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count > 0) $fatal(1, "SOME TESTS FAILED");
        else $display("ALL TESTS PASSED");
        $finish;
    end

endmodule: bsort_tb
