timescale 1ns/1ps
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

    // The course design uses OR-propagate for carry logic and XOR for sum.
    assign p = A | B;
    assign g = A & B;
    assign h = A ^ B;

    clu4 u_clu4 (
        .P(p),
        .G(g),
        .C0(C0),
        .C(carry),
        .Gg(Gg),
        .Pg(Pg)
    );

    // carry[1], carry[2], carry[3] are the carry-ins of bits 1, 2, 3.
    // Bit 0 uses the external carry-in C0.
    assign S = h ^ {carry[3:1], C0};
    assign C4 = carry[4];
endmodule
