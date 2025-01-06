`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/13/2024 04:21:44 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top(

    );

    reg clk;
    reg rst_n;
    reg [7:0] kernal_data;
    reg [7:0] kernal_addr;
    reg kernal_en;
    reg [239:0] img_data_i;
    reg load_sw_img;
    reg [7:0] den_img_i;
    reg den_img_v;
    reg den_rd_r;

    reg [7:0] bias_data;
    reg [4:0] bias_addr;
    reg bias_en;
    reg [9:0] img_addr_sw;
    reg [47:0] img_data_sw;

    wire [9:0] img_addr;
    wire img_data_en_o;
    wire img_data_rw_o;
    wire [95:0] img_data_o;
    wire [4:0] channel_code_o;
    wire kernal_w_o;
    wire [47:0] img_data_relu_o;
    wire kernal_w_tb_top;
    wire den_data_rd;
    wire den_done;
    wire [9:0] den_result;

    reg [7:0] conv_img_sw;
    reg conv_img_valid;
    wire [7:0] conv_img_o;
    wire conv_done;

    wire bias_w;

    integer i;
    integer j;

    // asploc_cnn_top asploc_cnn_top_inst(
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .img_addr_top_i(img_addr_sw),
    //     .img_data_top_i(img_data_sw),
    //     .load_sw_img_top_i(load_sw_img),
    //     .kernal_data_top_i(kernal_data),
    //     .kernal_addr_top_i(kernal_addr),
    //     .kernal_en_top_i(kernal_en),
    //     .bias_data_top_i(bias_data),
    //     .bias_addr_top_i(bias_addr),
    //     .bias_en_top_i(bias_en),
    //     .kernal_w_top_o(kernal_w_tb_top)
    // );

    dense dense_inst(
        .clk(clk),
        .rst_n(rst_n), 
        .img_data_i(den_img_i),
        .img_data_valid_i(den_img_v),
        .read_result_i(den_rd_r),
        .img_data_read_o(den_data_rd),
        .done_o(den_done),
        .result_o(den_result)
    );

    conv2d conv2d_inst(
        .clk(clk),
        .rst_n(rst_n),
        .img_data_i(conv_img_sw),
        .img_in_valid_i(conv_img_valid),
        .read_result_i(1'b0),
        .img_data_o(conv_img_o),
        .img_out_valid_o(),
        .done_o(conv_done),
        .conv_busy_o()
    );

    initial begin
        clk = 1;
        rst_n = 0;
        #10
        rst_n = 1;
        den_img_i = 0;
        #10;
        den_img_v = 1;
        for (i = 0; i<400*120; i=i+1) begin
            // den_img_i = (den_img_i>60)? 0:den_img_i+1;
            den_img_i = 1;
            #2;
            while (~den_data_rd) begin
                #2;
            end
        end
        den_img_v = 0;
        #2;
        while (~den_done) begin
            #2;
        end
        #200;
        ////

        // conv_img_valid = 1;
        // for (i = 0; i<32*32; i=i+1) begin
        //     // den_img_i = (den_img_i>60)? 0:den_img_i+1;
        //     conv_img_sw = 40;
        //     #2;
        // end
        // #2;
        // conv_img_valid = 0;
        // while (~conv_done) begin
        //     #2;
        // end

        ////
        // load_sw_img = 1;
        // img_addr_sw = 0;
        // for (i = 0; i < 172; i = i+1) begin
        //     img_addr_sw = i;
        //     for (j = 0; j < 6; j = j+1) begin
        //         img_data_sw[8*j +: 8] = $urandom;
        //     end
        //     #2;
        // end
        // load_sw_img = 0;
        // #10;
        // kernal_en = 1;
        // for (i = 0; i < 150; i = i + 1) begin
        //     kernal_data = -1;
        //     kernal_addr = i;
        //     #2;
        // end
        // kernal_en = 0;
        // bias_en = 1;
        // for (i = 0; i < 22; i = i + 1) begin
        //     bias_data = $urandom;
        //     bias_addr = i;
        //     #2;
        // end
        // bias_en = 0;
        // #100
        // while (~kernal_w_tb_top) begin 
        //     #2;
        // end
        // kernal_en = 1;
        // for (i = 0; i < 150; i = i + 1) begin
        //     kernal_data = 1;
        //     kernal_addr = i;
        //     #2;
        // end
        // kernal_en = 0;
    end

    always begin
        #1 clk = ~clk;
    end
endmodule
