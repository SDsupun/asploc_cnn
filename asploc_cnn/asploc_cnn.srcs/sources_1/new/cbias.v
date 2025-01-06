`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/16/2024 10:37:07 PM
// Design Name: asploc_cnn
// Module Name: cbias
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: Add biases for the convolution channels
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cbias(
    input clk,
    input rst_n,
    input [7:0] bias_data,
    input [4:0] bias_addr,
    input bias_en,
    output bias_w_o,
    input [9:0] img_addr_i,
    input [95:0] img_data_i,
    input img_data_en_i,
    input img_data_rw_i,
    input [4:0] channel_code_i,
    output [9:0] img_addr_o,
    output [95:0] img_data_o,
    output img_data_en_o,
    output img_data_rw_o,
    output [4:0] channel_code_o
    );

    localparam B_SIZE = 22;
    localparam CONV_2_IN__CHN = 6;

    reg signed [15:0] decomp_img [5:0];
    reg bias_w;
    
    reg [9:0] img_addr_d1;
    reg img_data_en_d1;
    reg img_data_rw_d1;
    reg [4:0] channel_code_d1;

    integer i;
    genvar j;
    
    assign bias_w_o = bias_w;
    assign img_addr_o = img_addr_d1;
    assign img_data_en_o = img_data_en_d1;
    assign img_data_rw_o = img_data_rw_d1;
    assign channel_code_o = channel_code_d1;


    for (j = 0; j < 6; j=j+1) begin
        assign img_data_o[j*16 +: 16] = decomp_img[j];
    end

    (* ram_style = "block"*) reg signed [7:0] chn_bias[0:B_SIZE-1];
    initial begin
        for(i = 0; i < B_SIZE; i = i+1)
            chn_bias[i] <= 0;
    end

    // signal pipeline
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            img_addr_d1 <= 10'h0;
            img_data_en_d1 <= 1'b0;
            img_data_rw_d1 <= 1'b0;
            channel_code_d1 <= 5'h0;
        end else begin
            img_addr_d1 <= img_addr_i;
            img_data_en_d1 <= img_data_en_i;
            img_data_rw_d1 <= img_data_rw_i;
            channel_code_d1 <= channel_code_i;
        end
    end

    // Load biass
    always @(posedge clk) begin
        if (bias_en) begin
            chn_bias[bias_addr] <= bias_data;
        end
    end
    
    // Add the biases
    always @(posedge clk ) begin
        for (i = 0; i < 6; i=i+1) begin
            if (!bias_w) begin
                if (channel_code_i == 5'h00) begin
                    decomp_img[i] <= img_data_i[i*16 +: 16];
                end else if (channel_code_i == 5'h01) begin
                    decomp_img[i] <= img_data_i[i*16 +: 16] + chn_bias[i];
                end else begin
                    decomp_img[i] <= img_data_i[i*16 +: 16] + chn_bias[CONV_2_IN__CHN + channel_code_i -2];
                end
            end else begin
                decomp_img[i] <= img_data_i[i*16 +: 16];
            end
        end
    end

    // Check for new bias data and be ready 
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            bias_w <= 1'b1;
        end else begin
            if (bias_en) begin
                bias_w <= 1'b1;
                if (bias_addr == B_SIZE - 1) begin
                    bias_w <= 1'b0;
                end else begin
                    bias_w <= 1'b1;
                end
            end else begin
                bias_w <= bias_w;
            end
        end
    end


endmodule
