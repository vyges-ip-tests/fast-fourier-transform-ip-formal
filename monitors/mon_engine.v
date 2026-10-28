	// vyges formal monitor for fft_engine (spliced before endmodule; sees the module's nets).
	// vf_p_<id>: property violated now · vf_c_<id>: cover hit now · vf_a_<id>: assumption holds now.

	// first cycle after reset release
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~reset_n_i;

	// START handling assumed of software: START may stay high from launch, but once it is low
	// during a run it is not raised again until the engine is idle.
	reg vf_start_dropped;
	always @(posedge clk_i)
		if (~reset_n_i | ~fft_busy_o) vf_start_dropped <= 1'b0;
		else if (~fft_start_i) vf_start_dropped <= 1'b1;
	wire vf_a_start_once = ~(fft_busy_o & vf_start_dropped & fft_start_i);
	// this build is 1024-point max; the spec range is 256..1024 points
	wire vf_a_legal_len = ~fft_start_i | ((fft_length_log2_i >= 12'd8) & (fft_length_log2_i <= 12'd10));

	// C1 reset: control state, counters and write strobe are clear on the first cycle after reset
	wire vf_p_c1_engine_reset_state = vf_rst_q & ((fft_state != 3'd0) | (stage_counter != 12'd0) |
		(butterfly_counter != 12'd0) | mem_write_i | (scale_factor_reg != 8'd0));

	// C2 done is reported only once every stage has run (raw: any software; c2: with start_once)
	wire vf_p_c2_done_after_last_stage_raw = fft_done_o & (stage_counter < fft_length_log2_reg);
	wire vf_p_c2_done_after_last_stage = fft_done_o & (stage_counter < fft_length_log2_reg);
	// C2 done is a single-cycle event
	reg vf_done_q;
	always @(posedge clk_i) vf_done_q <= fft_done_o;
	wire vf_p_c2_done_single_cycle = fft_done_o & vf_done_q;

	// C3 bounded response: once START is released, a run ends within 5300 cycles
	// (1024 points: 10 stages x 512 butterflies at one per cycle, plus pipeline fill)
	reg [12:0] vf_run_cnt;
	always @(posedge clk_i)
		if (~reset_n_i | ~fft_busy_o | fft_start_i) vf_run_cnt <= 13'd0;
		else if (vf_run_cnt != 13'h1fff) vf_run_cnt <= vf_run_cnt + 13'd1;
	wire vf_p_c3_completes_within_bound = (vf_run_cnt > 13'd5300);

	// C4 every data write lands inside the configured N-point buffer
	wire vf_p_c4_write_addr_in_range = mem_write_i & (mem_addr_i >= (16'd1 << fft_length_log2_reg));
	// C4 results are written back in place, to the butterfly's own address
	reg [15:0] vf_wb_addr;
	always @(posedge clk_i) vf_wb_addr <= pipeline_addr_a_4;
	wire vf_p_c4_writeback_in_place = mem_write_i & (mem_addr_i != vf_wb_addr);

	// C5 the scale factor never wraps
	wire vf_p_c5_scale_factor_no_wrap = scale_track_en_reg & scale_factor_increment &
		(scale_factor_reg == 8'hff) & ~fft_start_i;

	// covers
	wire vf_c_cov_done_any = fft_done_o;
	wire vf_c_cov_done_legal = fft_done_o;
	wire vf_c_cov_error = fft_error_o;
	wire vf_c_cov_rescale = rescaling_active_reg;
	// no abort: neither CTRL.reset nor a second block reset once the block has come out of reset
	reg vf_na_up;
	always @(posedge clk_i) vf_na_up <= vf_na_up | reset_n_i;
	reg vf_na_rst2;
	always @(posedge clk_i) vf_na_rst2 <= vf_na_rst2 | (vf_na_up & ~reset_n_i);
	wire vf_a_no_abort = ~fft_reset_i & ~vf_na_rst2 & ~(vf_na_up & ~reset_n_i);
	wire vf_p_c4_writeback_in_place_no_abort = mem_write_i & (mem_addr_i != vf_wb_addr);
	wire vf_p_c4_write_addr_in_range_no_abort = mem_write_i & (mem_addr_i >= (16'd1 << fft_length_log2_reg));
	wire vf_c_cov_done_legal_no_abort = fft_done_o;
