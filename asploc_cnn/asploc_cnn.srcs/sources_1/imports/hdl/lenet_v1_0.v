
`timescale 1 ns / 1 ps

	module lenet_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4,

		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid
	);
// Instantiation of Axi Bus Interface S00_AXI
	lenet_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) lenet_v1_0_S00_AXI_inst (
		.lenet_status(lenet_status),
		.reset_lenet(reset_lenet),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

// Instantiation of Axi Bus Interface S00_AXIS
	lenet_v1_0_S00_AXIS # ( 
		.C_S_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH)
	) lenet_v1_0_S00_AXIS_inst (
		.lenet_busy(0),
		.lenet_data(lenet_data),
		.lenet_data_valid(lenet_data_valid),
		.S_AXIS_ACLK(s00_axis_aclk),
		.S_AXIS_ARESETN(s00_axis_aresetn),
		.S_AXIS_TREADY(s00_axis_tready),
		.S_AXIS_TDATA(s00_axis_tdata),
		.S_AXIS_TSTRB(s00_axis_tstrb),
		.S_AXIS_TLAST(s00_axis_tlast),
		.S_AXIS_TVALID(s00_axis_tvalid)
	);

	// Add user logic here
	wire [31:0] lenet_status;
	wire reset_lenet;
	wire [7:0] lenet_data;
	wire lenet_data_valid;
	wire [3:0] result;
	wire cnv_busy;
	wire cnv_done;
	wire den_done;
	wire [7:0] cnv_debug;
	wire [7:0] dense_debug;

	assign lenet_status = {	dense_debug, 
							cnv_debug, 
							4'b0, 
							lenet_data_valid, cnv_busy, cnv_done, den_done, 
							4'h0, 
							result};
	
    asploc_cnn_top asploc_cnn_top_inst(
        .clk(s00_axis_aclk),
        .rst_n(s00_axis_aresetn),
        .img_data_top_i(lenet_data),
        .load_sw_img_top_i(lenet_data_valid),
        .read_result_top_i(reset_lenet),
        .conv_busy_top_o(cnv_busy),
        .conv_done_top_o(cnv_done),
        .dense_done_top_o(den_done),
        .result_top_o(result),
		.conv_debug_o(cnv_debug),
		.dense_debug_o(dense_debug)
    );
	
	// // check the image data is passing to HW correctly, uncomment this section and comment 
	// //   lenet_status assignment above. assign .lenet_busy(~read_to_sw_v), in AXIS_S00
	// reg [7:0] read_to_sw;
	// reg read_to_sw_v;
	// reg reset_lenet_r;

	// assign lenet_status = {23'h0, reset_lenet_r, read_to_sw};


	// always @(posedge s00_axis_aclk, negedge s00_axis_aresetn) begin
	// 	if (!s00_axis_aresetn) begin
	// 		read_to_sw   <= 0;
	// 		read_to_sw_v <= 0;
	// 		reset_lenet_r <= 0;
	// 	end else begin
	// 		reset_lenet_r <= reset_lenet;
	// 		read_to_sw <= lenet_data;
	// 		if (reset_lenet && ~reset_lenet_r) begin
	// 			read_to_sw_v <= 1;
	// 		end else begin
	// 			read_to_sw_v <= 0;
	// 		end
	// 	end
	// end

	
	// // check the convolution result, uncomment this section and comment 
	// //   lenet_status assignment above. assign .lenet_busy(~read_to_sw_v), in AXIS_S00
	// reg [7:0] read_to_sw;
	// reg read_to_sw_v;
	// reg reset_lenet_r;
	// wire [7:0] conv_img;

	// assign lenet_status = {23'h0, reset_lenet_r, read_to_sw};


	// always @(posedge s00_axis_aclk, negedge s00_axis_aresetn) begin
	// 	if (!s00_axis_aresetn) begin
	// 		read_to_sw   <= 0;
	// 		read_to_sw_v <= 0;
	// 		reset_lenet_r <= 0;
	// 	end else begin
	// 		reset_lenet_r <= reset_lenet;
	// 		read_to_sw <= conv_img;
	// 		if (reset_lenet && ~reset_lenet_r) begin
	// 			read_to_sw_v <= 1;
	// 		end else begin
	// 			read_to_sw_v <= 0;
	// 		end
	// 	end
	// end

	// User logic ends

	endmodule
