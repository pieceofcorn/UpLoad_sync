`timescale 1ns/1ps
module preset_vectors(
    input wire [4:0] index,
    output reg valid,
    output reg [31:0] A, B, expected_result,
    output reg [3:0] op, expected_flags,
    output wire expected_flags_valid, output wire expected_zero
);
    // Flags are {CF,OF,SF,ZF}; subtract CF means borrow.
    always @* begin
        valid=1'b1; A=0; B=0; op=0; expected_result=0; expected_flags=0;
        case(index)
            0: begin A=32'h00000000;B=32'h00000000;op=4'h0;expected_result=32'h00000000;expected_flags=4'b0001;end
            1: begin A=32'h0000000f;B=32'h00000001;op=4'h0;expected_result=32'h00000010;expected_flags=4'b0000;end
            2: begin A=32'h0000ffff;B=32'h00000001;op=4'h0;expected_result=32'h00010000;expected_flags=4'b0000;end
            3: begin A=32'hffffffff;B=32'h00000001;op=4'h0;expected_result=32'h00000000;expected_flags=4'b1001;end
            4: begin A=32'h7fffffff;B=32'h00000001;op=4'h0;expected_result=32'h80000000;expected_flags=4'b0110;end
            5: begin A=32'h80000000;B=32'h80000000;op=4'h0;expected_result=32'h00000000;expected_flags=4'b1101;end
            6: begin A=32'h00000000;B=32'h00000001;op=4'h8;expected_result=32'hffffffff;expected_flags=4'b1010;end
            7: begin A=32'h80000000;B=32'h00000001;op=4'h8;expected_result=32'h7fffffff;expected_flags=4'b0100;end
            8: begin A=32'h7fffffff;B=32'hffffffff;op=4'h8;expected_result=32'h80000000;expected_flags=4'b1110;end
            9: begin A=32'h12345678;B=32'h12345678;op=4'h8;expected_result=32'h00000000;expected_flags=4'b0001;end
           10: begin A=32'h80000000;B=32'h00000001;op=4'h2;expected_result=32'h00000001;expected_flags=4'b0100;end
           11: begin A=32'h7fffffff;B=32'hffffffff;op=4'h2;expected_result=32'h00000000;expected_flags=4'b1110;end
           12: begin A=32'h80000000;B=32'h00000001;op=4'h3;expected_result=32'h00000000;expected_flags=4'b0100;end
           13: begin A=32'h00000001;B=32'hffffffff;op=4'h3;expected_result=32'h00000001;expected_flags=4'b1000;end
           14: begin A=32'h12345678;B=32'h12345678;op=4'h2;expected_result=32'h00000000;expected_flags=4'b0001;end
           15: begin A=32'h12345678;B=32'h12345678;op=4'h3;expected_result=32'h00000000;expected_flags=4'b0001;end
           16: begin A=32'haaaaaaaa;B=32'h55555555;op=4'h6;expected_result=32'hffffffff;expected_flags=4'b0000;end
           17: begin A=32'h00000000;B=32'h00000000;op=4'h6;expected_result=32'h00000000;expected_flags=4'b0000;end
           18: begin A=32'hffffffff;B=32'h00000000;op=4'hf;expected_result=32'h00000000;expected_flags=4'b0000;end
           19: begin A=32'h00000000;B=32'h80000000;op=4'hf;expected_result=32'h80000000;expected_flags=4'b0000;end
            default: valid=1'b0;
        endcase
    end
    assign expected_flags_valid = valid && ((op==0)||(op==2)||(op==3)||(op==8));
    assign expected_zero = expected_flags_valid && expected_flags[0];
endmodule
