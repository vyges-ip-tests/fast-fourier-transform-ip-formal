	// vyges formal monitor for memory_interface (APB register slave + SRAM address decode).
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~reset_n_i;

	reg vf_start_dropped;
	always @(posedge clk_i)
		if (~reset_n_i | ~fft_busy_i) vf_start_dropped <= 1'b0;
		else if (~fft_start_o) vf_start_dropped <= 1'b1;
	wire vf_a_start_once = ~(fft_busy_i & vf_start_dropped & fft_start_o);
	wire vf_a_legal_len = ~fft_start_o | ((fft_length_log2_o >= 12'd8) & (fft_length_log2_o <= 12'd10));

	// C1 registers hold their documented reset values on the first cycle after reset
	wire vf_p_c1_regs_reset_values = vf_rst_q & ((fft_ctrl_reg != 32'd0) | (fft_config_reg != 32'd0) |
		(fft_length_reg != 32'h400) | (int_enable_reg != 32'd0) | pready_o);

	// C4 engine data writes never land in the twiddle bank (bank 1)
	wire vf_p_c4_no_data_write_to_twiddle_bank = mem_write_i & ~apb_twiddle_wr & mem_idx[10];

	// C6 a control register changes only on a completed APB write to its address
	reg [31:0] vf_ctrl_q;
	reg vf_ctrl_wr_q;
	always @(posedge clk_i) begin
		vf_ctrl_q <= fft_ctrl_reg;
		vf_ctrl_wr_q <= psel_i & penable_i & pwrite_i & pready_o & (paddr_i == 16'h0000);
	end
	wire vf_p_c6_ctrl_written_only_by_apb = (fft_ctrl_reg != vf_ctrl_q) & ~vf_ctrl_wr_q;

	// covers
	wire vf_c_cov_twiddle_load = apb_twiddle_wr;
	// no abort: neither CTRL.reset nor a second block reset once the block has come out of reset
	reg vf_na_up;
	always @(posedge clk_i) vf_na_up <= vf_na_up | reset_n_i;
	reg vf_na_rst2;
	always @(posedge clk_i) vf_na_rst2 <= vf_na_rst2 | (vf_na_up & ~reset_n_i);
	wire vf_a_no_abort = ~fft_reset_o & ~vf_na_rst2 & ~(vf_na_up & ~reset_n_i);
	wire vf_p_c4_no_data_write_to_twiddle_bank_no_abort = mem_write_i & ~apb_twiddle_wr & mem_idx[10];
