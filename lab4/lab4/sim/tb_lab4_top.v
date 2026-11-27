`timescale 1ns/1ps
module tb_lab4_top;
    reg clk=0;
    always #5 clk=~clk;
    reg [23:0] sw=0;
    reg load=0, reset=0;
    wire [7:0] led,an,seg;
    integer checks=0, errors=0, i, fd;
    reg [31:0] before_value;
    lab4_top #(.CLK_HZ(8000),.DEBOUNCE_CYCLES(2)) dut(
        .clk(clk),.sw(sw),.btn_load(load),.btn_reset(reset),
        .led(led),.seg_an(an),.seg_cat(seg));
    task check;
        input okay;
        input [511:0] label;
        begin
            checks=checks+1;
            if(okay !== 1'b1) begin errors=errors+1; $display("FAIL BOARD: %0s",label);end
        end
    endtask
    task settle;
        begin repeat(8) @(negedge clk);end
    endtask
    task clear_operands;
        begin reset=1;repeat(10) @(negedge clk);reset=0;repeat(10) @(negedge clk);end
    endtask
    task put_byte;
        input target;
        input [1:0] position;
        input [7:0] value;
        begin
            sw[17]=1; sw[10]=target;sw[9:8]=position;sw[7:0]=value;
            settle;
            load=1;repeat(10) @(negedge clk);
            load=0;repeat(10) @(negedge clk);
        end
    endtask
    function [7:0] digit_pattern;
        input [3:0] h;
        begin
            case(h)
            0:digit_pattern=8'hc0;1:digit_pattern=8'hf9;2:digit_pattern=8'ha4;3:digit_pattern=8'hb0;
            4:digit_pattern=8'h99;5:digit_pattern=8'h92;6:digit_pattern=8'h82;7:digit_pattern=8'hf8;
            8:digit_pattern=8'h80;9:digit_pattern=8'h90;10:digit_pattern=8'h88;11:digit_pattern=8'h83;
            12:digit_pattern=8'hc6;13:digit_pattern=8'ha1;14:digit_pattern=8'h86;15:digit_pattern=8'h8e;
            endcase
        end
    endfunction
    initial begin
        settle;
        for(i=0;i<20;i=i+1) begin
            sw=0;sw[22:18]=i;sw[16:15]=2;settle;
            check(led[7]===1'b1,"all twenty preset result/flag/ZERO comparisons");
            check(led[6]===1'b0,"preset mode indication");
            check(dut.display_data===dut.result,"result display page");
            sw[16:15]=0;settle;check(dut.display_data===dut.A,"A display page");
            sw[16:15]=1;settle;check(dut.display_data===dut.B,"B display page");
            sw[16:15]=3;settle;check(dut.display_data===dut.arithF,"arithmetic F page");
        end
        sw=0;sw[22:18]=31;settle;
        check(led[7]===0 && led[4]===0,"invalid preset cannot pass");
        check(dut.display_data===32'heeeeeeee,"invalid preset has visible E error");
        sw=0;sw[17]=1;clear_operands;
        check(dut.manualA===0 && dut.manualB===0,"reset clears manual operands");
        // A pulse shorter than the filter threshold must not capture data.
        sw[7:0]=8'hff;settle;load=1;@(negedge clk);load=0;settle;
        check(dut.manualA===0,"short button bounce is rejected");
        put_byte(0,0,8'h78);put_byte(0,1,8'h56);put_byte(0,2,8'h34);put_byte(0,3,8'h12);
        put_byte(1,0,8'h04);put_byte(1,1,8'h03);put_byte(1,2,8'h02);put_byte(1,3,8'h01);
        check(dut.manualA===32'h12345678 && dut.manualB===32'h01020304,"byte capture and A/B selection");
        sw[14:11]=0;sw[16:15]=2;settle;
        check(dut.result===(32'h12345678+32'h01020304),"manual add");
        check(led[6]===1 && led[7]===0,"manual mode disables preset pass indication");
        sw[14:11]=8;settle;
        check(dut.result===(32'h12345678-32'h01020304),"manual subtraction");
        sw[14:11]=6;settle;
        check(dut.result===(32'h12345678|32'h01020304) && led[5:0]===0,"OR masks arithmetic flags");
        sw[14:11]=15;settle;check(dut.result===32'h01020304,"manual srcB");
        sw[14:11]=1;settle;check(dut.result===0 && led[5:0]===0,"unused operation defaults");
        // A held load button captures exactly once despite later switch changes.
        sw[10]=0;sw[9:8]=0;sw[7:0]=8'h55;settle;
        load=1;repeat(12) @(negedge clk);before_value=dut.manualA;
        sw[7:0]=8'haa;repeat(20) @(negedge clk);
        check(dut.manualA===before_value && dut.manualA[7:0]===8'h55,"held button is one capture");
        load=0;repeat(12) @(negedge clk);
        put_byte(0,0,8'haa);check(dut.manualA[7:0]===8'haa,"released button permits next capture");
        clear_operands;check(dut.manualA===0 && dut.manualB===0,"reset after writes");
        // Check logical digit ordering and segment encoding over a full scan.
        put_byte(0,0,8'h10);put_byte(0,1,8'h32);put_byte(0,2,8'h54);put_byte(0,3,8'h76);
        sw[16:15]=0;settle;
        for(i=0;i<16;i=i+1) begin
            @(negedge clk);
            check(an===(~(8'b1<<dut.display_driver.digit)),"one active digit, correct logical order");
            check(seg===digit_pattern((32'h76543210>>(4*dut.display_driver.digit))&15),"hex segment encoding");
        end
        fd=$fopen("lab4_board_status.txt","w");
        if(errors==0) begin
            $fdisplay(fd,"PASS checks=%0d errors=0",checks);$fclose(fd);
            $display("PASS: BOARD LOGIC TESTS PASSED (%0d checks)",checks);$finish;
        end else begin
            $fdisplay(fd,"FAIL checks=%0d errors=%0d",checks,errors);$fclose(fd);
            $fatal(1,"Board logic simulation failed");
        end
    end
endmodule
