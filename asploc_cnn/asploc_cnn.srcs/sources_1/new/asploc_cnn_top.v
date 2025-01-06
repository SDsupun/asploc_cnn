`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/18/2024 08:55:57 AM
// Design Name: asploc_cnn
// Module Name: asploc_cnn_top
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: Top module for all connections
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module asploc_cnn_top(
    input clk,
    input rst_n,
    input [7:0] img_data_top_i,
    input load_sw_img_top_i,
    input read_result_top_i,
    output conv_busy_top_o,
    output conv_done_top_o,
    output dense_done_top_o,
    output [3:0] result_top_o,
    output [7:0] conv_debug_o,
    output [7:0] dense_debug_o
    );

    wire [7:0] conv_img;
    wire conv_img_valid;

    wire dense_read;
    
    conv2d conv2d_inst(
        .clk(clk),
        .rst_n(rst_n),
        .img_data_i(img_data_top_i),
        .img_in_valid_i(load_sw_img_top_i),
        .read_result_i(dense_read),
        .img_data_o(conv_img),
        .img_out_valid_o(conv_img_valid),
        .done_o(conv_done_top_o),
        .conv_busy_o(conv_busy_top_o),
        .conv_debug_o(conv_debug_o)
    );

    dense dense_inst(
        .clk(clk),
        .rst_n(rst_n),
        .img_data_i(conv_img),
        .img_data_valid_i(conv_img_valid),
        .read_result_i(read_result_top_i),
        .img_data_read_o(dense_read),
        .done_o(dense_done_top_o),
        .result_o(result_top_o),
        .dense_debug_o(dense_debug_o)
    );


endmodule
