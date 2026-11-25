

// JasperGold-compatible parameter-selection and timing-range assertions
// Intended parameters:
// Full-Speed : 17 .. 54 cycles
// Low-Speed  : 134 .. 433 cycles
// High-Speed : 2 .. 40 cycles

module bt_top_sva #(
    parameter logic [1:0] SPEED_FULL = 2'b00,
    parameter logic [1:0] SPEED_LOW  = 2'b01,
    parameter logic [1:0] SPEED_HIGH = 2'b10,

    parameter logic [31:0] FS_MIN = 32'd17,
    parameter logic [31:0] FS_MAX = 32'd54,
    parameter logic [31:0] LS_MIN = 32'd134,
    parameter logic [31:0] LS_MAX = 32'd433,
    parameter logic [31:0] HS_MIN = 32'd2,
    parameter logic [31:0] HS_MAX = 32'd40,
    parameter integer MAX_WAIT = 500,
    parameter integer CW       = 32      // = bt_top COUNTER_WIDTH
)(
    input logic clk,
    input logic rst_n,

    input logic [1:0] speed_cfg,
    input logic transaction_start,
    input logic packet_valid,
    input logic [CW-1:0] active_min,
    input logic [CW-1:0] active_max,
    input logic [CW-1:0] elapsed_count,

    input logic timing_check_en,
    input logic time_ok,
    input logic time_error,

    input logic bt_timing_valid,
    input logic bt_timeout_status,

    input logic phy_eop_ref,
    input logic [3:0] packet_pid,

    // Probed from bt_fsm_controller (plain signals, no expressions in the bind)
    input logic relevant_eop,
    input logic data_expected,
    input logic [1:0] fsm_state          // bt_fsm_controller.state (WAIT_EOP_REF = 1)
);

    localparam logic [3:0] PID_OUT   = 4'b0001;
    localparam logic [3:0] PID_IN    = 4'b1001;
    localparam logic [3:0] PID_SETUP = 4'b1101;

    localparam logic [1:0] ST_IDLE = 2'd0;
    localparam logic [1:0] ST_WAIT = 2'd1;

    // The FSM overwrites its active_packet_pid with the DATA PID, so the
    // token type is remembered here, exactly when the FSM accepts the token.
    logic [3:0] tok_pid_q;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)
            tok_pid_q <= 4'h0;
        else if (fsm_state == ST_IDLE && transaction_start)
            tok_pid_q <= packet_pid;

    // A reference only counts when the FSM is really waiting for it
    // (relevant_eop alone is also true for stray EOPs while idle).
    wire ref_ok          = (fsm_state == ST_WAIT) && relevant_eop;
    wire in_reference    = ref_ok && (tok_pid_q == PID_IN);
    wire out_reference   = ref_ok && data_expected && (tok_pid_q == PID_OUT);
    wire setup_reference = ref_ok && data_expected && (tok_pid_q == PID_SETUP);

    // Watchdogs: after a reference, a verdict must follow within MAX_WAIT
    // cycles. Constant-size logic, no long ##[m:n] ranges.
    logic        in_p, out_p, setup_p;
    logic [15:0] in_c, out_c, setup_c;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_p <= 1'b0;    in_c <= 16'd0;
            out_p <= 1'b0;   out_c <= 16'd0;
            setup_p <= 1'b0; setup_c <= 16'd0;
        end else begin
            if (in_reference)         begin in_p <= 1'b1;    in_c <= 16'd0; end
            else if (bt_timing_valid)       in_p <= 1'b0;
            else if (in_p && in_c <= MAX_WAIT)       in_c <= in_c + 16'd1;

            if (out_reference)        begin out_p <= 1'b1;   out_c <= 16'd0; end
            else if (bt_timing_valid)       out_p <= 1'b0;
            else if (out_p && out_c <= MAX_WAIT)     out_c <= out_c + 16'd1;

            if (setup_reference)      begin setup_p <= 1'b1; setup_c <= 16'd0; end
            else if (bt_timing_valid)       setup_p <= 1'b0;
            else if (setup_p && setup_c <= MAX_WAIT) setup_c <= setup_c + 16'd1;
        end
    end

    // ---------------------------------------------------------
    // 1. Check that the DUT selects the intended turnaround
    //    minimum and maximum values when a transaction starts.
    // ---------------------------------------------------------
    property p_fs_parameter_selection;
        @(posedge clk) disable iff (!rst_n)
        (transaction_start && speed_cfg == SPEED_FULL)
        |=> (active_min == FS_MIN && active_max == FS_MAX);
    endproperty

    ap_fs_parameter_selection:
        assert property (p_fs_parameter_selection);

    property p_ls_parameter_selection;
        @(posedge clk) disable iff (!rst_n)
        (transaction_start && speed_cfg == SPEED_LOW)
        |=> (active_min == LS_MIN && active_max == LS_MAX);
    endproperty

    ap_ls_parameter_selection:
        assert property (p_ls_parameter_selection);

    property p_hs_parameter_selection;
        @(posedge clk) disable iff (!rst_n)
        (transaction_start && speed_cfg == SPEED_HIGH)
        |=> (active_min == HS_MIN && active_max == HS_MAX);
    endproperty

    ap_hs_parameter_selection:
        assert property (p_hs_parameter_selection);

    // ---------------------------------------------------------
    // 2. Check the timer's combinational timing decision.
    //    time_ok must be true exactly inside the active range.
    //    time_error must be true outside the active range.
    // ---------------------------------------------------------
    property p_timing_check_inside_range;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en &&
        (elapsed_count >= active_min) &&
        (elapsed_count <= active_max)
        |-> time_ok && !time_error;
    endproperty

    ap_timing_check_inside_range:
        assert property (p_timing_check_inside_range);

    property p_timing_check_below_minimum;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en && (elapsed_count < active_min)
        |-> !time_ok && time_error;
    endproperty

    ap_timing_check_below_minimum:
        assert property (p_timing_check_below_minimum);

    property p_timing_check_above_maximum;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en && (elapsed_count > active_max)
        |-> !time_ok && time_error;
    endproperty

    ap_timing_check_above_maximum:
        assert property (p_timing_check_above_maximum);

    // ---------------------------------------------------------
    // 3. Timing verdict must be generated when the FSM performs
    //    the turnaround timing check.
    // ---------------------------------------------------------
    property p_timing_valid_after_check;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en |=> bt_timing_valid;
    endproperty

    ap_timing_valid_after_check:
        assert property (p_timing_valid_after_check);

    // If the timing check reports an error, timeout must be
    // asserted with the timing-valid verdict.
    property p_timeout_on_timing_error;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en && time_error
        |=> bt_timing_valid && bt_timeout_status;
    endproperty

    ap_timeout_on_timing_error:
        assert property (p_timeout_on_timing_error);

    // If the measured turnaround is within the active range,
    // the timing check must not report a timeout.
    property p_no_timeout_on_valid_timing;
        @(posedge clk) disable iff (!rst_n)
        timing_check_en && time_ok
        |=> bt_timing_valid && !bt_timeout_status;
    endproperty

    ap_no_timeout_on_valid_timing:
        assert property (p_no_timeout_on_valid_timing);

    // ---------------------------------------------------------
    // 4. IN: after the IN token's EOP reference, a verdict follows
    //    (response measured, or timeout) within MAX_WAIT cycles.
    // ---------------------------------------------------------
    property p_in_transaction;
        @(posedge clk) disable iff (!rst_n)
        (in_p && !bt_timing_valid) |-> (in_c < MAX_WAIT);
    endproperty

    ap_in_transaction:
        assert property (p_in_transaction);

    // ---------------------------------------------------------
    // 5. OUT: after the DATA packet's EOP reference
    // ---------------------------------------------------------
    property p_out_transaction;
        @(posedge clk) disable iff (!rst_n)
        (out_p && !bt_timing_valid) |-> (out_c < MAX_WAIT);
    endproperty

    ap_out_transaction:
        assert property (p_out_transaction);

    // ---------------------------------------------------------
    // 6. SETUP: after the DATA packet's EOP reference
    // ---------------------------------------------------------
    property p_setup_transaction;
        @(posedge clk) disable iff (!rst_n)
        (setup_p && !bt_timing_valid) |-> (setup_c < MAX_WAIT);
    endproperty

    ap_setup_transaction:
        assert property (p_setup_transaction);

