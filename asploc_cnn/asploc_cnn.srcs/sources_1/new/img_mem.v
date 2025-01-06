`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/14/2024 08:21:50 PM
// Design Name: asploc_cnn
// Module Name: img_mem
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: convolutional data stored here
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module img_mem(
    input clk,
    input rst_n,
    input [9:0] img_addr,
    input [4:0] chn_code,
    input [47:0] img_data_i,
    input load_sw_img_i,
    input img_data_en_i,
    input img_data_rw_i,
    input kernal_w_i,
    input bias_w_i,
    input dense_read_i,
    output read_sw_img_o,
    output [239:0] img_data_o,
    output img_data_valid_o,
    output dense_valid_o
    );

    localparam IMG_SIZE    = 1200;
    localparam SW_IMG_SIZE = 32*32;

    localparam S_ACTIVE_OUT_1  = 5'b00001;
    localparam S_ACTIVE_OUT_2  = 5'b00010;
    localparam S_ACTIVE_IN_SW  = 5'b00100;
    localparam S_IDLE          = 5'b01000;
    localparam S_ACTIVE_FS_OUT = 5'b10000;
    
    localparam K_DIME = 5;

    localparam CONV_1_IN_IMG_DIM = 32;
    localparam CONV_2_IN_IMG_DIM = 14;
    localparam CONV_1_OUT_IMG_DIM = 27;
    localparam CONV_2_OUT_IMG_DIM = 9;
    localparam DENS_IN_IMG_DIM = 5;
    localparam CONV_1_IN__CHN = 1;
    localparam CONV_2_IN__CHN = 6;
    localparam CONV_1_OUT_CHN = 6;
    localparam CONV_2_OUT_CHN = 16;
    localparam CHN_COUNT = 5'h11;
    
    localparam CONV_2_IMG_SIZE = CONV_2_IN_IMG_DIM * CONV_2_IN_IMG_DIM;
    localparam DENS_IN_IMG_SIZE = DENS_IN_IMG_DIM * DENS_IN_IMG_DIM;


    reg [4:0] current_state;
    reg [4:0] next_state;
    reg [5:0] img_i;
    reg [5:0] img_j;
    reg [3:0] cnv_i;
    reg [3:0] chn_i;
    reg [239:0] img_data;
    reg [4:0] chn_img_i;
    reg [4:0] chn_img_j;
    reg read_sw_img;

    integer j;
    integer i;

    assign img_data_o = img_data;
    assign img_data_valid_o = (current_state == S_ACTIVE_OUT_1) 
                            || (current_state == S_ACTIVE_OUT_2);
    assign dense_valid_o = (current_state == S_ACTIVE_FS_OUT);
    assign read_sw_img_o = read_sw_img;

    reg [7:0] img_1[0:IMG_SIZE-1];
    reg [7:0] img_2[0:IMG_SIZE-1];
    
    initial begin
        for(i = 0; i < IMG_SIZE; i = i+1)
        begin
            img_1[i] <= 0;
            img_2[i] <= 0;
        end
        chn_img_i <= 5'h0;
        chn_img_j <= 5'h0;
    end

    // assign current state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_ACTIVE_IN_SW;
        end else begin
            current_state <= next_state;
        end
    end

    // assign next state
    always @(load_sw_img_i, img_addr, kernal_w_i, bias_w_i, read_sw_img, chn_code) begin
        case (current_state)
            S_ACTIVE_IN_SW: begin
                if (load_sw_img_i && (img_addr*6 > SW_IMG_SIZE)) begin // 6 data at a time
                    next_state = S_IDLE;
                end else begin
                    if (~load_sw_img_i) begin
                        next_state = S_IDLE;
                    end else begin
                        next_state = current_state;
                    end
                end
            end
            S_ACTIVE_OUT_1: begin
                if (load_sw_img_i && ~read_sw_img) begin
                    next_state = S_ACTIVE_IN_SW;
                end else begin
                    if (kernal_w_i | bias_w_i) begin
                        next_state = S_IDLE;
                    end else begin
                        next_state = current_state;
                    end
                end
            end
            S_ACTIVE_OUT_2: begin
                if (load_sw_img_i && ~read_sw_img) begin
                    next_state = S_ACTIVE_IN_SW;
                end else begin
                    if (kernal_w_i | bias_w_i) begin
                        next_state = S_IDLE;
                    end else if (chn_code == CHN_COUNT) begin
                        next_state = S_ACTIVE_FS_OUT;
                    end else begin
                        next_state = current_state;
                    end
                end
            end
            S_ACTIVE_FS_OUT: begin
                if (~dense_read_i) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = current_state;
                end
            end
            S_IDLE: begin
                if (load_sw_img_i && ~read_sw_img) begin
                    next_state = S_ACTIVE_IN_SW;
                end else begin
                    if (~kernal_w_i & ~bias_w_i) begin
                        if (chn_code[0] == 1'b1) begin
                            next_state = S_ACTIVE_OUT_1;
                        end else begin
                            next_state = S_ACTIVE_OUT_2;
                        end
                    end else begin
                        next_state = current_state;
                    end
                end
            end
            default: next_state = S_ACTIVE_IN_SW;
        endcase
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            read_sw_img <= 1'b0;
        end else begin
            if (current_state == S_ACTIVE_IN_SW) begin
                read_sw_img <= 1'b1;
            end else begin
                read_sw_img <= 1'b0;
            end
        end
    end

    // generate image address
    always @(posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            img_i <= 5'h0;
            img_j <= 5'h0;
            cnv_i <= 3'h0;
            chn_i <= 3'h0;
        end else begin

            if (((current_state != S_IDLE) 
            && (current_state != S_ACTIVE_FS_OUT)) 
            && (chn_code == 5'h01)) begin
                if (cnv_i == K_DIME-1) begin
                    cnv_i <= 3'h0;
                end else begin
                    cnv_i <= cnv_i + 3'h1;
                end

                if ((img_j == CONV_1_IN_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                    img_j <= 5'h0;
                end else begin
                    if (cnv_i == K_DIME-1) begin
                        img_j <= img_j + 5'h1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_1_IN_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IN_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    img_i <= 5'h0;
                end else begin
                    if ((img_j == CONV_1_IN_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end
            end 
            else if(((current_state != S_IDLE) 
            && (current_state != S_ACTIVE_FS_OUT)) 
            && (chn_code > 5'h01)) begin
                if (cnv_i == K_DIME-1) begin
                    cnv_i <= 3'h0;
                end else begin
                    cnv_i <= cnv_i + 3'h1;
                end

                if ((img_j == CONV_1_IN_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                    img_j <= 5'h0;
                end else begin
                    if (cnv_i == K_DIME-1) begin
                        img_j <= img_j + 5'h1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_1_IN_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IN_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    img_i <= 5'h0;
                end else begin
                    if ((img_j == CONV_1_IN_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end

                if ((chn_i == CONV_2_IN__CHN-1)
                    && (img_i == CONV_1_IN_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IN_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    chn_i <= 3'h0;
                end else begin
                    if ((img_i == CONV_1_IN_IMG_DIM - K_DIME - 1) 
                        && (img_j == CONV_1_IN_IMG_DIM - K_DIME - 1)
                        && (cnv_i == K_DIME-1)) begin
                        chn_i <= chn_i + 3'h1;
                    end else begin
                        chn_i <= chn_i;
                    end
                end
            end
            else if ((current_state == S_ACTIVE_FS_OUT) && dense_read_i) begin

                if (img_j == DENS_IN_IMG_DIM - 1) begin
                    img_j <= 5'h0;
                end else begin
                    img_j <= img_j + 5'h1;
                end

                if ((img_i == DENS_IN_IMG_DIM - 1) 
                    && (img_j == DENS_IN_IMG_DIM - 1)) begin
                    img_i <= 5'h0;
                end else begin
                    if (img_j == DENS_IN_IMG_DIM - 1) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end

                if ((chn_i == CONV_2_IN__CHN-1)
                    && (img_i == DENS_IN_IMG_DIM - 1) 
                    && (img_j == DENS_IN_IMG_DIM - 1)) begin
                    chn_i <= 3'h0;
                end else begin
                    if ((img_i == DENS_IN_IMG_DIM - 1) 
                        && (img_j == DENS_IN_IMG_DIM - 1)) begin
                        chn_i <= chn_i + 3'h1;
                    end else begin
                        chn_i <= chn_i;
                    end
                end
            end
            else begin
                img_i <= 5'h0;
                img_j <= 5'h0;
                cnv_i <= 3'h0;
                chn_i <= 3'h0;
            end
        end
    end


    // generate the data
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            img_data <= 240'h0;
        end else begin
            if ((current_state == S_ACTIVE_OUT_1) || (current_state == S_ACTIVE_OUT_2)) begin
                if (chn_code == 5'h01) begin
                    for (i = 0; i < K_DIME ; i = i+1) begin
                        img_data[i*8 +: 8] <= img_1[i 
                                                + (CONV_1_IN_IMG_DIM*cnv_i 
                                                + CONV_1_IN_IMG_DIM*img_i + img_j)];
                    end
                end 
                else if (current_state == S_ACTIVE_FS_OUT) begin
                    img_data[8:0] <= img_1[chn_i*DENS_IN_IMG_SIZE + img_i*DENS_IN_IMG_DIM + img_j];
                end
                else begin
                    for (j = 0; j < CONV_2_IN__CHN; j = j+1) begin
                        for (i = 0; i < K_DIME ; i = i+1) begin
                            if (current_state == S_ACTIVE_OUT_1) begin
                                img_data[(i*8 + j*CONV_2_IN_IMG_DIM) +: 8] <= img_1[i 
                                                        + j*CONV_2_IN_IMG_DIM
                                                        + (CONV_1_IN_IMG_DIM*cnv_i 
                                                        + CONV_1_IN_IMG_DIM*img_i + img_j)];
                            end else begin
                                img_data[(i*8 + j*CONV_2_IN_IMG_DIM) +: 8] <= img_2[i 
                                                        + j*CONV_2_IN_IMG_DIM
                                                        + (CONV_1_IN_IMG_DIM*cnv_i 
                                                        + CONV_1_IN_IMG_DIM*img_i + img_j)];
                            end
                        end
                    end
                end
            end else begin
                img_data <= 240'h0;
            end
        end
    end

    // save data
    always @(posedge clk) begin
        if (current_state == S_ACTIVE_IN_SW) begin
            for (i = 0; i < 6; i = i+1) begin
                img_1[img_addr*6+i] <= img_data_i[i*8 +: 8];
            end
        end else if ((current_state != S_IDLE) && img_data_rw_i) begin
            if (chn_code == 5'h01) begin
                if (img_addr == 10'h0) begin
                    chn_img_i <= 5'h0;
                    chn_img_j <= 5'h0;
                end else begin
                    if (chn_img_j == CONV_1_OUT_IMG_DIM-1) begin
                        chn_img_j <= 5'h0;
                        chn_img_i <= chn_img_i + 1;
                    end else begin
                        chn_img_j <= chn_img_j + 1;
                        chn_img_i <= chn_img_i;
                    end
                end
                for (i = 0; i < CONV_1_OUT_CHN; i = i+1) begin
                    // maxpool
                    // check for odd column addresses 
                    if (chn_img_j[0]== 1'b1) begin
                        if (img_2[CONV_2_IMG_SIZE * i 
                            + CONV_2_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                < img_data_i[i*8 +: 8]) begin

                            img_2[CONV_2_IMG_SIZE * i 
                                + CONV_2_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                    <= img_data_i[i*8 +: 8];
                        end
                    end 
                    // check for odd row addresses
                    else if(chn_img_i[0]== 1'b1) begin
                        if (img_2[CONV_2_IMG_SIZE * i 
                            + CONV_2_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                < img_data_i[i*8 +: 8]) begin

                            img_2[CONV_2_IMG_SIZE * i 
                                + CONV_2_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                    <= img_data_i[i*8 +: 8];
                        end
                    end
                    else begin
                        img_2[CONV_2_IMG_SIZE * i 
                                + CONV_2_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                    <= img_data_i[i*8 +: 8];
                    end
                end
            end else begin
                if (img_addr == 10'h0) begin
                    chn_img_i <= 5'h0;
                    chn_img_j <= 5'h0;
                end else begin
                    if (chn_img_j == CONV_2_OUT_IMG_DIM-1) begin
                        chn_img_j <= 5'h0;
                        chn_img_i <= chn_img_i + 1;
                    end else begin
                        chn_img_j <= chn_img_j + 1;
                        chn_img_i <= chn_img_i;
                    end
                end
                
                // maxpool
                // check for odd column addresses 
                if (chn_img_j[0]== 1'b1) begin
                    if (img_1[DENS_IN_IMG_SIZE * i 
                        + DENS_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                            < img_data_i[8:0]) begin

                        img_1[DENS_IN_IMG_SIZE * i 
                            + DENS_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                <= img_data_i[8:0];
                    end
                end 
                // check for odd row addresses
                else if(chn_img_i[0]== 1'b1) begin
                    if (img_1[DENS_IN_IMG_SIZE * i 
                        + DENS_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                            < img_data_i[8:0]) begin

                        img_1[DENS_IN_IMG_SIZE * i 
                            + DENS_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                <= img_data_i[8:0];
                    end
                end
                else begin
                    img_1[DENS_IN_IMG_SIZE * i 
                            + DENS_IN_IMG_DIM * (chn_img_i >> 2) + (chn_img_j >> 2)] 
                                <= img_data_i[8:0];
                end
            end
        end
    end


endmodule
