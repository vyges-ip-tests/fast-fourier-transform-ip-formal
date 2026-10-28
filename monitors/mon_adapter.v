	// vyges formal monitor for tlul_apb_adapter: TL-UL device-side rules and APB master rules.
	reg vf_rst_q;
	always @(posedge clk_i) vf_rst_q <= ~rst_ni;

	wire vf_a_acc = tl_a_valid_i & tl_a_ready_o;
	wire vf_d_acc = tl_d_valid_o & tl_d_ready_i;
	reg [1:0] vf_out;
	reg vf_req_wr;
	reg [7:0] vf_req_src;
	reg [1:0] vf_req_size;
	always @(posedge clk_i)
		if (~rst_ni) vf_out <= 2'd0;
		else vf_out <= vf_out + {1'b0, vf_a_acc} - {1'b0, vf_d_acc};
	always @(posedge clk_i)
		if (vf_a_acc) begin
			vf_req_wr <= is_write;
			vf_req_src <= tl_a_source_i;
			vf_req_size <= tl_a_size_i;
		end

	// C1 after reset: ready for a request, no response pending
	wire vf_p_c1_adapter_reset = vf_rst_q & (~tl_a_ready_o | tl_d_valid_o | apb_psel_o);

	// C6 TL-UL: no response without an outstanding request; at most one outstanding
	wire vf_p_c6_tl_no_unsolicited_response = tl_d_valid_o & (vf_out == 2'd0);
	wire vf_p_c6_tl_single_outstanding = (vf_out > 2'd1);
	// C6 TL-UL: response opcode, source and size match the request
	wire vf_p_c6_tl_response_matches_request = tl_d_valid_o & ((tl_d_opcode_o != (vf_req_wr ? 3'h0 : 3'h1)) |
		(tl_d_source_o != vf_req_src) | (tl_d_size_o != vf_req_size));
	// C6 TL-UL: the D channel holds steady while valid and not accepted
	reg vf_d_stall_q;
	reg [47:0] vf_d_q;
	wire [47:0] vf_d_now = {tl_d_opcode_o, tl_d_param_o, tl_d_size_o, tl_d_source_o, tl_d_error_o, tl_d_data_o};
	always @(posedge clk_i) begin
		vf_d_stall_q <= tl_d_valid_o & ~tl_d_ready_i & rst_ni;
		vf_d_q <= vf_d_now;
	end
	wire vf_p_c6_tl_d_stable = vf_d_stall_q & (~tl_d_valid_o | (vf_d_now != vf_d_q));

	// C6 APB master: an access phase follows a setup phase (or a waiting access)
	reg vf_psel_q;
	reg vf_pdone_q;
	reg [64:0] vf_apb_q;
	wire [64:0] vf_apb_now = {apb_pwrite_o, apb_paddr_o, apb_pwdata_o};
	always @(posedge clk_i) begin
		vf_psel_q <= apb_psel_o;
		vf_pdone_q <= apb_psel_o & apb_penable_o & apb_pready_i;
		vf_apb_q <= vf_apb_now;
	end
	wire vf_p_c6_apb_access_after_setup = apb_penable_o & ~vf_psel_q;
	// C6 APB master: address, direction and write data are stable for the whole transfer
	wire vf_p_c6_apb_stable = vf_psel_q & ~vf_pdone_q & apb_psel_o & (vf_apb_now != vf_apb_q);

	// covers
	wire vf_c_cov_tl_write_ack = tl_d_valid_o & (tl_d_opcode_o == 3'h0);
	wire vf_c_cov_tl_read_data = tl_d_valid_o & (tl_d_opcode_o == 3'h1);
