	// vyges formal monitor for fft_control (interrupt status).
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~reset_n_i;

	// C1 interrupt status is clear on the first cycle after reset
	wire vf_p_c1_int_status_reset = vf_rst_q & (int_status_reg != 8'd0);

	// C6 an enabled done event is visible in INT_STATUS[0] on the next cycle
	reg vf_done_en_q;
	always @(posedge clk_i) vf_done_en_q <= fft_done_i & int_enable_i[0] & reset_n_i;
	wire vf_p_c6_done_sets_int_status = vf_done_en_q & ~int_status_reg[0];

	// C6 INT_STATUS[0], once set, stays set until software writes 1 to it
	reg vf_pend_q, vf_clr_q, vf_en_q, vf_rn_q;
	always @(posedge clk_i) begin
		vf_pend_q <= int_status_reg[0];
		vf_clr_q <= int_status_clear_i[0];
		vf_en_q <= int_enable_i[0];
		vf_rn_q <= reset_n_i;
	end
	wire vf_p_c6_int_status_held = vf_pend_q & ~int_status_reg[0] & ~vf_clr_q & reset_n_i & vf_rn_q;
	// C6 INT_STATUS[0] is set only while its interrupt is enabled
	wire vf_p_c6_int_status_set_only_when_enabled = ~vf_pend_q & int_status_reg[0] & ~vf_en_q & vf_rn_q;

	// covers
	wire vf_c_cov_int_cleared = vf_pend_q & ~int_status_reg[0] & vf_clr_q;
