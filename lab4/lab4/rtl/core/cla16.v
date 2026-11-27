timescale 1ns/1ps
// Assemble four CLA4 blocks and one group CLU4.
module cla16 (
    input  wire [15:0] A,
    input  wire [15:0] B,
    input  wire        C0,
    output wire [15:0] S,
    output wire        C16,
    output wire        Gg,
    output wire        Pg
);
    wire [3:0] block_g;
    wire [3:0] block_p;
    wire [3:0] unused_block_cout;
    wire [4:1] group_carry;

    // Lowest four-bit block.
    cla4 u_cla0 (
        .A(A[3:0]),
        .B(B[3:0]),
        .C0(C0),
        .S(S[3:0]),
        .C4(unused_block_cout[0]),
        .Gg(block_g[0]),
        .Pg(block_p[0])
    );

    // Remaining three four-bit blocks.
    cla4 u_cla1 (
        .A(A[7:4]),
        .B(B[7:4]),
        .C0(group_carry[1]),
        .S(S[7:4]),
        .C4(unused_block_cout[1]),
        .Gg(block_g[1]),
        .Pg(block_p[1])
    );

    cla4 u_cla2 (
        .A(A[11:8]),
        .B(B[11:8]),
        .C0(group_carry[2]),
        .S(S[11:8]),
        .C4(unused_block_cout[2]),
        .Gg(block_g[2]),
        .Pg(block_p[2])
    );

    cla4 u_cla3 (
        .A(A[15:12]),
        .B(B[15:12]),
        .C0(group_carry[3]),
        .S(S[15:12]),
        .C4(unused_block_cout[3]),
        .Gg(block_g[3]),
        .Pg(block_p[3])
    );

    // Group-level lookahead computes the carry into each CLA4 block.
    clu4 u_group_clu4 (
        .P(block_p),
        .G(block_g),
        .C0(C0),
        .C(group_carry),
        .Gg(Gg),
        .Pg(Pg)
    );

    assign C16 = group_carry[4];
endmodule
