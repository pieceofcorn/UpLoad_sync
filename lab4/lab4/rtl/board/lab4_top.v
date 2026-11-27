`timescale 1ns/1ps
module lab4_top #(
    parameter integer CLK_HZ=100000000,
    parameter integer DEBOUNCE_CYCLES=1000000
)(
    input wire clk, input wire [23:0] sw,
    input wire btn_load, btn_reset,
    output wire [7:0] led, output wire [7:0] seg_an, seg_cat
);
    reg [23:0] sw0=0, switches=0;
    reg [31:0] manualA=0, manualB=0;
    wire load_pulse, reset_level;
    wire unused_load_level, unused_reset_pulse;
    always @(posedge clk) begin sw0<=sw; switches<=sw0; end
    button_clean #(.CYCLES(DEBOUNCE_CYCLES)) load_filter(
        .clk(clk),.raw(btn_load),.level(unused_load_level),.pulse(load_pulse));
    button_clean #(.CYCLES(DEBOUNCE_CYCLES)) reset_filter(
        .clk(clk),.raw(btn_reset),.level(reset_level),.pulse(unused_reset_pulse));
    always @(posedge clk) begin
        if(reset_level) begin manualA<=0;manualB<=0;end
        else if(load_pulse && switches[17]) begin
            if(switches[10]) begin
                case(switches[9:8])
                    0: manualB[7:0]<=switches[7:0];
                    1: manualB[15:8]<=switches[7:0];
                    2: manualB[23:16]<=switches[7:0];
                    3: manualB[31:24]<=switches[7:0];
                endcase
            end else begin
                case(switches[9:8])
                    0: manualA[7:0]<=switches[7:0];
                    1: manualA[15:8]<=switches[7:0];
                    2: manualA[23:16]<=switches[7:0];
                    3: manualA[31:24]<=switches[7:0];
                endcase
            end
        end
    end
    wire pv, efv, ez;
    wire [31:0] pA,pB,er;
    wire [3:0] po,ef;
    preset_vectors vectors(.index(switches[22:18]),.valid(pv),.A(pA),.B(pB),
        .expected_result(er),.op(po),.expected_flags(ef),
        .expected_flags_valid(efv),.expected_zero(ez));
    wire [31:0] A=switches[17]?manualA:pA;
    wire [31:0] B=switches[17]?manualB:pB;
    wire [3:0] op=switches[17]?switches[14:11]:po;
    wire [31:0] result,arithF;
    wire zero,cf,of,sf,zf,fv;
    alu_datapath dut(.A(A),.B(B),.ALUctr(op),.RESULT(result),.ZERO(zero),
        .debugF(arithF),.CF(cf),.OF(of),.SF(sf),.ZF(zf),.FLAGS_VALID(fv));
    wire match = pv && (result==er) && (fv==efv) && (zero==ez) &&
                 ((!efv)||({cf,of,sf,zf}==ef));
    wire invalid = !switches[17] && !pv;
    assign led = {(!switches[17] && match), switches[17],
                  (zero && fv && !invalid), (fv && !invalid),
                  (fv && !invalid ? {cf,of,sf,zf}:4'b0)};
    reg [31:0] display_data;
    always @* begin
        case(switches[16:15])
            0: display_data=A;
            1: display_data=B;
            2: display_data=result;
            3: display_data=arithF;
        endcase
        if(invalid) display_data=32'heeeeeeee;
    end
    hex8_scan #(.CLK_HZ(CLK_HZ)) display_driver(
        .clk(clk),.data(display_data),.an(seg_an),.seg(seg_cat));
endmodule
