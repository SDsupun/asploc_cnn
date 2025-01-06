`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/12/2024 11:51:32 AM
// Design Name: asploc_cnn
// Module Name: conv2d
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


module conv2d(
    input clk,
    input rst_n,
    input [7:0] img_data_i,
    input img_in_valid_i,
    input read_result_i,
    output [7:0] img_data_o,
    output img_out_valid_o,
    output done_o,
    output conv_busy_o,
    output [7:0] conv_debug_o
    );

    localparam K_SIZE = 150;
    localparam K_DIME = 5;

    localparam CONV_1_IMG_DIM = 32;
    localparam CONV_2_IMG_DIM = 14;
    localparam CONV_1_OUT_DIM = 27;
    localparam CONV_2_OUT_DIM = 9;
    localparam CONV_OUT_IMDIM = 5;
    localparam CONV_1_IN__CHN = 1;
    localparam CONV_2_IN__CHN = 6;
    localparam CONV_1_OUT_CHN = 6;
    localparam CONV_2_OUT_CHN = 16;
    localparam MEMDATA_WIDTH = 8;
    localparam MAX_POOL_DIM  = 2;

    localparam CHN_COUNT = 5'h12;

    localparam S_IDLE        = 7'b000_0001;
    localparam S_LOAD_IMG_SW = 7'b000_0010;
    localparam S_LOAD_KERNAL = 7'b000_0100;
    localparam S_CALC_CONV_1 = 7'b000_1000;
    localparam S_CALC_CONV_2 = 7'b001_0000;
    localparam S_MAX_POOL    = 7'b010_0000;
    localparam S_OUT_DATA    = 7'b100_0000;


    reg [4:0] channel_code;
    reg [4:0] img_i;
    reg [4:0] img_i_d1;
    reg [4:0] img_i_d2;
    reg [4:0] img_j;
    reg [4:0] img_j_d1;
    reg [4:0] img_j_d2;
    reg [2:0] img_k;
    reg [2:0] img_k_d1;
    reg [2:0] img_k_d2;
    reg [2:0] cnv_i;
    reg [2:0] cnv_j;
    reg [4:0] chn_i;
    reg [4:0] chn_i_d1;
    reg [4:0] chn_i_d2;

    reg [4:0] cnv_addr;

    reg kernal_w;
    reg kernal_w_d1;

    reg [6:0] current_state;
    reg [6:0] next_state;
    
    reg signed [7:0] chn_kernal[0:K_SIZE-1];

    reg kernal_en;
    reg [11:0] kernal_addr;
    wire signed [7:0] kernal_data;
    reg kernal_en_d1;
    reg [11:0] kernal_addr_d1;
    
    wire bias_en;
    wire [4:0] bias_addr;
    wire signed [7:0] bias_data;

    wire img_1_en;
    wire img_1_rw;
    wire [10:0] img_1_addr;
    wire [MEMDATA_WIDTH-1:0] img_1_data_in;
    wire signed [MEMDATA_WIDTH-1:0] img_1_data_out;

    wire img_2_en;
    wire img_2_rw;
    wire [12:0] img_2_addr;
    wire [MEMDATA_WIDTH-1:0] img_2_data_in;
    wire signed [MEMDATA_WIDTH-1:0] img_2_data_out;

    reg signed [15:0] conv_cell_data [0:CONV_1_OUT_CHN-1];
    wire signed [15:0] conv_round_data [0:CONV_1_OUT_CHN-1];
    wire signed [15:0] channel_sum;
    reg [7:0] max_pool_data;
    reg conv_busy;
    reg load_sw_img_done;
    reg load_kernal_done;
    reg max_pool_done;
    reg max_pool_start;
    reg read_result_start;
    reg read_result_done;
    reg conv_2_chn_done;
    

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

    bram #(
        .SIZE(CONV_1_OUT_CHN+CONV_2_OUT_CHN),
        .SIZE_LOG(5),
        .DATA_WIDTH(MEMDATA_WIDTH),
        .MEM_INIT_FILE("conv_bias.mem")) 
    conv_bias(
        .clk(clk),
        .rst_n(rst_n),
        .en(bias_en),
        .rw(1'b0),
        .addr(bias_addr),
        .data_in(),
        .data_out(bias_data)
    );
    
    bram_us #(
        .SIZE((CONV_2_IMG_DIM**2)*CONV_2_IN__CHN), 
        .SIZE_LOG(11),
        .DATA_WIDTH(MEMDATA_WIDTH),
        .MEM_INIT_FILE("image.mem")) 
    img_1(
        .clk(clk),
        .rst_n(rst_n),
        .en(img_1_en),
        .rw(img_1_rw),
        .addr(img_1_addr),
        .data_in(img_1_data_in),
        .data_out(img_1_data_out)
    );

    bram_us #(
        .SIZE(4400), // > CONV_1_OUT_DIM*CONV_1_OUT_DIM*CONV_1_OUT_CHN
        .SIZE_LOG(13),
        .DATA_WIDTH(MEMDATA_WIDTH)) 
    img_2(
        .clk(clk),
        .rst_n(rst_n),
        .en(img_2_en),
        .rw(img_2_rw),
        .addr(img_2_addr),
        .data_in(img_2_data_in),
        .data_out(img_2_data_out)
    );

    assign conv_debug_o = {1'b0, current_state};

    integer i;
    initial begin
        for(i = 0; i < K_SIZE; i = i+1)
            chn_kernal[i] <= 0;
    end

    genvar g;
    for (g = 0; g < CONV_1_OUT_CHN; g=g+1) begin
        assign conv_round_data[g] = (conv_cell_data[g]>0)?conv_cell_data[g]+16'sh007f:0;
    end

    assign channel_sum = conv_cell_data[0] + conv_cell_data[1] + conv_cell_data[2] 
                        + conv_cell_data[3] + conv_cell_data[4] + conv_cell_data[5]
                        + bias_data + 16'sh007f;

    
    assign conv_busy_o = conv_busy;
    assign done_o = (current_state == S_OUT_DATA);

    // generate the memory signals
    assign img_1_en = (|(current_state 
                    & (S_CALC_CONV_1|S_CALC_CONV_2|S_LOAD_IMG_SW|S_MAX_POOL|S_OUT_DATA)));
    assign img_1_rw = (|(current_state & (S_LOAD_IMG_SW|S_MAX_POOL)));
                    // ((current_state == S_LOAD_IMG_SW)
                    // || ((current_state == S_MAX_POOL) && (cnv_i == 1) && (cnv_j == 1)));
    assign img_1_addr = (current_state == S_LOAD_IMG_SW)? CONV_1_IMG_DIM*img_i + img_j:
                        (current_state == S_CALC_CONV_1)? CONV_1_IMG_DIM*(img_i+cnv_i) + img_j+cnv_j:
                        (current_state == S_CALC_CONV_2)? 
                            img_k*(CONV_2_IMG_DIM**2) + CONV_2_IMG_DIM*(img_i+cnv_i) + img_j+cnv_j:
                        
                        ((current_state == S_MAX_POOL) && (channel_code == 2))?
                                chn_i_d2*(CONV_2_IMG_DIM**2) + CONV_2_IMG_DIM*img_i_d2 + img_j_d2:
                        ((current_state == S_MAX_POOL) && (channel_code > 2))?
                                chn_i_d2*(CONV_OUT_IMDIM**2) + CONV_OUT_IMDIM*img_i_d2 + img_j_d2:
                        (current_state == S_OUT_DATA)?
                                chn_i*(CONV_OUT_IMDIM**2) + CONV_OUT_IMDIM*img_i + img_j:0;
    assign img_1_data_in = (current_state == S_LOAD_IMG_SW)? img_data_i:
                            (current_state == S_MAX_POOL)? max_pool_data: 0;

    assign img_2_en = (|(current_state & (S_CALC_CONV_1|S_CALC_CONV_2|S_MAX_POOL)));
    assign img_2_rw = (|(current_state & (S_CALC_CONV_1|S_CALC_CONV_2)));
    assign img_2_addr = (current_state == S_CALC_CONV_1)? 
                                img_k_d2*(CONV_1_OUT_DIM**2)+img_i_d2*CONV_1_OUT_DIM + img_j_d2+1:
                        (current_state == S_CALC_CONV_2)?
                                chn_i_d2*(CONV_2_OUT_DIM**2)+img_i_d2*CONV_2_OUT_DIM + img_j_d2:

                        ((current_state == S_MAX_POOL) && (channel_code == 2))?
                            chn_i*(CONV_1_OUT_DIM**2) + CONV_1_OUT_DIM*(MAX_POOL_DIM*img_i+cnv_i) 
                                + MAX_POOL_DIM*img_j+cnv_j:
                        ((current_state == S_MAX_POOL) && (channel_code > 2))?
                            chn_i*(CONV_2_OUT_DIM**2) + CONV_2_OUT_DIM*(MAX_POOL_DIM*img_i+cnv_i) 
                                + MAX_POOL_DIM*img_j+cnv_j:0;
    assign img_2_data_in = (current_state == S_CALC_CONV_1)? conv_round_data[img_k_d2][15:8]:
                            (current_state == S_CALC_CONV_2)? 
                                (channel_sum > 0)? channel_sum[15:8]: 0:0;

    // bias read signals
    assign bias_en = (|(current_state & (S_CALC_CONV_1|S_CALC_CONV_2)));
    assign bias_addr = (current_state == S_CALC_CONV_1)? img_k:
                        (current_state == S_CALC_CONV_2)? channel_code+CONV_1_OUT_CHN-2:0;

    // output data
    assign img_data_o = (current_state == S_OUT_DATA)? img_1_data_out: 0;
    assign img_out_valid_o = (current_state == S_OUT_DATA);

    // Load kernals
    always @(posedge clk) begin
        if (kernal_en) begin
            chn_kernal[kernal_addr_d1-(channel_code-1)*K_SIZE] <= kernal_data;
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
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            conv_busy <= 1'b0;
        end else begin
            if (current_state == S_CALC_CONV_1) begin
                conv_busy <= 1'b1;
            end else if (current_state == S_IDLE) begin
                conv_busy <= 1'b0;
            end else begin
                conv_busy <= conv_busy;
            end
        end
    end

    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            load_kernal_done <= 1'b0;
        end else begin
            if ((kernal_addr_d1 - (channel_code-1)*K_SIZE == K_SIZE-1)  
            && (current_state == S_LOAD_KERNAL)) begin
                load_kernal_done <= 1'b1;
            end else begin
                load_kernal_done <= 1'b0;
            end 
        end
    end

    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            max_pool_done <= 1'b0;
        end else begin
            if (((current_state == S_MAX_POOL) 
                && (channel_code == 2) 
                && (img_2_addr == (CONV_1_OUT_DIM**2)*CONV_1_OUT_CHN-1))
            || ((current_state == S_MAX_POOL) 
                && (channel_code > 2) 
                && (img_2_addr == (CONV_2_OUT_DIM**2)*CONV_2_OUT_CHN-1))) begin
                max_pool_done <= 1'b1;
            end else begin
                max_pool_done <= 1'b0;
            end 
        end
    end

    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            load_sw_img_done <= 1'b0;
        end else begin
            if ((current_state == S_LOAD_IMG_SW) && img_in_valid_i
                && (img_1_addr == (CONV_1_IMG_DIM**2)-1)) begin
                load_sw_img_done <= 1'b1;
            end else begin
                load_sw_img_done <= 1'b0;
            end 
        end
    end
    
    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            read_result_done <= 1'b0;
        end else begin
            if ((current_state == S_OUT_DATA) && read_result_i
                && (img_1_addr == (CONV_OUT_IMDIM**2)*CONV_2_OUT_CHN-1)) begin
                read_result_done <= 1'b1;
            end else begin
                read_result_done <= 1'b0;
            end 
        end
    end
    
    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            max_pool_start <= 1'b0;
        end else begin
            if ((current_state == S_MAX_POOL) && (img_2_addr == 0) && ~max_pool_start) begin
                max_pool_start <= 1'b1;
            end else if (max_pool_done) begin
                max_pool_start <= 1'b0;
            end else begin
                max_pool_start <= max_pool_start;
            end 
        end
    end
    
    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            read_result_start <= 1'b0;
        end else begin
            if (current_state == S_OUT_DATA) begin
                if (read_result_i) begin
                    read_result_start <= 1'b1;
                end else begin
                    read_result_start <= read_result_start;
                end
            end else begin
                read_result_start <= 1'b0;
            end 
        end
    end
    
    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            conv_2_chn_done <= 1'b0;
        end else begin
            if (current_state == S_CALC_CONV_2) begin
                if ((img_i == CONV_2_OUT_DIM -1)
                    && (img_j == CONV_2_OUT_DIM -1) 
                    && (cnv_i == K_DIME -1) 
                    && (cnv_j == K_DIME -1)
                    && (img_k == CONV_2_IN__CHN -1)) begin
                    conv_2_chn_done <= 1'b1;
                end else begin
                    conv_2_chn_done <= 1'b0;
                end
            end else begin
                conv_2_chn_done <= 1'b0;
            end 
        end
    end

    // generate the conv layer state
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            kernal_w <= 1'b1;
            kernal_w_d1 <= 1'b0;
        end else begin
            kernal_w_d1 <= kernal_w;
            if (current_state == S_CALC_CONV_1) begin
                if((img_i == CONV_1_IMG_DIM - K_DIME -1)
                && (img_j == CONV_1_IMG_DIM - K_DIME -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_1_OUT_CHN-1)) begin
                    kernal_w <= 1'b1;
                end else begin
                    kernal_w <= kernal_w;
                end
            end else if (current_state == S_CALC_CONV_2) begin
                if ((img_i == CONV_2_IMG_DIM - K_DIME -1)
                && (img_j == CONV_2_IMG_DIM - K_DIME -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)) begin
                    kernal_w <= 1'b1;
                end else begin
                    kernal_w <= kernal_w;
                end
            end else begin
                if ((img_i*K_DIME + img_j == K_SIZE-1) 
                && (current_state == S_LOAD_KERNAL)) begin
                    kernal_w <= 1'b0;
                end else begin
                    kernal_w <= kernal_w;
                end
            end
        end
    end

    // next state
    always @(conv_busy, img_in_valid_i, load_sw_img_done, kernal_en, conv_2_chn_done,
        load_kernal_done, channel_code, kernal_w, max_pool_done, read_result_done) begin
        case (current_state)
            S_IDLE: begin
                if (~conv_busy && img_in_valid_i) begin
                    next_state = S_LOAD_IMG_SW;
                end else begin
                    next_state = current_state;
                end
            end
            S_LOAD_IMG_SW: begin
                if (load_sw_img_done) begin
                    next_state = S_LOAD_KERNAL;
                end else begin
                    next_state = current_state;
                end
            end
            S_LOAD_KERNAL: begin
                if (load_kernal_done) begin
                    if (channel_code > 1) begin
                        next_state = S_CALC_CONV_2;
                    end else begin
                        next_state = S_CALC_CONV_1;
                    end
                end else begin
                    next_state = current_state;
                end
            end
            S_CALC_CONV_1: begin
                if (kernal_w) begin
                    next_state = S_MAX_POOL;
                end else begin
                    next_state = current_state;
                end
            end
            S_CALC_CONV_2: begin
                if (conv_2_chn_done && kernal_w_d1 && (channel_code == CHN_COUNT)) begin
                    next_state = S_MAX_POOL;
                end else if (conv_2_chn_done && kernal_w_d1 && (channel_code < CHN_COUNT)) begin
                    next_state = S_LOAD_KERNAL;
                end else begin
                    next_state = current_state;
                end
            end
            S_MAX_POOL: begin
                if (max_pool_done && (channel_code < CHN_COUNT)) begin
                    next_state = S_LOAD_KERNAL;
                end else if (max_pool_done && (channel_code == CHN_COUNT)) begin
                    next_state = S_OUT_DATA;
                end else begin
                    next_state = current_state;
                end
            end
            S_OUT_DATA: begin
                if (read_result_done) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = current_state;
                end
            end
            default: 
                next_state = S_IDLE;
        endcase
    end

    // update kernal code
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            channel_code <= 5'h0;
        end else begin
            if(kernal_w && ~kernal_w_d1) begin
                if(current_state == S_OUT_DATA) begin
                    channel_code <= 5'h1;
                end else begin
                    channel_code <= channel_code + 5'h1;
                end
            end
            else begin
                if (done_o && read_result_i) begin
                    channel_code <= 5'h1;
                end else begin
                    channel_code <= channel_code;
                end
            end
        end
    end

    // generate image address
    always @(posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            img_i <= 5'h0;
            img_j <= 5'h0;
            img_k <= 3'h0;
            img_i_d1 <= 5'h0;
            img_j_d1 <= 5'h0;
            img_k_d1 <= 3'h0;
            img_i_d2 <= 5'h0;
            img_j_d2 <= 5'h0;
            img_k_d2 <= 3'h0;
            cnv_i <= 3'h0;
            cnv_j <= 3'h0;
            chn_i <= 5'h0;
            chn_i_d1 <= 5'h0;
            chn_i_d2 <= 5'h0;
        end else begin
            img_i_d1 <= img_i;
            img_j_d1 <= img_j;
            img_k_d1 <= img_k;
            img_i_d2 <= img_i_d1;
            img_j_d2 <= img_j_d1;
            img_k_d2 <= img_k_d1;
            chn_i_d1 <= chn_i;
            chn_i_d2 <= chn_i_d1;

            if ((current_state == S_LOAD_IMG_SW) && img_in_valid_i) begin
                if(img_j == CONV_1_IMG_DIM -1) begin
                    img_j <= 0;
                end else begin
                    img_j <= img_j + 1;
                end
                if ((img_i == CONV_1_IMG_DIM -1) && (img_j == CONV_1_IMG_DIM -1)) begin
                    img_i <= 0;
                end else begin
                    if (img_j == CONV_1_IMG_DIM -1) begin
                        img_i <= img_i + 1;
                    end else begin
                        img_i <= img_i;
                    end
                end
                img_k <= 0;
                cnv_i <= 0;
                cnv_j <= 0;
                chn_i <= 0;
            end else if ((current_state == S_LOAD_KERNAL) && kernal_w) begin
                if (img_j == K_DIME -1) begin
                    img_j <= 0;
                end else begin
                    img_j <= img_j + 1;
                end
                if ((img_i == K_DIME*CONV_1_OUT_CHN -1) && (img_j == K_DIME -1)) begin
                    img_i <= 0;
                end else begin
                    if (img_j == K_DIME -1) begin
                        img_i <= img_i + 1;
                    end else begin
                        img_i <= img_i;
                    end
                end
                img_k <= 0;
                cnv_i <= 0;
                cnv_j <= 0;
                chn_i <= chn_i;
            end else if (current_state == S_CALC_CONV_1) begin
                if((cnv_j == K_DIME -1) && (cnv_i == K_DIME -1) 
                && (img_k < CONV_1_OUT_CHN-1)) begin
                    img_k <= img_k +1;
                end else begin
                    img_k <= 0;
                end

                if (cnv_j == K_DIME -1) begin
                    if ((cnv_i == K_DIME -1) && (img_k < CONV_1_OUT_CHN-1)) begin
                        cnv_j <= cnv_j;
                    end else begin
                        cnv_j <= 0;
                    end
                end else begin
                    cnv_j <= cnv_j + 1;
                end

                if ((cnv_i == K_DIME -1) && (cnv_j == K_DIME -1)) begin
                    if (img_k < CONV_1_OUT_CHN-1) begin
                        cnv_i <= cnv_i;
                    end else begin
                        cnv_i <= 0;
                    end
                end else begin
                    if (cnv_j == K_DIME -1) begin
                        cnv_i <= cnv_i + 1;
                    end else begin
                        cnv_i <= cnv_i;
                    end
                end

                if ((img_j == CONV_1_IMG_DIM - K_DIME -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_1_OUT_CHN-1)) begin
                    img_j <= 0;
                end else begin
                    if ((cnv_i == K_DIME -1) 
                    && (cnv_j == K_DIME -1) 
                    && (img_k == CONV_1_OUT_CHN-1)) begin
                        img_j <= img_j +1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_1_IMG_DIM - K_DIME -1)
                && (img_j == CONV_1_IMG_DIM - K_DIME -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_1_OUT_CHN-1)) begin
                    img_i <= 0;
                end else begin
                    if ((img_j == CONV_1_IMG_DIM - K_DIME -1) 
                    && (cnv_i == K_DIME -1) 
                    && (cnv_j == K_DIME -1)
                    && (img_k == CONV_1_OUT_CHN-1)) begin
                        img_i <= img_i +1;
                    end else begin
                        img_i <= img_i;
                    end
                end
                chn_i <= 0;
            end else if (current_state == S_CALC_CONV_2) begin

                if (img_k == CONV_2_IN__CHN -1) begin
                    img_k <= 0;
                end else begin
                    img_k <= img_k +1;
                end

                if ((cnv_j == K_DIME -1) && (img_k == CONV_2_IN__CHN -1)) begin
                    cnv_j <= 0;
                end else begin
                    if (img_k == CONV_2_IN__CHN -1) begin
                        cnv_j <= cnv_j + 1;
                    end else begin
                        cnv_j <= cnv_j;
                    end
                end

                if ((cnv_i == K_DIME -1) && (cnv_j == K_DIME -1) 
                && (img_k == CONV_2_IN__CHN -1)) begin
                    cnv_i <= 0;
                end else begin
                    if ((cnv_j == K_DIME -1) && (img_k == CONV_2_IN__CHN -1)) begin
                        cnv_i <= cnv_i + 1;
                    end else begin
                        cnv_i <= cnv_i;
                    end
                end

                if ((img_j == CONV_2_OUT_DIM -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_2_IN__CHN -1)) begin
                    img_j <= 0;
                end else begin
                    if ((cnv_i == K_DIME -1) && (cnv_j == K_DIME -1)
                    && (img_k == CONV_2_IN__CHN -1)) begin
                        img_j <= img_j +1;
                    end else begin
                        img_j <= img_j;
                    end
                end

                if ((img_i == CONV_2_OUT_DIM -1)
                && (img_j == CONV_2_OUT_DIM -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_2_IN__CHN -1)) begin
                    img_i <= 0;
                end else begin
                    if ((img_j == CONV_2_OUT_DIM -1) 
                    && (cnv_i == K_DIME -1) 
                    && (cnv_j == K_DIME -1)
                    && (img_k == CONV_2_IN__CHN -1)) begin
                        img_i <= img_i +1;
                    end else begin
                        img_i <= img_i;
                    end
                end
                
                if ((chn_i == CHN_COUNT-3)
                && (img_i == CONV_2_OUT_DIM -1)
                && (img_j == CONV_2_OUT_DIM -1) 
                && (cnv_i == K_DIME -1) 
                && (cnv_j == K_DIME -1)
                && (img_k == CONV_2_IN__CHN -1)) begin
                    chn_i <= 0;
                end else begin
                    if ((img_i == CONV_2_OUT_DIM -1)
                    && (img_j == CONV_2_OUT_DIM -1) 
                    && (cnv_i == K_DIME -1) 
                    && (cnv_j == K_DIME -1)
                    && (img_k == CONV_2_IN__CHN -1)) begin
                        chn_i <= chn_i +1;
                    end else begin
                        chn_i <= chn_i;
                    end
                end
            end else if ((current_state == S_MAX_POOL) && max_pool_start 
            && ~max_pool_done) begin // SIZE 2X2
                if ((channel_code == 2) && (kernal_w)) begin
                    if ((cnv_j == 1) || (img_j == CONV_2_IMG_DIM -1)) begin
                        cnv_j <= 0;
                    end else begin
                        cnv_j <= cnv_j + 1;
                    end

                    if (((cnv_i == 1) || (img_i == CONV_2_IMG_DIM -1)) 
                    && ((cnv_j == 1)|| (img_j == CONV_2_IMG_DIM -1))) begin
                        cnv_i <= 0;
                    end else begin
                        if ((cnv_j == 1) || (img_j == CONV_2_IMG_DIM -1)) begin
                            cnv_i <= cnv_i + 1;
                        end else begin
                            cnv_i <= cnv_i;
                        end
                    end

                    if ((img_j == CONV_2_IMG_DIM -1) 
                    && ((cnv_i == 1)||(img_i == CONV_2_IMG_DIM -1))) begin
                        img_j <= 0;
                    end else begin
                        if (((cnv_i == 1) || (img_i == CONV_2_IMG_DIM -1)) 
                        && ((cnv_j == 1) || (img_j == CONV_2_IMG_DIM -1))) begin
                            img_j <= img_j +1;
                        end else begin
                            img_j <= img_j;
                        end
                    end

                    if ((img_i == CONV_2_IMG_DIM -1)
                    && (img_j == CONV_2_IMG_DIM -1) ) begin
                        img_i <= 0;
                    end else begin
                        if ((img_j == CONV_2_IMG_DIM -1) 
                        && (cnv_i == 1)) begin
                            img_i <= img_i +1;
                        end else begin
                            img_i <= img_i;
                        end
                    end

                    if ((chn_i == CONV_1_OUT_CHN-1) 
                    && (img_i == CONV_2_IMG_DIM -1)
                    && (img_j == CONV_2_IMG_DIM -1) ) begin
                        chn_i <= 0;
                    end else begin
                        if ((img_i == CONV_2_IMG_DIM -1)
                        && (img_j == CONV_2_IMG_DIM -1)) begin
                            chn_i <= chn_i + 1;
                        end else begin
                            chn_i <= chn_i;
                        end
                    end
                end else begin
                    if ((cnv_j == 1) || (img_j == CONV_OUT_IMDIM -1)) begin
                        cnv_j <= 0;
                    end else begin
                        cnv_j <= cnv_j + 1;
                    end

                    if (((cnv_i == 1) || (img_i == CONV_OUT_IMDIM -1)) 
                    && ((cnv_j == 1) || (img_j == CONV_OUT_IMDIM -1))) begin
                        cnv_i <= 0;
                    end else begin
                        if ((cnv_j == 1) || (img_j == CONV_OUT_IMDIM -1)) begin
                            cnv_i <= cnv_i + 1;
                        end else begin
                            cnv_i <= cnv_i;
                        end
                    end

                    if ((img_j == CONV_OUT_IMDIM -1) 
                    && ((cnv_i == 1) || (img_i == CONV_OUT_IMDIM -1))) begin
                        img_j <= 0;
                    end else begin
                        if (((cnv_i == 1) || (img_i == CONV_OUT_IMDIM -1)) 
                        && (cnv_j == 1)) begin
                            img_j <= img_j +1;
                        end else begin
                            img_j <= img_j;
                        end
                    end

                    if ((img_i == CONV_OUT_IMDIM -1)
                    && (img_j == CONV_OUT_IMDIM -1) ) begin
                        img_i <= 0;
                    end else begin
                        if ((img_j == CONV_OUT_IMDIM -1)
                        && (cnv_i == 1)) begin
                            img_i <= img_i +1;
                        end else begin
                            img_i <= img_i;
                        end
                    end

                    if ((chn_i == CONV_2_OUT_CHN-1) 
                    && (img_i == CONV_OUT_IMDIM -1)
                    && (img_j == CONV_OUT_IMDIM -1)) begin
                        chn_i <= 0;
                    end else begin
                        if ((img_i == CONV_OUT_IMDIM -1)
                        && (img_j == CONV_OUT_IMDIM -1)) begin
                            chn_i <= chn_i +1;
                        end else begin
                            chn_i <= chn_i;
                        end
                    end
                end
                img_k <= 0;
            end else if (current_state == S_OUT_DATA) begin
                if (read_result_i) begin
                    if (img_j == CONV_OUT_IMDIM-1) begin
                        img_j <= 0;
                    end else begin
                        img_j <= img_j +1;
                    end

                    if ((img_i == CONV_OUT_IMDIM -1) && (img_j == CONV_OUT_IMDIM -1)) begin
                        img_i <= 0;
                    end else begin
                        if (img_j == CONV_OUT_IMDIM -1) begin
                            img_i <= img_i +1;
                        end else begin
                            img_i <= img_i;
                        end
                    end

                    if ((chn_i == CONV_2_OUT_CHN-1) && (img_i == CONV_OUT_IMDIM -1) 
                    && (img_j == CONV_OUT_IMDIM -1)) begin
                        chn_i <= 0;
                    end else begin
                        if ((img_i == CONV_OUT_IMDIM -1) 
                        && (img_j == CONV_OUT_IMDIM -1)) begin
                            chn_i <= chn_i +1;
                        end else begin
                            chn_i <= chn_i;
                        end
                    end
                    img_k <= 0;
                    cnv_i <= 3'h0;
                    cnv_j <= 3'h0;
                end else begin
                    if (~(read_result_start || read_result_i)) begin
                        img_i <= 5'h0;
                        img_j <= 5'h0;
                        img_k <= 3'h0;
                        cnv_i <= 3'h0;
                        cnv_j <= 3'h0;
                        chn_i <= 5'h0;
                    end else begin
                        img_i <= img_i;
                        img_j <= img_j;
                        img_k <= img_k;
                        cnv_i <= cnv_i;
                        cnv_j <= cnv_j;
                        chn_i <= chn_i;
                    end
                end
            end
            else begin
                img_i <= 5'h0;
                img_j <= 5'h0;
                img_k <= 3'h0;
                cnv_i <= 3'h0;
                cnv_j <= 3'h0;
                chn_i <= chn_i;
            end
        end
    end

    // maxpool logic
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            max_pool_data <= 0;
        end else begin
            if (current_state == S_MAX_POOL) begin
                if ((cnv_addr == 0)) begin
                    max_pool_data <= img_2_data_out;
                end else begin
                    if (max_pool_data < img_2_data_out) begin
                        max_pool_data <= img_2_data_out;
                    end else begin
                        max_pool_data <= max_pool_data;
                    end
                end
            end else begin
                max_pool_data <= 0;
            end
        end
    end
    
    // convolution kernal address
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            cnv_addr <= 0;
        end else begin
            if (current_state == S_MAX_POOL) begin
                cnv_addr <= cnv_i*2 + cnv_j;
            end else begin
                cnv_addr <= cnv_i*K_DIME + cnv_j;
            end
        end
    end

    // convolution
    always @(posedge clk) begin
        if (current_state == S_CALC_CONV_1) begin
            for (i = 0; i < CONV_1_OUT_CHN; i = i+1) begin
                if (cnv_addr == 0) begin
                    conv_cell_data[i] <= chn_kernal[i*(K_DIME**2) + cnv_addr] 
                                        * img_1_data_out;
                end else if (cnv_addr == (K_DIME**2)-1) begin
                    if (i == img_k_d1) begin
                        conv_cell_data[i] <= conv_cell_data[i] + chn_kernal[i*(K_DIME**2) + cnv_addr] 
                                        * img_1_data_out + bias_data;
                    end else begin
                        conv_cell_data[i] <= conv_cell_data[i];
                    end
                end else begin
                    conv_cell_data[i] <= conv_cell_data[i] + chn_kernal[i*(K_DIME**2) + cnv_addr] 
                                        * img_1_data_out;
                end
            end
        end else if (current_state == S_CALC_CONV_2) begin
            for (i = 0; i < CONV_1_OUT_CHN; i = i+1) begin
                if (i == img_k_d1) begin
                    if (cnv_addr == 0) begin
                        conv_cell_data[i] <= chn_kernal[i*(K_DIME**2) + cnv_addr] 
                                            * img_1_data_out;
                    end else begin
                        conv_cell_data[i] <= conv_cell_data[i] + chn_kernal[i*(K_DIME**2) + cnv_addr] 
                                            * img_1_data_out;
                    end
                end else begin
                    conv_cell_data[i] <= conv_cell_data[i];
                end
            end
        end else begin
            for (i = 0; i < CONV_1_OUT_CHN; i = i+1) begin
                conv_cell_data[i] <= 0;
            end
        end
    end

endmodule

module bram_us #
(
    parameter integer SIZE = 1024,
    parameter integer SIZE_LOG = 10,
    parameter integer DATA_WIDTH = 32,
    parameter MEM_INIT_FILE = ""
)
(
    input wire clk,
    input wire rst_n,  
    input wire en,
    input wire rw,
    input wire [SIZE_LOG-1 : 0] addr,
    input wire [DATA_WIDTH-1 : 0] data_in,
    output reg [DATA_WIDTH-1 : 0] data_out
);

    
    (* ram_style = "block"*) reg [DATA_WIDTH-1: 0] block_ram [0:SIZE -1];
    integer i;
    initial begin
        data_out <= 0;
        if (MEM_INIT_FILE != "") begin
            $readmemh(MEM_INIT_FILE, block_ram);
        end else begin
            for(i = 0; i < SIZE; i = i+1) begin
                block_ram[i] <= 0;
            end
        end
    end

    always@(posedge clk)
    begin
        if(en && rw)
            block_ram[addr] <= data_in;
        else if(en && !rw)
                data_out <= block_ram[addr];              
        else
            data_out <= 0;
    end
        

endmodule