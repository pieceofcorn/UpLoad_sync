`timescale 1ns/1ps
module addsub32 (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire        SUB,
    output wire [31:0] F,
    output wire        CF,
    output wire        OF,
    output wire        SF,
    output wire        ZF
);
    wire [31:0] b_eff;
    wire c16;
    wire c32;
    wire [1:0] unused_group_g;
    wire [1:0] unused_group_p;

    // TODO 4: transform B for add/sub; the low carry input is already SUB.
    assign b_eff = 32'b0;
    cla16 u_low (
        .A(A[15:0]), .B(b_eff[15:0]), .C0(SUB), .S(F[15:0]),
        .C16(c16), .Gg(unused_group_g[0]), .Pg(unused_group_p[0])
    );
    // TODO STRUCT-32: instantiate the upper CLA16 and complete the inter-block
    // carry connection. Choose its data slices, carry input, and carry output.
    // The low block above is an instance-writing example, not a complete
    // 32-bit assembly. Do not use a behavioral A+B or A-B as a replacement.
    //
    // PLACEHOLDERS: remove these when the upper block drives the same nets.
    assign F[31:16] = 16'b0;
    assign c32 = 1'b0;
    assign unused_group_g[1] = 1'b0;
    assign unused_group_p[1] = 1'b0;
    // TODO 5: CF means borrow=1 for subtraction. OF is signed overflow.
    // SF and ZF describe arithmetic F, not the ALU result multiplexer.
    assign CF = 1'b0;
    assign OF = 1'b0;
    assign SF = 1'b0;
    assign ZF = 1'b0;
endmodule
