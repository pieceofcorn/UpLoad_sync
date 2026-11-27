`timescale 1ns/1ps
// Complete the core logic in this directory.
module clu4 (
    input  wire [3:0] P,
    input  wire [3:0] G,
    input  wire       C0,
    output wire [4:1] C,
    output wire       Gg,
    output wire       Pg
);
    // TODO 1: replace zero placeholders with expanded carry-lookahead equations.
    // C[i] is the carry into bit/group i; Gg and Pg must not depend on C0.
    assign C = 4'b0;
    assign Gg = 1'b0;
    assign Pg = 1'b0;
endmodule
