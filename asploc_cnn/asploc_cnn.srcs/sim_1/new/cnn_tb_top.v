`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/27/2024 07:09:35 AM
// Design Name: 
// Module Name: cnn_tb_top
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


module cnn_tb_top(

    );

    reg clk;
    reg rst_n;
    reg [7:0] img_data;
    reg load_sw_img;
    reg read_result;

    wire cnv_busy;
    wire cnv_done;
    wire den_done;
    wire [3:0] result;
    reg [7:0] image [0:1023];

    integer i;

    asploc_cnn_top asploc_cnn_top_inst(
        .clk(clk),
        .rst_n(rst_n),
        .img_data_top_i(img_data),
        .load_sw_img_top_i(load_sw_img),
        .read_result_top_i(read_result),
        .conv_busy_top_o(cnv_busy),
        .conv_done_top_o(cnv_done),
        .dense_done_top_o(den_done),
        .result_top_o(result)
    );

    initial begin
        
        $readmemh("image.txt", image);
        clk = 1;
        rst_n = 0;
        img_data = 0;
        load_sw_img = 0;
        read_result = 0;
        #10
        rst_n = 1;
        #10;

        load_sw_img = 1;
        for (i = 0; i<32*32; i=i+1) begin
            // img_data = 100;
            img_data = image[i];
            $display(img_data);
            #2;
        end
        #2;
        load_sw_img = 0;
        while (~den_done) begin
            #2;
        end
        #20;
        read_result = 1;
        #20;
        read_result = 0;
        #20;
        
        load_sw_img = 1;
        for (i = 0; i<32*32; i=i+1) begin
            // img_data = 100;
            img_data = image[i];
            // $display(img_data);
            #2;
        end
        #2;
        load_sw_img = 0;
        while (~den_done) begin
            #2;
        end
        #20;
        read_result = 1;
        #20;
        read_result = 0;
        #20;
        
        load_sw_img = 1;
        for (i = 0; i<32*32; i=i+1) begin
            // img_data = 100;
            img_data = image[i];
            // $display(img_data);
            #2;
        end
        #2;
        load_sw_img = 0;
        while (~den_done) begin
            #2;
        end
        #20;
        read_result = 1;
        #20;
        read_result = 0;
        #20;
        
        load_sw_img = 1;
        for (i = 0; i<32*32; i=i+1) begin
            // img_data = 100;
            img_data = image[i];
            // $display(img_data);
            #2;
        end
        #2;
        load_sw_img = 0;
        while (~den_done) begin
            #2;
        end
        #20;
        read_result = 1;
        #20;
        read_result = 0;
        #20;
        
        load_sw_img = 1;
        for (i = 0; i<32*32; i=i+1) begin
            // img_data = 100;
            img_data = image[i];
            // $display(img_data);
            #2;
        end
        #2;
        load_sw_img = 0;
        while (~den_done) begin
            #2;
        end
    end
    
    always begin
        #1 clk = ~clk;
    end
endmodule
