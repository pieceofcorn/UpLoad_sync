`timescale 1ns/1ps
module cla4 (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       C0,
    output wire [3:0] S,
    output wire       C4,
    output wire       Gg,
    output wire       Pg
);
    wire [3:0] p;
    wire [3:0] g;
    wire [3:0] h;
    wire [4:1] carry;

    // TODO 2: the course definitions are p=A|B, g=A&B, h=A^B.
    assign p = 4'b0;
    assign g = 4'b0;
    assign h = 4'b0;
    clu4 u_clu4 (
        .P(p), .G(g), .C0(C0), .C(carry), .Gg(Gg), .Pg(Pg)
    );
    // TODO 3: combine h with each bit's carry input, not its carry output.
    assign S = 4'b0;
    assign C4 = carry[4];
endmodule
