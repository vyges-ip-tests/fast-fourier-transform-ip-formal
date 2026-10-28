	// vyges formal monitor for fft_control (interrupt status).
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~reset_n_i;

	// C1 interrupt status is clear on the first cycle after reset
	wire vf_p_c1_int_status_reset = vf_rst_q & (int_status_reg != 8'd0);

	// C6 an enabled done event is visible in INT_STATUS[0] on the next cycle
	reg vf_done_en_q;
	always @(posedge clk_i) vf_done_en_q <= fft_done_i & int_enable_i[0] & reset_n_i;
	wire vf_p_c6_done_sets_int_status = vf_done_en_q & ~int_status_reg[0];
	// C6 interrupt status, once set, stays set until software can observe it (two cycles or more)
	reg vf_pend_q;
	always @(posedge clk_i) vf_pend_q <= int_status_reg[0];
	reg vf_pend_qq;
	always @(posedge clk_i) vf_pend_qq <= vf_pend_q;
	wire vf_p_c6_int_status_held = vf_pend_q & ~vf_pend_qq & ~int_status_reg[0];
