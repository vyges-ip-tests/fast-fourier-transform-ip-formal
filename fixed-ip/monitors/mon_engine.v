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
	wire vf_p_c1_engine_reset_state = vf_rst_q & ((fft_state != 3'd0) | (stage_counter != 4'd0) |
		(butterfly_counter != 10'd0) | mem_write_i | (scale_factor_reg != 8'd0));

	// Stage bookkeeping invariant. C2 and C5 below are each checked as "claim violated OR invariant
	// broken": the invariant is inductive, the bare claims are not, and proving the stronger
	// statement proves the claim. In words: a run that is past CONFIG has a legal latched length;
	// the completed-stage count equals the stage counter while computing and log2(N) once the
	// stages are done; it is 0 before the first stage and after a rejected length; and the scale
	// factor never exceeds the completed-stage count.
	wire vf_len_legal = (fft_length_log2_reg >= 12'd1) & (fft_length_log2_reg <= 12'd10);
	wire [7:0] vf_len8 = {4'd0, fft_length_log2_reg[3:0]};
	wire vf_inv_ok =
		((fft_state < 3'd2) | (fft_state == 3'd7) | vf_len_legal) &
		(((fft_state != 3'd1) & (fft_state != 3'd2) & (fft_state != 3'd3)) |
			((stage_counter == 4'd0) & (stage_count_reg == 8'd0))) &
		((fft_state != 3'd7) | (stage_count_reg == 8'd0)) &
		((fft_state != 3'd4) | ((stage_count_reg == {4'd0, stage_counter}) & ({4'd0, stage_counter} < vf_len8))) &
		(((fft_state != 3'd5) & (fft_state != 3'd6)) | (stage_count_reg == vf_len8)) &
		((fft_state != 3'd0) | (stage_count_reg == 8'd0) | (vf_len_legal & (stage_count_reg <= vf_len8))) &
		(scale_factor_reg <= stage_count_reg);

	// C2 done is reported only once every stage of the latched length has run (any software)
	wire vf_p_c2_done_after_last_stage_raw = (fft_done_o & ({4'd0, stage_count_reg} != fft_length_log2_reg)) | ~vf_inv_ok;
	// C2 done is a single-cycle event
	reg vf_done_q;
	always @(posedge clk_i) vf_done_q <= fft_done_o;
	wire vf_p_c2_done_single_cycle = fft_done_o & vf_done_q;
	// C2 the length the run uses does not change while the run is in progress
	reg [11:0] vf_len_q;
	reg vf_busy_q;
	always @(posedge clk_i) begin
		vf_len_q <= fft_length_log2_reg;
		vf_busy_q <= fft_busy_o;
	end
	wire vf_p_c2_config_latched = vf_busy_q & fft_busy_o & (fft_length_log2_reg != vf_len_q);
	// C2 done only after the bit-reverse pass has reached the last word
	wire vf_p_c2_done_after_reorder = fft_done_o & (index_counter != last_index);

	// C3 bounded response: once START is released, a run of a legal length ends within 35000
	// cycles (1024 points: input scan ~1k, 10 stages x 512 butterflies x 6 cycles, reorder ~3k)
	reg [15:0] vf_run_cnt;
	always @(posedge clk_i)
		if (~reset_n_i | ~fft_busy_o | fft_start_i) vf_run_cnt <= 16'd0;
		else if (vf_run_cnt != 16'hffff) vf_run_cnt <= vf_run_cnt + 16'd1;
	wire vf_p_c3_completes_within_bound = (vf_run_cnt > 16'd35000);

	// C4 every data write lands inside the configured N-point buffer
	wire vf_p_c4_write_addr_in_range = mem_write_i & (mem_addr_i >= (16'd1 << fft_length_log2_reg));
	// C4 results are written back in place: the first write of a pair goes to the first of the
	// two data words just read, the second write to the second (butterflies and reorder swaps)
	reg [15:0] vf_rd1, vf_rd2;
	reg vf_wr_q;
	always @(posedge clk_i) begin
		vf_wr_q <= mem_write_i;
		if (~mem_write_i & (mem_addr_i < 16'h1000) & (mem_addr_i != vf_rd1)) begin
			vf_rd2 <= vf_rd1;
			vf_rd1 <= mem_addr_i;
		end
	end
	wire vf_p_c4_writeback_in_place = mem_write_i & (vf_wr_q ? (mem_addr_i != vf_rd1) : (mem_addr_i != vf_rd2));
	// C4 the engine writes only while it is computing or reordering, never when idle or done
	wire vf_p_c4_write_only_during_run = mem_write_i & (fft_state != 3'd4) & (fft_state != 3'd5);
	// C4 the cycle after CTRL.reset, no write is issued
	reg vf_abort_q;
	always @(posedge clk_i) vf_abort_q <= fft_reset_i & reset_n_i;
	wire vf_p_c4_no_write_after_abort = vf_abort_q & mem_write_i;

	// C5 the scale factor never exceeds log2(N), so it never wraps
	wire vf_p_c5_scale_factor_no_wrap = ({4'd0, scale_factor_reg} > fft_length_log2_reg) | ~vf_inv_ok;

	// covers
	wire vf_c_cov_done_any = fft_done_o;
	wire vf_c_cov_done_legal = fft_done_o;
	wire vf_c_cov_error = fft_error_o;
	wire vf_c_cov_rescale = rescaling_active_o;
	wire vf_c_cov_reorder_swap = (fft_state == 3'd5) & mem_write_i;
