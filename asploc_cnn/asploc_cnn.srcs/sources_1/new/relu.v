`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/14/2024 08:53:29 PM
// Design Name: asploc_cnn
// Module Name: relu_n_dq
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: ReLu and dequantization methods
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module relu_n_dq(
    input clk,
    input rst_n,
    input [9:0] img_addr_i,
    input [95:0] img_data_i,
    input img_data_en_i,
    input img_data_rw_i,
    input [4:0] channel_code_i,
    output [9:0] img_addr_o,
    output [47:0] img_data_o,
    output img_data_en_o,
    output img_data_rw_o,
    output [4:0] channel_code_o
    );

    reg signed [15:0] decomp_img [5:0];
    reg [47:0] dq_img_o;
    reg [9:0] img_addr_d1;
    reg [9:0] img_addr_d2;
    reg [4:0] channel_code_d1;
    reg [4:0] channel_code_d2;
    reg img_data_en_d1;
    reg img_data_en_d2;
    reg img_data_rw_d1;
    reg img_data_rw_d2;

    integer i;
    genvar j;

    wire signed [15:0] round_img_val [5:0];

    assign img_data_o = dq_img_o;
    assign img_addr_o = img_addr_d2;
    assign img_data_en_o = img_data_en_d2;
    assign img_data_rw_o = img_data_rw_d2;
    assign channel_code_o = channel_code_d2;

    for (j = 0; j < 6; j=j+1) begin
        assign round_img_val[j] = decomp_img[j]+16'h000f;
    end

    always @(posedge clk ) begin
        for (i = 0; i < 6; i=i+1) begin
            decomp_img[i] <= img_data_i[i*16 +: 16];
            if (decomp_img[i] < 0) begin
                dq_img_o[i*8 +: 8] <= 8'h0;
            end else begin
                dq_img_o[i*8 +: 8] <= round_img_val[i][15:8];
            end
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            img_addr_d1    <= 10'h0;
            img_addr_d2    <= 10'h0;
            channel_code_d1<= 5'h0;
            channel_code_d2<= 5'h0;
            img_data_en_d1 <= 1'b0;
            img_data_en_d2 <= 1'b0;
            img_data_rw_d1 <= 1'b0;
            img_data_rw_d2 <= 1'b0;
        end else begin
            img_addr_d1    <= img_addr_i;
            img_addr_d2    <= img_addr_d1;
            img_data_en_d1 <= img_data_en_i;
            img_data_en_d2 <= img_data_en_d1;
            img_data_rw_d1 <= img_data_rw_i;
            img_data_rw_d2 <= img_data_rw_d1;
            channel_code_d1<= channel_code_i;
            channel_code_d2<= channel_code_d1;
        end
    end

endmodule


module relu_n_dq_16(
    input clk,
    input rst_n,
    input [9:0] img_addr_i,
    input [15:0] img_data_i,
    output [9:0] img_addr_o,
    output [7:0] img_data_o
    );

    reg signed [15:0] decomp_img;
    reg [7:0] dq_img_o;
    reg [9:0] img_addr_d1;
    reg [9:0] img_addr_d2;

    integer i;
    genvar j;

    wire signed [15:0] round_img_val;

    assign img_data_o = dq_img_o;
    assign img_addr_o = img_addr_d2;

    assign round_img_val = decomp_img +16'sh007f;

    always @(posedge clk ) begin
        decomp_img <= img_data_i;
        if (decomp_img < 0) begin
            dq_img_o <= 8'h0;
        end else begin
            dq_img_o <= round_img_val[15:8];
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            img_addr_d1    <= 10'h0;
            img_addr_d2    <= 10'h0;
        end else begin
            img_addr_d1    <= img_addr_i;
            img_addr_d2    <= img_addr_d1;
        end
    end

endmodule
