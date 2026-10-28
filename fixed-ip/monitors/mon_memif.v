	// vyges formal monitor for memory_interface (APB register slave + SRAM address decode).
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~reset_n_i;

	// C1 registers hold their documented reset values on the first cycle after reset
	wire vf_p_c1_regs_reset_values = vf_rst_q & ((fft_ctrl_reg != 32'd0) | (fft_config_reg != 32'd0) |
		(fft_length_reg != 32'h400) | (int_enable_reg != 32'd0) | pready_o);

	// C4 engine data writes never land in the twiddle bank (bank 1)
	wire vf_p_c4_no_data_write_to_twiddle_bank = mem_write_i & ~apb_twiddle_wr & mem_idx[10];

	// APB master behaviour assumed of the bus (AMBA APB): once PSEL and PENABLE are up, the
	// master holds them, with address, direction and write data, until the slave raises PREADY.
	reg vf_wait_q, vf_pw_q;
	reg [15:0] vf_pa_q;
	reg [31:0] vf_wd_q;
	always @(posedge clk_i) begin
		vf_wait_q <= psel_i & penable_i & ~pready_o & reset_n_i;
		vf_pa_q <= paddr_i;
		vf_pw_q <= pwrite_i;
		vf_wd_q <= pwdata_i;
	end
	wire vf_a_apb_master = ~vf_wait_q | (psel_i & penable_i & (paddr_i == vf_pa_q) &
		(pwrite_i == vf_pw_q) & (pwdata_i == vf_wd_q));

	// C6 a control register changes only on a completed APB write to its address
	reg [31:0] vf_ctrl_q;
	reg vf_ctrl_wr_q;
	always @(posedge clk_i) begin
		vf_ctrl_q <= fft_ctrl_reg;
		vf_ctrl_wr_q <= psel_i & penable_i & pwrite_i & pready_o & (paddr_i == 16'h0000);
	end
	wire vf_p_c6_ctrl_written_only_by_apb = (fft_ctrl_reg != vf_ctrl_q) & ~vf_ctrl_wr_q;

	// C6 FFT_STATUS.done, once set, stays set until the next run starts
	reg vf_sd_q, vf_sbusy_q, vf_rn_q;
	always @(posedge clk_i) begin
		vf_sd_q <= status_done_q;
		vf_sbusy_q <= fft_busy_i;
		vf_rn_q <= reset_n_i;
	end
	wire vf_p_c6_status_done_held = vf_sd_q & ~status_done_q & ~vf_sbusy_q & reset_n_i & vf_rn_q;

	// covers
	wire vf_c_cov_twiddle_load = apb_twiddle_wr;
