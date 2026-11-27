`timescale 1ns/1ps
// Provided interface adapter. Do not add clock or board-specific pins here.
module alu_core (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUctr,
    output wire [31:0] RESULT,
    output wire        ZERO
);
    wire [31:0] unused_debug_f;
    wire unused_cf;
    wire unused_of;
    wire unused_sf;
    wire unused_zf;
    wire unused_flags_valid;
    // TODO CHECK: this same interface will be reused by the later CPU.
    alu_datapath u_datapath (
        .A(A), .B(B), .ALUctr(ALUctr), .RESULT(RESULT), .ZERO(ZERO),
        .debugF(unused_debug_f), .CF(unused_cf), .OF(unused_of),
        .SF(unused_sf), .ZF(unused_zf), .FLAGS_VALID(unused_flags_valid)
    );
endmodule
