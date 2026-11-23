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
    parameter integer MAX_WAIT = 500
)(
    input logic clk,
    input logic rst_n,

    input logic [1:0] speed_cfg,
    input logic transaction_start,
    input logic packet_valid,
    input logic [31:0] active_min,
    input logic [31:0] active_max,
    input logic [31:0] elapsed_count,

    input logic timing_check_en,
    input logic time_ok,
    input logic time_error,

    input logic bt_timing_valid,
    input logic bt_timeout_status,

    // Transaction reference events derived from the FSM
    input logic in_reference,
    input logic out_reference,
    input logic setup_reference,
    input logic [3:0] packet_pid
);

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
    // 4. IN Transaction
    // ---------------------------------------------------------
    property p_in_transaction;
        @(posedge clk) disable iff (!rst_n)
        (packet_valid && packet_pid == 4'b1001)
        |-> ##[1:MAX_WAIT]
            in_reference
            ##[1:MAX_WAIT]
            bt_timing_valid;
    endproperty

    ap_in_transaction:
        assert property (p_in_transaction);

    // ---------------------------------------------------------
    // 5. OUT Transaction
    // ---------------------------------------------------------
    property p_out_transaction;
        @(posedge clk) disable iff (!rst_n)
        (packet_valid && packet_pid == 4'b0001)
        |-> ##[1:MAX_WAIT]
            out_reference
            ##[1:MAX_WAIT]
            bt_timing_valid;
    endproperty

    ap_out_transaction:
        assert property (p_out_transaction);

    // ---------------------------------------------------------
    // 6. SETUP Transaction
    // ---------------------------------------------------------
    property p_setup_transaction;
        @(posedge clk) disable iff (!rst_n)
        (packet_valid && packet_pid == 4'b1101)
        |-> ##[1:MAX_WAIT]
            setup_reference
            ##[1:MAX_WAIT]
            bt_timing_valid;
    endproperty

    ap_setup_transaction:
        assert property (p_setup_transaction);

endmodule


// Bind to the actual bt_top RTL hierarchy.
// Uses the intended turnaround timing values in the checker.

bind bt_top bt_top_sva #(
    .SPEED_FULL (2'b00),
    .SPEED_LOW  (2'b01),
    .SPEED_HIGH (2'b10),

    .FS_MIN     (32'd17),
    .FS_MAX     (32'd54),

    .LS_MIN     (32'd134),
    .LS_MAX     (32'd433),

    .HS_MIN     (32'd2),
    .HS_MAX     (32'd40),
    .MAX_WAIT   (500)
) u_bt_top_turnaround_parameter_sva (
    .clk                (clk),
    .rst_n              (rst_n),
    .packet_valid       (packet_valid),
    .speed_cfg          (speed_cfg),
    .transaction_start  (transaction_start),

    .active_min         (active_min),
    .active_max         (active_max),
    .elapsed_count      (elapsed_count),

    .timing_check_en    (timing_check_en),
    .time_ok            (time_ok),
    .time_error         (time_error),

    .bt_timing_valid    (bt_timing_valid),
    .bt_timeout_status  (bt_timeout_status),

    .in_reference       (u_bt_fsm_controller.relevant_eop &&
                         u_bt_fsm_controller.active_packet_pid == 4'b1001),
    .out_reference      (u_bt_fsm_controller.relevant_eop &&
                         u_bt_fsm_controller.active_packet_pid == 4'b0001 &&
                         u_bt_fsm_controller.data_expected),
    .setup_reference    (u_bt_fsm_controller.relevant_eop &&
                         u_bt_fsm_controller.active_packet_pid == 4'b1101 &&
                         u_bt_fsm_controller.data_expected),
    .packet_pid         (packet_pid)
);

