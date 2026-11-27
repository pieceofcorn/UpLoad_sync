`timescale 1ns/1ps
module button_clean #(parameter integer CYCLES = 1000000)(
    input wire clk, input wire raw, output wire level, output wire pulse
);
    reg s0 = 1'b0, s1 = 1'b0, stable = 1'b0, old_stable = 1'b0;
    reg [31:0] count = 32'd0;
    always @(posedge clk) begin
        s0 <= raw;
        s1 <= s0;
        old_stable <= stable;
        if (s1 == stable) count <= 0;
        else if (count >= CYCLES-1) begin
            stable <= s1;
            count <= 0;
        end else count <= count + 1'b1;
    end
    assign level = stable;
    assign pulse = stable & ~old_stable;
endmodule
