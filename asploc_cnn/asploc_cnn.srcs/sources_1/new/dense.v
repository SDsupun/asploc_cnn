`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Uppsala University
// Engineer: Supun Madusanka
// 
// Create Date: 12/18/2024 07:28:06 AM
// Design Name: asploc_cnn
// Module Name: dense
// Project Name: ASPLOC
// Target Devices: Minized
// Tool Versions: 2018.3
// Description: Fully connected/dense layer implementation
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dense(
    input clk,
    input rst_n, 
    input [7:0] img_data_i,
    input img_data_valid_i,
    input read_result_i,
    output img_data_read_o,
    output done_o,
    output [3:0] result_o,
    output [7:0] dense_debug_o
    );

    localparam FS_1_COL_SIZE = 400;
    localparam FS_1_BATCH_SZ = 5;
    localparam FS_1_ROW_SIZE = 120;
    localparam FS_2_COL_SIZE = 120;
    localparam FS_2_BATCH_SZ = 5;
    localparam FS_2_ROW_SIZE = 84;
    localparam FS_3_COL_SIZE = 84;
    localparam FS_3_BATCH_SZ = 5;
    localparam FS_3_ROW_SIZE = 10;
    localparam IMG_IN_WIDTH  = 6;
    localparam MEMDATA_WIDTH = 8;
    localparam FS1W_SIZE_LOG = 16;
    localparam FS2W_SIZE_LOG = 14;
    localparam FS3W_SIZE_LOG = 10;
    localparam FS1B_SIZE_LOG = 7;
    localparam FS2B_SIZE_LOG = 7;
    localparam FS3B_SIZE_LOG = 6;

    localparam S_IDLE = 6'b000001;
    localparam S_FS_1 = 6'b000010;
    localparam S_FS_2 = 6'b000100;
    localparam S_FS_3 = 6'b001000;
    localparam S_RELU = 6'b010000;
    localparam S_OUTD = 6'b100000;

    reg [5:0] current_state;
    reg [5:0] next_state;
    reg [1:0] done_layer;
    reg [8:0] mat_j;
    reg [6:0] mat_i;
    wire signed [7:0] img_data_s;
    reg [6:0] mat_i_d1;
    reg [6:0] mat_i_d2;
    reg [8:0] mat_j_d1;
    reg [8:0] mat_j_d2;
    reg [6:0] bias_i;
    reg [3:0] relu_i;
    reg [7:0] r_max_val;
    reg [3:0] result;

    wire [9:0] relu_img_addr_i;
    wire signed [15:0] relu_img_data_i;
    wire [9:0] relu_img_addr_o;
    wire [7:0] relu_img_data_o;

    reg fs1_w_en;
    reg [FS1W_SIZE_LOG-1:0] fs1_w_addr;
    wire signed [7:0] fs1_w_data_out;
    
    reg fs1_w_en_d1  ;
    reg [FS1W_SIZE_LOG-1:0] fs1_w_addr_d1;
    
    reg fs2_w_en;
    reg [FS2W_SIZE_LOG-1:0] fs2_w_addr;
    wire signed [7:0] fs2_w_data_out;
    
    reg fs3_w_en;
    reg [FS3W_SIZE_LOG-1:0] fs3_w_addr;
    wire signed [7:0] fs3_w_data_out;
    
    reg fs1_b_en;
    reg [FS1B_SIZE_LOG-1:0] fs1_b_addr;
    wire signed [7:0] fs1_b_data_out;
    reg fs1_b_en_d1;
    reg [FS1B_SIZE_LOG-1:0] fs1_b_addr_d1;
    
    reg fs2_b_en;
    reg [FS2B_SIZE_LOG-1:0] fs2_b_addr;
    wire signed [7:0] fs2_b_data_out;
    reg fs2_b_en_d1;
    reg [FS2B_SIZE_LOG-1:0] fs2_b_addr_d1;
    
    reg fs3_b_en;
    reg [FS3B_SIZE_LOG-1:0] fs3_b_addr;
    wire signed [7:0] fs3_b_data_out;
    reg fs3_b_en_d1;
    reg [FS3B_SIZE_LOG-1:0] fs3_b_addr_d1;

    reg signed [15:0] fs1_out_data_r [0:FS_1_ROW_SIZE-1];
    
    reg signed [7:0] fs1_relu_out_data [0:FS_1_ROW_SIZE-1];

    reg conv_img_data_read;
    reg matmult_done;
    reg relu_done;
    

    bram #(
            .SIZE(FS_1_COL_SIZE*FS_1_ROW_SIZE),
            .SIZE_LOG(FS1W_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs1_weight.mem")) 
    fs1_weight(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs1_w_en),
        .rw(1'b0),
        .addr(fs1_w_addr),
        .data_in(8'h00),
        .data_out(fs1_w_data_out)
    );

    bram #(
            .SIZE(FS_2_COL_SIZE*FS_2_ROW_SIZE),
            .SIZE_LOG(FS2W_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs2_weight.mem")) 
    fs2_weight(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs2_w_en),
        .rw(1'b0),
        .addr(fs2_w_addr),
        .data_in(8'h00),
        .data_out(fs2_w_data_out)
    );
    
    bram #(
            .SIZE(FS_3_COL_SIZE*FS_3_ROW_SIZE),
            .SIZE_LOG(FS3W_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs3_weight.mem")) 
    fs3_weight(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs3_w_en),
        .rw(1'b0),
        .addr(fs3_w_addr),
        .data_in(8'h00),
        .data_out(fs3_w_data_out)
    );
    
    bram #(
            .SIZE(FS_1_ROW_SIZE),
            .SIZE_LOG(FS1B_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs1_bias.mem")) 
    fs1_bias(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs1_b_en),
        .rw(1'b0),
        .addr(fs1_b_addr),
        .data_in(8'h00),
        .data_out(fs1_b_data_out)
    );
    
    bram #(
            .SIZE(FS_2_ROW_SIZE),
            .SIZE_LOG(FS2B_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs2_bias.mem")) 
    fs2_bias(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs2_b_en),
        .rw(1'b0),
        .addr(fs2_b_addr),
        .data_in(8'h00),
        .data_out(fs2_b_data_out)
    );
    
    bram #(
            .SIZE(FS_3_ROW_SIZE),
            .SIZE_LOG(FS3B_SIZE_LOG),
            .DATA_WIDTH(MEMDATA_WIDTH),
            .MEM_INIT_FILE("fs3_bias.mem")) 
    fs3_bias(
        .clk(clk),
        .rst_n(rst_n),
        .en(fs3_b_en),
        .rw(1'b0),
        .addr(fs3_b_addr),
        .data_in(8'h00),
        .data_out(fs3_b_data_out)
    );
    
    relu_n_dq_16 relu_n_dq_inst(
        .clk(clk),
        .rst_n(rst_n),
        .img_addr_i(relu_img_addr_i),
        .img_data_i(relu_img_data_i),
        .img_addr_o(relu_img_addr_o),
        .img_data_o(relu_img_data_o)
    );

    assign dense_debug_o = {2'b0, current_state};
    assign img_data_s = img_data_i;
    assign done_o = ((relu_i == FS_3_ROW_SIZE-1) && (current_state == S_OUTD));
    assign result_o = result;
    assign img_data_read_o = conv_img_data_read;
    assign relu_img_addr_i = (current_state == S_RELU)? mat_i_d2: 0;
    assign relu_img_data_i = (current_state == S_RELU)? 
                                (done_layer == 2'b01)? fs1_out_data_r[mat_i_d2] + fs1_b_data_out:
                                (done_layer == 2'b10)? fs1_out_data_r[mat_i_d2] + fs2_b_data_out:
                                (done_layer == 2'b11)? fs1_out_data_r[mat_i_d2] + fs3_b_data_out: 0: 0;

    integer i;
    initial begin
        for (i = 0; i<FS_1_ROW_SIZE; i = i +1) begin
            fs1_out_data_r[i] <= 16'h0;
            fs1_relu_out_data[i] <= 8'h0;
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // generate status signal
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            conv_img_data_read <= 0;
        end else begin
            if ((current_state == S_FS_1) && (mat_i == FS_1_ROW_SIZE-1) && (img_data_valid_i)) begin
                conv_img_data_read <= 1;
            end else begin
                conv_img_data_read <= 0;
            end
        end
    end
    
    // generate status signal
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            matmult_done <= 0;
        end else begin
            if ((current_state == S_FS_1) 
            && (mat_i == FS_1_ROW_SIZE-1) 
            && (mat_j == FS_1_COL_SIZE-1)) begin
                matmult_done <= 1;
            end else if ((current_state == S_FS_2) 
            && (mat_i == FS_2_ROW_SIZE-1) 
            && (mat_j == FS_2_COL_SIZE-1)) begin
                matmult_done <= 1;
            end else if ((current_state == S_FS_3) 
            && (mat_i == FS_3_ROW_SIZE-1) 
            && (mat_j == FS_3_COL_SIZE-1)) begin
                matmult_done <= 1;
            end else if (current_state == S_RELU) begin
                matmult_done <= 0;
            end else begin
                matmult_done <= matmult_done;
            end
        end
    end

    // generate status signal
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            relu_done <= 0;
        end else begin
            if(current_state == S_RELU) begin
                if((done_layer == 2'b01) && (relu_img_addr_o == FS_1_ROW_SIZE-1)) begin
                    relu_done <= 1;
                end else if ((done_layer == 2'b10) && (relu_img_addr_o == FS_2_ROW_SIZE-1)) begin
                    relu_done <= 1;
                end else if ((done_layer == 2'b11) && (relu_img_addr_o == FS_3_ROW_SIZE-1)) begin
                    relu_done <= 1;
                end else begin
                    relu_done <= 0;
                end
            end else begin
                relu_done <= 0;
            end
        end
    end

    always @(img_data_valid_i, done_layer, read_result_i, relu_done) begin
        case (current_state)
            S_IDLE: begin
                if (img_data_valid_i) begin
                    next_state = S_FS_1;
                end else begin
                    next_state = current_state;
                end
            end
            S_FS_1: begin
                if (done_layer == 2'b01) begin
                    next_state = S_RELU;
                end else begin
                    next_state = current_state;
                end
            end
            S_FS_2: begin
                if (done_layer == 2'b10) begin
                    next_state = S_RELU;
                end else begin
                    next_state = current_state;
                end
            end
            S_FS_3: begin
                if (done_layer == 2'b11) begin
                    next_state = S_RELU;
                end else begin
                    next_state = current_state;
                end
            end
            S_RELU: begin
                if (relu_done) begin
                    if (done_layer == 2'b01) begin
                        next_state = S_FS_2;
                    end else if (done_layer == 2'b10) begin
                        next_state = S_FS_3;
                    end else begin
                        next_state = S_OUTD;
                    end
                end else begin
                    next_state = current_state;
                end
            end
            S_OUTD: begin
                if (read_result_i) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = current_state;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // matrix index generation
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            mat_i <= 7'h0;
            mat_j <= 9'h0;
            mat_i_d1 <= 7'h0;
            mat_i_d2 <= 7'h0;
            mat_j_d1 <= 7'h0;
            mat_j_d2 <= 7'h0;
        end else begin
            mat_i_d1 <= mat_i;
            mat_i_d2 <= mat_i_d1;
            mat_j_d1 <= mat_j;
            mat_j_d2 <= mat_j_d1;
            if ((current_state == S_FS_1) && img_data_valid_i && ~matmult_done) begin
                if ((mat_j == FS_1_COL_SIZE-1) 
                && (mat_i == FS_1_ROW_SIZE-1)) begin
                    mat_j <= 9'h0;
                end else begin
                    if (mat_i == FS_1_ROW_SIZE-1) begin
                        mat_j <= mat_j + 1;
                    end else begin
                        mat_j <= mat_j;
                    end
                end

                if (mat_i == FS_1_ROW_SIZE-1) begin
                    mat_i <= 0;
                end else begin
                    mat_i <= mat_i+1;
                end

            end else if ((current_state == S_FS_2)  && ~matmult_done) begin
                if ((mat_j == FS_2_COL_SIZE-1) && (mat_i == FS_2_ROW_SIZE-1)) begin
                    mat_j <= 9'h0;
                end else begin
                    if (mat_i == FS_2_ROW_SIZE-1) begin
                        mat_j <= mat_j + 1;
                    end else begin
                        mat_j <= mat_j;
                    end
                end

                if (mat_i == FS_2_ROW_SIZE-1) begin
                    mat_i <= 0;
                end else begin
                    mat_i <= mat_i + 1;
                end

            end else if ((current_state == S_FS_3)  && ~matmult_done) begin
                if ((mat_j == FS_3_COL_SIZE-1) && (mat_i == FS_3_ROW_SIZE-1)) begin
                    mat_j <= 9'h0;
                end else begin
                    if (mat_i == FS_3_ROW_SIZE-1) begin
                        mat_j <= mat_j + 1;
                    end else begin
                        mat_j <= mat_j;
                    end
                end

                if (mat_i == FS_3_ROW_SIZE-1) begin
                    mat_i <= 0;
                end else begin
                    mat_i <= mat_i +1;
                end

            end else if(current_state == S_RELU) begin
                if (done_layer == 2'b01) begin
                    mat_j <= 9'h0;
                    if (mat_i == FS_1_ROW_SIZE-1) begin
                        mat_i <= 0;
                    end else begin
                        mat_i <= mat_i +1;
                    end 
                end else if (done_layer == 2'b10) begin
                    mat_j <= 9'h0;
                    if (mat_i == FS_2_ROW_SIZE-1) begin
                        mat_i <= 0;
                    end else begin
                        mat_i <= mat_i +1;
                    end 
                end else if (done_layer == 2'b11) begin
                    mat_j <= 9'h0;
                    if (mat_i == FS_3_ROW_SIZE-1) begin
                        mat_i <= 0;
                    end else begin
                        mat_i <= mat_i +1;
                    end 
                end else begin
                    mat_i <= 7'h0;
                    mat_j <= 9'h0;
                end
            end else begin
                mat_i <= 7'h0;
                mat_j <= 9'h0;
            end
        end
    end

    // generate signals for the memories
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            fs1_w_en   <= 0;
            fs1_w_addr <= 0;
            fs2_w_en   <= 0;
            fs2_w_addr <= 0;
            fs3_w_en   <= 0;
            fs3_w_addr <= 0;
            fs1_w_en_d1   <= 0;
            fs1_w_addr_d1 <= 0;
        end else begin
            fs1_w_en_d1   <= fs1_w_en;
            fs1_w_addr_d1 <= fs1_w_addr;
            if ((current_state == S_FS_1) && ~matmult_done) begin
                fs1_w_en   <= 1;
                fs1_w_addr <= FS_1_COL_SIZE*mat_i + mat_j;
                fs2_w_en   <= 0;
                fs2_w_addr <= 0;
                fs3_w_en   <= 0;
                fs3_w_addr <= 0;
            end else if ((current_state == S_FS_2) && ~matmult_done) begin
                fs1_w_en   <= 0;
                fs1_w_addr <= 0;
                fs2_w_en   <= 1;
                fs2_w_addr <= FS_2_COL_SIZE*mat_i + mat_j;
                fs3_w_en   <= 0;
                fs3_w_addr <= 0;
            end else if ((current_state == S_FS_3) && ~matmult_done) begin
                fs1_w_en   <= 0;
                fs1_w_addr <= 0;
                fs2_w_en   <= 0;
                fs2_w_addr <= 0;
                fs3_w_en   <= 1;
                fs3_w_addr <= FS_3_COL_SIZE*mat_i + mat_j;
            end else begin
                fs1_w_en   <= 0;
                fs1_w_addr <= 0;
                fs2_w_en   <= 0;
                fs2_w_addr <= 0;
                fs3_w_en   <= 0;
                fs3_w_addr <= 0;
            end
        end
    end

    // matrix multiplication
    always @(posedge clk ) begin
        if (fs1_w_en||fs1_w_en_d1) begin
            fs1_out_data_r[mat_i_d2] <= fs1_out_data_r[mat_i_d2] 
                                        + fs1_w_data_out * img_data_s;
        end else if (fs2_w_en) begin
            fs1_out_data_r[mat_i_d2] <= fs1_out_data_r[mat_i_d2] 
                                        + fs2_w_data_out * fs1_relu_out_data[mat_j_d2];
        end else if (fs3_w_en) begin
            fs1_out_data_r[mat_i_d2] <= fs1_out_data_r[mat_i_d2] 
                                        + fs3_w_data_out * fs1_relu_out_data[mat_j_d2];
        end else if (current_state == S_RELU) begin
            fs1_out_data_r[relu_img_addr_o] <= 0;
        end
    end

    // read bias
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
                fs1_b_addr <= 0;
                fs1_b_en   <= 0;
                fs2_b_addr <= 0;
                fs2_b_en   <= 0;
                fs3_b_addr <= 0;
                fs3_b_en   <= 0;
                bias_i     <= 0;
                fs1_b_addr_d1 <= 0;
                fs1_b_en_d1   <= 0;
                fs2_b_addr_d1 <= 0;
                fs2_b_en_d1   <= 0;
                fs3_b_addr_d1 <= 0;
                fs3_b_en_d1   <= 0;
        end else begin
            fs1_b_addr_d1 <= fs1_b_addr;
            fs1_b_en_d1   <= fs1_b_en;
            fs2_b_addr_d1 <= fs2_b_addr;
            fs2_b_en_d1   <= fs2_b_en;
            fs3_b_addr_d1 <= fs3_b_addr;
            fs3_b_en_d1   <= fs3_b_en;
            if ((current_state == S_RELU) && (done_layer == 2'b01)) begin
                fs1_b_addr <= mat_i;
                fs1_b_en   <= 1;
                fs2_b_addr <= 0;
                fs2_b_en   <= 0;
                fs3_b_addr <= 0;
                fs3_b_en   <= 0;
                
            end else if ((current_state == S_RELU) && (done_layer == 2'b10)) begin
                fs1_b_addr <= 0;
                fs1_b_en   <= 0;
                fs2_b_addr <= mat_i;
                fs2_b_en   <= 1;
                fs3_b_addr <= 0;
                fs3_b_en   <= 0;
                
            end else if ((current_state == S_RELU) && (done_layer == 2'b11)) begin
                fs1_b_addr <= 0;
                fs1_b_en   <= 0;
                fs2_b_addr <= 0;
                fs2_b_en   <= 0;
                fs3_b_addr <= mat_i;
                fs3_b_en   <= 1;
                
            end else begin
                fs1_b_addr <= 0;
                fs1_b_en   <= 0;
                fs2_b_addr <= 0;
                fs2_b_en   <= 0;
                fs3_b_addr <= 0;
                fs3_b_en   <= 0;
                bias_i     <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (current_state == S_RELU) begin
            fs1_relu_out_data[relu_img_addr_o] <= relu_img_data_o;
    end
    end
    
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            done_layer <= 2'b00;
        end else begin
            if ((current_state == S_FS_1)) begin
                if ((mat_i_d2 == FS_1_ROW_SIZE-1) 
                && (mat_j_d2 == FS_1_COL_SIZE-1)) begin
                    done_layer <= done_layer + 1;
                end else begin
                    done_layer <= done_layer;
                end
            end else if ((current_state == S_FS_2)) begin
                if ((mat_i_d2 == FS_2_ROW_SIZE-1) 
                && (mat_j_d2 == FS_2_COL_SIZE-1)) begin
                    done_layer <= done_layer + 1;
                end else begin
                    done_layer <= done_layer;
                end
            end else if ((current_state == S_FS_3)) begin
                if ((mat_i_d2 == FS_3_ROW_SIZE-1) 
                && (mat_j_d2 == FS_3_COL_SIZE-1)) begin
                    done_layer <= done_layer + 1;
                end else begin
                    done_layer <= done_layer;
                end
            end else begin
                if (read_result_i) begin
                    done_layer <= 2'b00;
                end else begin
                    done_layer <= done_layer;
                end
            end
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            result    <= 4'h0; 
            relu_i    <= 4'h0;
            r_max_val <= 8'h0;
        end else begin
            if (current_state == S_OUTD) begin
                if(relu_i < FS_3_ROW_SIZE-1) begin
                    relu_i <= relu_i +1;
                end else begin
                    relu_i <= relu_i;
                end
                if (fs1_relu_out_data[relu_i] > r_max_val) begin
                    r_max_val <= fs1_relu_out_data[relu_i];
                    result    <= relu_i+1;
                end else begin
                    r_max_val <= r_max_val;
                    if (relu_i == 0) begin
                        result <= 1; // since the extra relu used in HW compared to SW
                    end else begin
                    result <= result;
                    end
                end

            end else begin
                result    <= 4'h0;
                relu_i    <= 4'h0;
                r_max_val <= 8'h0;
            end
        end
    end

endmodule

module bram #
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

    
    (* ram_style = "block"*) reg signed [DATA_WIDTH-1: 0] block_ram [0:SIZE -1];
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
