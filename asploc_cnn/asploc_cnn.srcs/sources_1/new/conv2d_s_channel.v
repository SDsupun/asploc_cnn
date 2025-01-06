`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/12/2024 11:51:32 AM
// Design Name: asploc_cnn
// Module Name: conv2d_s_channel
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: A single channel convolution hardware for LeNet.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module conv2d_s_channel(
    input clk,
    input rst_n,
    input [239:0] img_data_i,
    input img_in_valid_i,
    output [4:0] channel_code_o,
    output kernal_w_o,
    output [9:0] img_addr,
    output img_data_en_o,
    output img_data_rw_o,
    output [95:0] img_data_o
    );

    localparam K_SIZE = 150;
    localparam K_DIME = 5;

    localparam CONV_1_IMG_DIM = 32;
    localparam CONV_2_IMG_DIM = 14;
    localparam CONV_1_IN__CHN = 1;
    localparam CONV_2_IN__CHN = 6;
    localparam CONV_1_OUT_CHN = 6;
    localparam CONV_2_OUT_CHN = 16;
    localparam MEMDATA_WIDTH = 8;

    localparam CHN_COUNT = 5'h11;

    localparam S_LOAD_KERNAL = 3'b001;
    localparam S_CALC_CONV_1 = 3'b010;
    localparam S_CALC_CONV_2 = 3'b100;


    reg [4:0] channel_code;
    reg [4:0] img_i;
    reg [4:0] img_j;
    reg [2:0] cnv_i;
    reg [2:0] chn_i;

    reg kernal_w;
    reg kernal_w_d1;

    reg img_data_en;
    reg img_data_rw;

    reg [2:0] current_state;
    reg [2:0] next_state;
    reg signed [15:0] channel_in_out [0:CONV_1_OUT_CHN-1];
    reg [95:0] img_data_o_reg;
    reg [9:0] img_addr_reg;
    
    reg signed [7:0] chn_kernal[0:K_SIZE-1];
    reg kernal_en;
    reg [7:0] kernal_addr;
    reg kernal_en_d1;
    reg [7:0] kernal_addr_d1;
    wire [7:0] kernal_data;

    wire signed [15:0] channel_in_out_w [0:CONV_1_OUT_CHN-1];
    wire signed [15:0] channel_sum;


    integer j;
    genvar k;

    bram #(
        .SIZE(K_SIZE*CHN_COUNT),
        .SIZE_LOG(12),
        .DATA_WIDTH(MEMDATA_WIDTH),
        .MEM_INIT_FILE("conv_weight.mem")) 
    conv_weight(
        .clk(clk),
        .rst_n(rst_n),
        .en(kernal_en),
        .rw(1'b0),
        .addr(kernal_addr),
        .data_in(),
        .data_out(kernal_data)
    );

    for (k = 0; k < CONV_1_OUT_CHN; k = k+1) begin
        assign channel_in_out_w[k] = channel_in_out[k];
    end
    
    assign channel_sum = channel_in_out_w[0] + channel_in_out_w[1] 
                        + channel_in_out_w[2] + channel_in_out_w[3] 
                        + channel_in_out_w[4] + channel_in_out_w[5];
    assign channel_code_o = channel_code;
    assign kernal_w_o = kernal_w;
    assign img_data_o = (channel_code == 5'h01)? img_data_o_reg: {80'h0, channel_sum};
    assign img_data_en_o = (img_data_en && img_in_valid_i);
    assign img_data_rw_o = (img_data_rw && img_in_valid_i);
    assign img_addr = img_addr_reg;
    
    integer i;
    initial begin
        for(i = 0; i < K_SIZE; i = i+1)
            chn_kernal[i] <= 0;
        
        for(i = 0; i < CONV_2_OUT_CHN; i = i+1)
            channel_in_out[i] <= 16'h0;
    end
    

    // Load kernals
    always @(posedge clk) begin
        if (kernal_en_d1 && kernal_w) begin
            chn_kernal[kernal_addr_d1] <= kernal_data;
        end
    end

    // trigger kernal load signals
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            kernal_en <= 0;
            kernal_addr <= 0;
            kernal_en_d1 <= 0;
            kernal_addr_d1 <= 0;
        end else begin
            kernal_en_d1 <= kernal_en;
            kernal_addr_d1 <= kernal_addr;
            if ((current_state == S_LOAD_KERNAL) && (channel_code != 0)) begin
                kernal_en <= 1'b1;
                kernal_addr <= (channel_code-1)*K_SIZE + img_i*K_DIME + img_j;
            end else begin
                kernal_en <= 0;
                kernal_addr <= 0;
            end
        end
    end

    // update current state
    always @(posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            current_state <= S_LOAD_KERNAL;
        end else begin
            current_state <= next_state;
        end
    end

    // next state
    always @(channel_code, kernal_en, kernal_w) begin
        case (current_state)
            S_LOAD_KERNAL: begin
                if (kernal_w) begin
                    next_state = S_LOAD_KERNAL;
                end else begin
                    if (channel_code == 5'b0_0001) begin
                        next_state = S_CALC_CONV_1;
                    end else begin
                        next_state = S_CALC_CONV_2;
                    end
                end
            end 
            S_CALC_CONV_1: begin
                if (kernal_w) begin
                    next_state = S_LOAD_KERNAL;
                end else begin
                    next_state = S_CALC_CONV_1;
                end
            end
            S_CALC_CONV_2: begin
                if (kernal_w) begin
                    next_state = S_LOAD_KERNAL;
                end else begin
                    next_state = S_CALC_CONV_2;
                end
            end
            default: 
                next_state = S_LOAD_KERNAL;
        endcase
    end

    // update kernal code
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            channel_code <= 5'h1;
        end else begin
            if(kernal_w && ~kernal_w_d1) begin
                if(channel_code == CHN_COUNT) begin
                    channel_code <= 5'h0;
                end else begin
                    channel_code <= channel_code + 5'h1;
                end
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
            kernal_w <= 1'b1;
            kernal_w_d1 <= 1'b1;
        end else begin

            kernal_w_d1 <= kernal_w;

            if ((current_state == S_CALC_CONV_1) && img_in_valid_i) begin
                if (cnv_i == K_DIME-1) begin
                    cnv_i <= 3'h0;
                end else begin
                    cnv_i <= cnv_i + 3'h1;
                end

                if ((img_j == CONV_1_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                    img_j <= 5'h0;
                end else begin
                    if (cnv_i == K_DIME-1) begin
                        img_j <= img_j + 5'h1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_1_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    img_i <= 5'h0;
                    kernal_w <= 1'b1;
                end else begin
                    kernal_w <= kernal_w;
                    if ((img_j == CONV_1_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end
            end 
            else if((current_state == S_CALC_CONV_2) && img_in_valid_i) begin
                if (cnv_i == K_DIME-1) begin
                    cnv_i <= 3'h0;
                end else begin
                    cnv_i <= cnv_i + 3'h1;
                end

                if ((img_j == CONV_1_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                    img_j <= 5'h0;
                end else begin
                    if (cnv_i == K_DIME-1) begin
                        img_j <= img_j + 5'h1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_1_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    img_i <= 5'h0;
                end else begin
                    if ((img_j == CONV_1_IMG_DIM - K_DIME - 1) && (cnv_i == K_DIME-1)) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end

                if ((chn_i == CONV_2_IN__CHN-1)
                    && (img_i == CONV_1_IMG_DIM - K_DIME - 1) 
                    && (img_j == CONV_1_IMG_DIM - K_DIME - 1)
                    && (cnv_i == K_DIME-1)) begin
                    chn_i <= 3'h0;
                    kernal_w <= 1'b1;
                end else begin
                    kernal_w <= kernal_w;
                    if ((img_i == CONV_1_IMG_DIM - K_DIME - 1) 
                        && (img_j == CONV_1_IMG_DIM - K_DIME - 1)
                        && (cnv_i == K_DIME-1)) begin
                        chn_i <= chn_i + 3'h1;
                    end else begin
                        chn_i <= chn_i;
                    end
                end
            end
            else if (current_state == S_LOAD_KERNAL) begin
                if (img_j == K_DIME - 1) begin
                    img_j <= 5'h0;
                end else begin
                    img_j <= img_j + 5'h1;
                end

                if ((img_i == K_DIME*CONV_1_OUT_CHN - 1) && (img_j == K_DIME - 1)) begin
                    img_i <= 5'h0;
                end else begin
                    if (img_j == K_DIME - 1) begin
                        img_i <= img_i + 5'h1;
                    end else begin
                        img_i <= img_i;
                    end
                end
                if ((kernal_addr == K_SIZE -1) 
                    && (kernal_en)) begin
                    kernal_w <= 1'b0;
                end else begin
                    kernal_w <= kernal_w;
                end
            end
            else begin
                img_i <= 5'h0;
                img_j <= 5'h0;
                cnv_i <= 3'h0;
                chn_i <= 3'h0;
                if ((kernal_addr == K_SIZE -1) 
                    && (kernal_en)) begin
                    kernal_w <= 1'b0;
                end else begin
                    kernal_w <= kernal_w;
                end
            end
        end
    end

    // convolution
    always @(posedge clk) begin
        if (current_state == S_CALC_CONV_1) begin
            if (cnv_i == 3'h0) begin
                for (j = 0; j < CONV_1_OUT_CHN; j = j+1) begin
                    channel_in_out[j] <= img_data_i[ 7:0 ]*chn_kernal[K_DIME*K_DIME*j + 0] 
                                       + img_data_i[15:8 ]*chn_kernal[K_DIME*K_DIME*j + 1]
                                       + img_data_i[23:16]*chn_kernal[K_DIME*K_DIME*j + 2]
                                       + img_data_i[31:24]*chn_kernal[K_DIME*K_DIME*j + 3]
                                       + img_data_i[39:32]*chn_kernal[K_DIME*K_DIME*j + 4];
                    img_data_o_reg[16*j +:16] <= channel_in_out[j];
                    img_addr_reg <= img_addr_reg;
                    img_data_rw <= 1'b1;
                    img_data_en <= 1'b1;
                end
            end else if (cnv_i == K_DIME-1) begin
                for (j = 0; j < CONV_1_OUT_CHN; j = j+1) begin
                    channel_in_out[j] <= channel_in_out[j]
                                + img_data_i[ 7:0 ]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 0] 
                                + img_data_i[15:8 ]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 1]
                                + img_data_i[23:16]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 2]
                                + img_data_i[31:24]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 3]
                                + img_data_i[39:32]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 4];
                    img_data_o_reg <= img_data_o_reg;
                    img_addr_reg <= img_i*(CONV_1_IMG_DIM - K_DIME) + img_j;
                    img_data_rw <= 1'b0;
                    img_data_en <= 1'b0;
                end
            end else begin
                for (j = 0; j < CONV_1_OUT_CHN; j = j+1) begin
                    channel_in_out[j] <= channel_in_out[j]
                                + img_data_i[ 7:0 ]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 0] 
                                + img_data_i[15:8 ]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 1]
                                + img_data_i[23:16]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 2]
                                + img_data_i[31:24]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 3]
                                + img_data_i[39:32]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 4];
                    img_data_o_reg <= img_data_o_reg;
                    img_addr_reg <= img_addr_reg;
                    img_data_rw <= 1'b0;
                    img_data_en <= 1'b0;
                end
            end
        end 
        else if(current_state == S_CALC_CONV_2) begin
            if (cnv_i == 3'b0) begin
                for (j = 0; j < CONV_2_IN__CHN; j = j+1) begin
                    channel_in_out[j] <= img_data_i[(40*j     ) +: 8]*chn_kernal[K_DIME*K_DIME*j + 0] 
                                       + img_data_i[(40*j +  8) +: 8]*chn_kernal[K_DIME*K_DIME*j + 1]
                                       + img_data_i[(40*j + 16) +: 8]*chn_kernal[K_DIME*K_DIME*j + 2]
                                       + img_data_i[(40*j + 24) +: 8]*chn_kernal[K_DIME*K_DIME*j + 3]
                                       + img_data_i[(40*j + 32) +: 8]*chn_kernal[K_DIME*K_DIME*j + 4];
                    img_data_o_reg[16*j +:16] <= channel_in_out[j];
                    img_addr_reg <= img_addr_reg;
                    img_data_rw <= 1'b1;
                    img_data_en <= 1'b1;
                end
            end else if (cnv_i == K_DIME-1) begin
                for (j = 0; j < CONV_2_IN__CHN; j = j+1) begin
                    channel_in_out[j] <= channel_in_out[j]
                            + img_data_i[(40*j     ) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 0] 
                            + img_data_i[(40*j +  8) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 1]
                            + img_data_i[(40*j + 16) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 2]
                            + img_data_i[(40*j + 24) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 3]
                            + img_data_i[(40*j + 32) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 4];
                    img_data_o_reg <= img_data_o_reg;
                    img_addr_reg <= img_i*(CONV_1_IMG_DIM - K_DIME) + img_j;
                    img_data_rw <= 1'b0;
                    img_data_en <= 1'b0;
                end
            end else begin
                for (j = 0; j < CONV_2_IN__CHN; j = j+1) begin
                    channel_in_out[j] <= channel_in_out[j]
                            + img_data_i[(40*j     ) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 0] 
                            + img_data_i[(40*j +  8) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 1]
                            + img_data_i[(40*j + 16) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 2]
                            + img_data_i[(40*j + 24) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 3]
                            + img_data_i[(40*j + 32) +: 8]*chn_kernal[K_DIME*K_DIME*j + K_DIME*cnv_i + 4];
                    img_data_o_reg <= img_data_o_reg;
                    img_addr_reg <= img_addr_reg;
                    img_data_rw <= 1'b0;
                    img_data_en <= 1'b0;
                end
            end
        end
    end


endmodule