endmodule


// Bind to the actual bt_top RTL hierarchy.
// Uses the intended turnaround timing values in the checker.

bind bt_top bt_top_sva #(
    .SPEED_FULL (SPEED_FULL),
    .SPEED_LOW  (SPEED_LOW),
    .SPEED_HIGH (SPEED_HIGH),

    .FS_MIN     (32'd17),
    .FS_MAX     (32'd54),
    .LS_MIN     (32'd134),
    .LS_MAX     (32'd433),
    .HS_MIN     (32'd2),
    .HS_MAX     (32'd40),
    .MAX_WAIT   (500),
    .CW         (COUNTER_WIDTH)
) u_bt_top_turnaround_parameter_sva (
    .clk                (clk),
    .rst_n              (rst_n),

    .speed_cfg          (speed_cfg),
    .transaction_start  (transaction_start),
    .packet_valid       (packet_valid),
    .packet_pid         (packet_pid),
    .phy_eop_ref        (phy_eop_ref),

    .active_min         (active_min),
    .active_max         (active_max),
    .elapsed_count      (elapsed_count),

    .timing_check_en    (timing_check_en),
    .time_ok            (time_ok),
    .time_error         (time_error),

    .bt_timing_valid    (bt_timing_valid),
    .bt_timeout_status  (bt_timeout_status),

    .relevant_eop       (u_bt_fsm_controller.relevant_eop),
    .data_expected      (u_bt_fsm_controller.data_expected),
    .fsm_state          (u_bt_fsm_controller.state)
);

