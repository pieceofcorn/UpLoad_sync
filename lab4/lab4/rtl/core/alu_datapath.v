timescale 1ns/1ps
module alu_datapath (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUctr,
    output reg  [31:0] RESULT,
    output wire        ZERO,
    output wire [31:0] debugF,
    output wire        CF,
    output wire        OF,
    output wire        SF,
    output wire        ZF,
    output reg         FLAGS_VALID
);
    reg sub_control;
    wire [31:0] arithmetic_f;
    wire arithmetic_cf;
    wire arithmetic_of;
    wire arithmetic_sf;
    wire arithmetic_zf;

    // Decode arithmetic operations. Comparisons share the subtract datapath.
    always @* begin
        sub_control = 1'b0;
        FLAGS_VALID = 1'b0;

        case (ALUctr)
            4'h0: begin // add
                sub_control = 1'b0;
                FLAGS_VALID = 1'b1;
            end

            4'h2: begin // signed less-than
                sub_control = 1'b1;
                FLAGS_VALID = 1'b1;
            end

            4'h3: begin // unsigned less-than
                sub_control = 1'b1;
                FLAGS_VALID = 1'b1;
            end

            4'h8: begin // subtract
                sub_control = 1'b1;
                FLAGS_VALID = 1'b1;
            end

            default: begin
                sub_control = 1'b0;
                FLAGS_VALID = 1'b0;
            end
        endcase
    end

    addsub32 u_arithmetic (
        .A(A),
        .B(B),
        .SUB(sub_control),
        .F(arithmetic_f),
        .CF(arithmetic_cf),
        .OF(arithmetic_of),
        .SF(arithmetic_sf),
        .ZF(arithmetic_zf)
    );

    // Select the requested operation. Comparison results are zero-extended.
    always @* begin
        case (ALUctr)
            4'h0: RESULT = arithmetic_f;                         // add
            4'h2: RESULT = {31'b0, (arithmetic_sf ^ arithmetic_of)}; // slt
            4'h3: RESULT = {31'b0, arithmetic_cf};               // sltu
            4'h6: RESULT = A | B;                                // or
            4'h8: RESULT = arithmetic_f;                         // sub
            4'hf: RESULT = B;                                    // srcB
            default: RESULT = 32'b0;
        endcase
    end

    // Arithmetic debug outputs and flags are suppressed for non-arithmetic
    // operations and unused control encodings.
    assign debugF = FLAGS_VALID ? arithmetic_f : 32'b0;
    assign CF = FLAGS_VALID ? arithmetic_cf : 1'b0;
    assign OF = FLAGS_VALID ? arithmetic_of : 1'b0;
    assign SF = FLAGS_VALID ? arithmetic_sf : 1'b0;
    assign ZF = FLAGS_VALID ? arithmetic_zf : 1'b0;
    assign ZERO = ZF;
endmodule
