`timescale 1ns/1ps
// Logical order: seg[0]=a ... seg[6]=g, seg[7]=dp; all active low.
// an[0] is the rightmost digit. Map physical pins only after verification.
module hex8_scan #(parameter integer CLK_HZ = 100000000)(
    input wire clk, input wire [31:0] data,
    output reg [7:0] an, output reg [7:0] seg
);
    localparam integer DIV = (CLK_HZ/8000 < 1) ? 1 : CLK_HZ/8000;
    reg [31:0] count = 0;
    reg [2:0] digit = 0;
    reg [3:0] hex;
    always @(posedge clk) begin
        if (count >= DIV-1) begin count <= 0; digit <= digit + 1'b1; end
        else count <= count + 1'b1;
    end
    always @* begin
        hex = (data >> (digit*4)) & 4'hf;
        an = ~(8'b00000001 << digit);
        case (hex)
            4'h0: seg=8'hc0; 4'h1: seg=8'hf9;
            4'h2: seg=8'ha4; 4'h3: seg=8'hb0;
            4'h4: seg=8'h99; 4'h5: seg=8'h92;
            4'h6: seg=8'h82; 4'h7: seg=8'hf8;
            4'h8: seg=8'h80; 4'h9: seg=8'h90;
            4'ha: seg=8'h88; 4'hb: seg=8'h83;
            4'hc: seg=8'hc6; 4'hd: seg=8'ha1;
            4'he: seg=8'h86; 4'hf: seg=8'h8e;
            default: seg=8'hff;
        endcase
    end
endmodule
