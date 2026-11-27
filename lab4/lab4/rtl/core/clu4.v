timescale 1ns/1ps
// Four-bit carry lookahead unit.
// P is the OR-propagate term (A | B); G is the generate term (A & B).
module clu4 (
    input  wire [3:0] P,
    input  wire [3:0] G,
    input  wire       C0,
    output wire [4:1] C,
    output wire       Gg,
    output wire       Pg
);
    // Expanded carry equations. Each carry is computed directly from P, G
    // and C0 rather than waiting for the preceding carry output.
    assign C[1] = G[0] |
                  (P[0] & C0);

    assign C[2] = G[1] |
                  (P[1] & G[0]) |
                  (P[1] & P[0] & C0);

    assign C[3] = G[2] |
                  (P[2] & G[1]) |
                  (P[2] & P[1] & G[0]) |
                  (P[2] & P[1] & P[0] & C0);

    assign C[4] = G[3] |
                  (P[3] & G[2]) |
                  (P[3] & P[2] & G[1]) |
                  (P[3] & P[2] & P[1] & G[0]) |
                  (P[3] & P[2] & P[1] & P[0] & C0);

    // Group generate and group propagate do not depend on C0.
    assign Gg = G[3] |
                (P[3] & G[2]) |
                (P[3] & P[2] & G[1]) |
                (P[3] & P[2] & P[1] & G[0]);

    assign Pg = P[3] & P[2] & P[1] & P[0];
endmodule
