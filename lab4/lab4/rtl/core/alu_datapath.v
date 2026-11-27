`timescale 1ns/1ps
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

    // TODO 6: decode 0=add, 2=slt, 3=sltu, 6=or, 8=sub, F=srcB.
    // Set SUB for sub and BOTH comparisons. Flags are valid only for 0/2/3/8.
    // Keep defaults and a default case so this remains combinational.
    always @* begin
        case (ALUctr)
            default: begin
                sub_control = 1'b0;
                FLAGS_VALID = 1'b0;
            end
        endcase
    end
    addsub32 u_arithmetic (
        .A(A), .B(B), .SUB(sub_control), .F(arithmetic_f),
        .CF(arithmetic_cf), .OF(arithmetic_of),
        .SF(arithmetic_sf), .ZF(arithmetic_zf)
    );

    // TODO 7: select the result; compare outputs must be zero-extended to 32 bits.
    // For signed less use arithmetic_sf XOR arithmetic_of.
    // Unsupported (including unknown) control values must produce zero.
    always @* begin
        case (ALUctr)
            default: RESULT = 32'b0;
        endcase
    end

    assign debugF = FLAGS_VALID ? arithmetic_f : 32'b0;
    assign CF = FLAGS_VALID ? arithmetic_cf : 1'b0;
    assign OF = FLAGS_VALID ? arithmetic_of : 1'b0;
    assign SF = FLAGS_VALID ? arithmetic_sf : 1'b0;
    assign ZF = FLAGS_VALID ? arithmetic_zf : 1'b0;
    assign ZERO = ZF;
endmodule
