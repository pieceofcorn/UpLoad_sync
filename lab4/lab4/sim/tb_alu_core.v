`timescale 1ns/1ps
// Verilog-2001 self-checking testbench. Compile the six rtl/core modules with this testbench.
// No board files, vendor primitives, external vectors or SystemVerilog needed.
module tb_alu_core;
    reg [3:0] clu_p, clu_g;
    reg clu_c0;
    wire [4:1] clu_c;
    wire clu_gg, clu_pg;
    clu4 dut_clu (
        .P(clu_p), .G(clu_g), .C0(clu_c0),
        .C(clu_c), .Gg(clu_gg), .Pg(clu_pg)
    );

    reg [3:0] a4, b4;
    reg cin4;
    wire [3:0] s4;
    wire cout4, gg4, pg4;
    cla4 dut_cla4 (
        .A(a4), .B(b4), .C0(cin4), .S(s4),
        .C4(cout4), .Gg(gg4), .Pg(pg4)
    );

    reg [15:0] a16, b16;
    reg cin16;
    wire [15:0] s16;
    wire cout16, gg16, pg16;
    cla16 dut_cla16 (
        .A(a16), .B(b16), .C0(cin16), .S(s16),
        .C16(cout16), .Gg(gg16), .Pg(pg16)
    );

    reg [31:0] arithmetic_a, arithmetic_b;
    reg arithmetic_sub;
    wire [31:0] arithmetic_f;
    wire arithmetic_cf, arithmetic_of, arithmetic_sf, arithmetic_zf;
    addsub32 dut_addsub32 (
        .A(arithmetic_a), .B(arithmetic_b), .SUB(arithmetic_sub),
        .F(arithmetic_f), .CF(arithmetic_cf), .OF(arithmetic_of),
        .SF(arithmetic_sf), .ZF(arithmetic_zf)
    );

    reg [31:0] a, b;
    reg [3:0] control;
    wire [31:0] result;
    wire zero;
    alu_core dut_core (
        .A(a), .B(b), .ALUctr(control), .RESULT(result), .ZERO(zero)
    );
    wire [31:0] debug_result, debug_f;
    wire debug_zero, cf, of_flag, sf, zf, flags_valid;
    alu_datapath dut_datapath (
        .A(a), .B(b), .ALUctr(control),
        .RESULT(debug_result), .ZERO(debug_zero), .debugF(debug_f),
        .CF(cf), .OF(of_flag), .SF(sf), .ZF(zf), .FLAGS_VALID(flags_valid)
    );

    integer checks;
    integer failures;
    integer status_file;
    integer case_number;
    integer i;
    integer j;
    reg [31:0] seed;
    reg [31:0] sample_a, sample_b;
    reg [3:0] sample_control;
    reg [4:0] expected_carry;
    reg [4:0] generate_carry;
    reg [4:0] expected5;
    reg [4:0] no_cin5;

    // A deterministic PRNG avoids simulator-specific $random sequences.
    function [31:0] next_seed;
        input [31:0] state;
        begin
            next_seed = state * 32'd1664525 + 32'd1013904223;
        end
    endfunction

    // Independent overflow oracle: sign-extend and compute in 64 bits,
    // then ask whether the mathematical answer fits signed 32 bits.
    function golden_overflow;
        input [31:0] lhs;
        input [31:0] rhs;
        input subtract;
        reg signed [63:0] signed_lhs;
        reg signed [63:0] signed_rhs;
        reg signed [63:0] mathematical_result;
        begin
            signed_lhs = {{32{lhs[31]}}, lhs};
            signed_rhs = {{32{rhs[31]}}, rhs};
            if (subtract)
                mathematical_result = signed_lhs - signed_rhs;
            else
                mathematical_result = signed_lhs + signed_rhs;
            golden_overflow = (mathematical_result > 64'sd2147483647)
                            || (mathematical_result < -64'sd2147483648);
        end
    endfunction

    function golden_signed_less;
        input [31:0] lhs;
        input [31:0] rhs;
        reg signed [31:0] signed_lhs;
        reg signed [31:0] signed_rhs;
        begin
            signed_lhs = lhs;
            signed_rhs = rhs;
            golden_signed_less = signed_lhs < signed_rhs;
        end
    endfunction

    task check_true;
        input condition;
        input [8*96-1:0] message;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                failures = failures + 1;
                if (failures <= 20)
                    $display("FAIL: case=%0d %0s", case_number, message);
            end
        end
    endtask

    task check_cla16;
        input [15:0] lhs;
        input [15:0] rhs;
        input carry_in;
        reg [16:0] wide_sum;
        reg [16:0] without_carry;
        begin
            a16 = lhs;
            b16 = rhs;
            cin16 = carry_in;
            wide_sum = {1'b0, lhs} + {1'b0, rhs} + carry_in;
            without_carry = {1'b0, lhs} + {1'b0, rhs};
            #1;
            check_true(s16 === wide_sum[15:0], "CLA16 sum");
            check_true(cout16 === wide_sum[16], "CLA16 carry out");
            check_true(gg16 === without_carry[16], "CLA16 group generate");
            check_true(pg16 === ((lhs | rhs) == 16'hffff), "CLA16 OR-propagate");
        end
    endtask

    task check_addsub32;
        input [31:0] lhs;
        input [31:0] rhs;
        input subtract;
        reg [32:0] wide_sum;
        reg [31:0] expected_f;
        reg expected_cf;
        begin
            arithmetic_a = lhs;
            arithmetic_b = rhs;
            arithmetic_sub = subtract;
            // The subtraction oracle does not use complement-plus-carry.
            if (subtract) begin
                expected_f = lhs - rhs;
                expected_cf = lhs < rhs;
            end else begin
                wide_sum = {1'b0, lhs} + {1'b0, rhs};
                expected_f = wide_sum[31:0];
                expected_cf = wide_sum[32];
            end
            #1;
            check_true(arithmetic_f === expected_f, "ADDSUB32 arithmetic result");
            check_true(arithmetic_cf === expected_cf, "ADDSUB32 carry/borrow");
            check_true(arithmetic_of === golden_overflow(lhs, rhs, subtract),
                       "ADDSUB32 signed overflow from 64-bit math");
            check_true(arithmetic_sf === expected_f[31], "ADDSUB32 arithmetic sign");
            check_true(arithmetic_zf === (expected_f == 32'b0), "ADDSUB32 arithmetic zero");
        end
    endtask

    // flags_in is CF, OF, SF, ZF, all describing arithmetic F.
    task check_alu_vector;
        input integer number;
        input [31:0] lhs;
        input [31:0] rhs;
        input [3:0] op;
        input [31:0] expected_result;
        input [31:0] expected_f;
        input [3:0] flags_in;
        input valid_in;
        reg expected_zero;
        begin
            case_number = number;
            a = lhs;
            b = rhs;
            control = op;
            expected_zero = valid_in ? flags_in[0] : 1'b0;
            #1;
            check_true(result === expected_result, "ALU_CORE RESULT");
            check_true(zero === expected_zero, "ALU_CORE ZERO (arithmetic F)");
            check_true(debug_result === expected_result, "ALU_DATAPATH RESULT");
            check_true(debug_zero === expected_zero, "ALU_DATAPATH ZERO (arithmetic F)");
            check_true(debug_f === expected_f, "ALU_DATAPATH debugF");
            check_true({cf, of_flag, sf, zf} === flags_in, "ALU_DATAPATH CF OF SF ZF");
            check_true(flags_valid === valid_in, "ALU_DATAPATH FLAGS_VALID");
        end
    endtask

    task check_alu_golden;
        input integer number;
        input [31:0] lhs;
        input [31:0] rhs;
        input [3:0] op;
        reg [31:0] expected_result;
        reg [31:0] expected_f;
        reg [32:0] wide_sum;
        reg [3:0] expected_flags;
        reg expected_valid;
        reg subtract;
        begin
            expected_result = 32'b0;
            expected_f = 32'b0;
            expected_flags = 4'b0;
            expected_valid = 1'b0;
            subtract = 1'b0;
            case (op)
                4'h0: expected_valid = 1'b1;
                4'h2, 4'h3, 4'h8: begin
                    expected_valid = 1'b1;
                    subtract = 1'b1;
                end
                default: expected_valid = 1'b0;
            endcase
            if (expected_valid) begin
                if (subtract) begin
                    expected_f = lhs - rhs;
                    expected_flags[3] = lhs < rhs;
                end else begin
                    wide_sum = {1'b0, lhs} + {1'b0, rhs};
                    expected_f = wide_sum[31:0];
                    expected_flags[3] = wide_sum[32];
                end
                expected_flags[2] = golden_overflow(lhs, rhs, subtract);
                expected_flags[1] = expected_f[31];
                expected_flags[0] = expected_f == 32'b0;
            end
            case (op)
                4'h0, 4'h8: expected_result = expected_f;
                4'h2: expected_result = {31'b0, golden_signed_less(lhs, rhs)};
                4'h3: expected_result = {31'b0, (lhs < rhs)};
                4'h6: expected_result = lhs | rhs;
                4'hf: expected_result = rhs;
                default: expected_result = 32'b0;
            endcase
            check_alu_vector(number, lhs, rhs, op, expected_result,
                             expected_f, expected_flags, expected_valid);
        end
    endtask

    initial begin
        checks = 0;
        failures = 0;
        case_number = 0;
        seed = 32'h6c616234;
        clu_p = 0; clu_g = 0; clu_c0 = 0;
        a4 = 0; b4 = 0; cin4 = 0;
        a16 = 0; b16 = 0; cin16 = 0;
        arithmetic_a = 0; arithmetic_b = 0; arithmetic_sub = 0;
        a = 0; b = 0; control = 0;
        #1;

        // CLU4: all 16*16*2 P/G/C0 combinations, not just A/B-derived P/G.
        for (i = 0; i < 512; i = i + 1) begin
            case_number = 10000 + i;
            clu_p = i[3:0];
            clu_g = i[7:4];
            clu_c0 = i[8];
            expected_carry = 5'b0;
            generate_carry = 5'b0;
            expected_carry[0] = clu_c0;
            for (j = 0; j < 4; j = j + 1) begin
                expected_carry[j+1] = clu_g[j] | (clu_p[j] & expected_carry[j]);
                generate_carry[j+1] = clu_g[j] | (clu_p[j] & generate_carry[j]);
            end
            #1;
            check_true(clu_c === expected_carry[4:1], "CLU4 carry recurrence oracle");
            check_true(clu_gg === generate_carry[4], "CLU4 generate with C0=0");
            check_true(clu_pg === (clu_p == 4'hf), "CLU4 group propagate");
        end

        // CLA4: all 16*16*2 A/B/C0 combinations.
        for (i = 0; i < 512; i = i + 1) begin
            case_number = 20000 + i;
            a4 = i[3:0];
            b4 = i[7:4];
            cin4 = i[8];
            expected5 = {1'b0, a4} + {1'b0, b4} + cin4;
            no_cin5 = {1'b0, a4} + {1'b0, b4};
            #1;
            check_true(s4 === expected5[3:0], "CLA4 sum");
            check_true(cout4 === expected5[4], "CLA4 carry out");
            check_true(gg4 === no_cin5[4], "CLA4 group generate");
            check_true(pg4 === ((a4 | b4) == 4'hf), "CLA4 OR-propagate");
        end

        case_number = 30000;
        check_cla16(16'h0000, 16'h0000, 1'b0);
        case_number = 30001;
        check_cla16(16'hffff, 16'h0001, 1'b0);
        case_number = 30002;
        check_cla16(16'h7fff, 16'h0000, 1'b1);
        case_number = 30003;
        check_cla16(16'hffff, 16'hffff, 1'b1);
        for (i = 0; i < 512; i = i + 1) begin
            case_number = 31000 + i;
            seed = next_seed(seed); sample_a = seed;
            seed = next_seed(seed); sample_b = seed;
            check_cla16(sample_a[15:0], sample_b[15:0], i[0]);
        end

        for (i = 0; i < 1024; i = i + 1) begin
            case_number = 40000 + i;
            seed = next_seed(seed); sample_a = seed;
            seed = next_seed(seed); sample_b = seed;
            check_addsub32(sample_a, sample_b, i[0]);
        end

        // Twenty fixed vectors with literal expected answers.
        check_alu_vector(1, 32'h00000000, 32'h00000000, 4'h0, 32'h00000000, 32'h00000000, 4'b0001, 1'b1);
        check_alu_vector(2, 32'h0000000f, 32'h00000001, 4'h0, 32'h00000010, 32'h00000010, 4'b0000, 1'b1);
        check_alu_vector(3, 32'h0000ffff, 32'h00000001, 4'h0, 32'h00010000, 32'h00010000, 4'b0000, 1'b1);
        check_alu_vector(4, 32'hffffffff, 32'h00000001, 4'h0, 32'h00000000, 32'h00000000, 4'b1001, 1'b1);
        check_alu_vector(5, 32'h7fffffff, 32'h00000001, 4'h0, 32'h80000000, 32'h80000000, 4'b0110, 1'b1);
        check_alu_vector(6, 32'h80000000, 32'h80000000, 4'h0, 32'h00000000, 32'h00000000, 4'b1101, 1'b1);
        check_alu_vector(7, 32'h00000000, 32'h00000001, 4'h8, 32'hffffffff, 32'hffffffff, 4'b1010, 1'b1);
        check_alu_vector(8, 32'h80000000, 32'h00000001, 4'h8, 32'h7fffffff, 32'h7fffffff, 4'b0100, 1'b1);
        check_alu_vector(9, 32'h7fffffff, 32'hffffffff, 4'h8, 32'h80000000, 32'h80000000, 4'b1110, 1'b1);
        check_alu_vector(10, 32'h12345678, 32'h12345678, 4'h8, 32'h00000000, 32'h00000000, 4'b0001, 1'b1);
        check_alu_vector(11, 32'h80000000, 32'h00000001, 4'h2, 32'h00000001, 32'h7fffffff, 4'b0100, 1'b1);
        check_alu_vector(12, 32'h7fffffff, 32'hffffffff, 4'h2, 32'h00000000, 32'h80000000, 4'b1110, 1'b1);
        check_alu_vector(13, 32'h80000000, 32'h00000001, 4'h3, 32'h00000000, 32'h7fffffff, 4'b0100, 1'b1);
        check_alu_vector(14, 32'h00000001, 32'hffffffff, 4'h3, 32'h00000001, 32'h00000002, 4'b1000, 1'b1);
        check_alu_vector(15, 32'h12345678, 32'h12345678, 4'h2, 32'h00000000, 32'h00000000, 4'b0001, 1'b1);
        check_alu_vector(16, 32'h12345678, 32'h12345678, 4'h3, 32'h00000000, 32'h00000000, 4'b0001, 1'b1);
        check_alu_vector(17, 32'haaaaaaaa, 32'h55555555, 4'h6, 32'hffffffff, 32'h00000000, 4'b0000, 1'b0);
        check_alu_vector(18, 32'h00000000, 32'h00000000, 4'h6, 32'h00000000, 32'h00000000, 4'b0000, 1'b0);
        check_alu_vector(19, 32'hffffffff, 32'h00000000, 4'hf, 32'h00000000, 32'h00000000, 4'b0000, 1'b0);
        check_alu_vector(20, 32'h00000000, 32'h80000000, 4'hf, 32'h80000000, 32'h00000000, 4'b0000, 1'b0);

        // Random ALU oracle uses mathematical comparison, not SF XOR OF.
        for (i = 0; i < 1024; i = i + 1) begin
            seed = next_seed(seed); sample_a = seed;
            seed = next_seed(seed); sample_b = seed;
            case (i % 6)
                0: sample_control = 4'h0;
                1: sample_control = 4'h2;
                2: sample_control = 4'h3;
                3: sample_control = 4'h6;
                4: sample_control = 4'h8;
                default: sample_control = 4'hf;
            endcase
            check_alu_golden(50000 + i, sample_a, sample_b, sample_control);
        end

        // All ten unused binary controls, plus two four-state controls.
        for (i = 0; i < 16; i = i + 1) begin
            if ((i != 0) && (i != 2) && (i != 3)
                && (i != 6) && (i != 8) && (i != 15))
                check_alu_vector(60000 + i, 32'hdeadbeef, 32'h12345678,
                                 i[3:0], 32'b0, 32'b0, 4'b0, 1'b0);
        end
        check_alu_vector(60016, 32'hdeadbeef, 32'h12345678,
                         4'bx000, 32'b0, 32'b0, 4'b0, 1'b0);
        check_alu_vector(60017, 32'hdeadbeef, 32'h12345678,
                         4'bxxxx, 32'b0, 32'b0, 4'b0, 1'b0);

        $display("INFO: CLU4=512 exhaustive; CLA4=512 exhaustive; CLA16=4 directed+512 random");
        $display("INFO: ADDSUB32=1024 random; ALU=20 fixed+1024 random+12 invalid; seed=6c616234");
        status_file = $fopen("lab4_sim_status.txt", "w");
        if (status_file == 0) begin
            $display("FAIL: cannot write lab4_sim_status.txt in the simulation working directory");
            $fatal(1, "Cannot write simulation status");
        end
        if (failures == 0) begin
            $display("PASS: ALL CORE TESTS PASSED (%0d checks)", checks);
            $fdisplay(status_file, "PASS checks=%0d errors=%0d", checks, failures);
        end else begin
            $display("FAIL: CORE TESTS FAILED (%0d failures / %0d checks)", failures, checks);
            $fdisplay(status_file, "FAIL checks=%0d errors=%0d", checks, failures);
        end
        $fclose(status_file);
        // $fatal is supported by both target simulators, Icarus and Vivado.
        // The surrounding language syntax is Verilog-2001.
        if (failures != 0)
            $fatal(1, "Core self-check failed");
        $finish;
    end
endmodule
