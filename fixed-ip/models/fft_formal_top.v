// fft_formal_top — fft_top integrated the way the Edge Sensor SoC integrates it, for the proof.
//
// One clock and one reset: the APB port runs on the core clock and reset (the IP assumes
// pclk_i == clk_i), and the AXI port is tied off. APB inputs and SRAM read data stay free
// inputs, so the bus may do anything the APB signals allow and memory may return any data.
module fft_formal_top (
    input  wire        clk_i,
    input  wire        reset_n_i,
    input  wire        psel_i,
    input  wire        penable_i,
    input  wire        pwrite_i,
    input  wire [15:0] paddr_i,
    input  wire [31:0] pwdata_i,
    output wire [31:0] prdata_o,
    output wire        pready_o,
    output wire        fft_done_o,
    output wire        fft_error_o,
    output wire        sram_clk_o,
    output wire [9:0]  sram_addr_o,
    output wire [31:0] sram_wdata_o,
    output wire [31:0] sram_ben_o,
    output wire        sram_rwb_o,
    output wire [1:0]  sram_en_o,
    input  wire [31:0] sram_rdata0_i,
    input  wire [31:0] sram_rdata1_i
);
    fft_top #(
        .FFT_MAX_LENGTH_LOG2(10),
        .FFT_DATA_WIDTH(16),
        .FFT_TWIDDLE_WIDTH(16)
    ) u_fft_top (
        .clk_i(clk_i), .reset_n_i(reset_n_i),
        .pclk_i(clk_i), .preset_n_i(reset_n_i),
        .psel_i(psel_i), .penable_i(penable_i), .pwrite_i(pwrite_i),
        .paddr_i(paddr_i), .pwdata_i(pwdata_i), .prdata_o(prdata_o), .pready_o(pready_o),
        .axi_aclk_i(clk_i), .axi_areset_n_i(reset_n_i),
        .axi_awaddr_i(32'd0), .axi_awvalid_i(1'b0), .axi_awready_o(),
        .axi_wdata_i(64'd0), .axi_wvalid_i(1'b0), .axi_wready_o(),
        .axi_araddr_i(32'd0), .axi_arvalid_i(1'b0), .axi_arready_o(),
        .axi_rdata_o(), .axi_rvalid_o(), .axi_rready_i(1'b0),
        .fft_done_o(fft_done_o), .fft_error_o(fft_error_o),
        .sram_clk_o(sram_clk_o), .sram_addr_o(sram_addr_o), .sram_wdata_o(sram_wdata_o),
        .sram_ben_o(sram_ben_o), .sram_rwb_o(sram_rwb_o), .sram_en_o(sram_en_o),
        .sram_rdata0_i(sram_rdata0_i), .sram_rdata1_i(sram_rdata1_i),
        .bin_valid_o(), .bin_ready_i(1'b0), .bin_index_o(), .bin_last_o(),
        .bin_re_o(), .bin_im_o()
    );
endmodule
