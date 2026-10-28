// fft_data_sram — the SRAM bridge FFT_USE_SRAM_MACRO expects, for the proof model.
//
// The IP leaves this module to the SoC. This one is the bridge the Edge Sensor SoC
// uses: two 1024x32 banks outside the block, bank 0 for data (addr_i[10] = 0) and
// bank 1 for twiddles, one-cycle read latency. The banks themselves are not modelled:
// sram_rdata0_i / sram_rdata1_i are free inputs of the top, so every claim must hold
// for ANY data the memory returns.
module fft_data_sram (
    input  wire        clk_i,
    input  wire        reset_n_i,
    input  wire [10:0] addr_i,
    input  wire [31:0] wdata_i,
    input  wire        write_en_i,
    output wire [31:0] rdata_o,
    output wire        sram_clk_o,
    output wire [9:0]  sram_addr_o,
    output wire [31:0] sram_wdata_o,
    output wire [31:0] sram_ben_o,
    output wire        sram_rwb_o,
    output wire [1:0]  sram_en_o,
    input  wire [31:0] sram_rdata0_i,
    input  wire [31:0] sram_rdata1_i
);
    reg bank_sel_q;
    always @(posedge clk_i or negedge reset_n_i)
        if (!reset_n_i) bank_sel_q <= 1'b0;
        else            bank_sel_q <= addr_i[10];

    assign sram_clk_o   = clk_i;
    assign sram_addr_o  = addr_i[9:0];
    assign sram_wdata_o = wdata_i;
    assign sram_ben_o   = 32'hffffffff;
    assign sram_rwb_o   = ~write_en_i;
    assign sram_en_o    = addr_i[10] ? 2'b10 : 2'b01;
    assign rdata_o      = bank_sel_q ? sram_rdata1_i : sram_rdata0_i;
endmodule
