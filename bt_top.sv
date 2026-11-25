
module bt_top #(
    parameter int COUNTER_WIDTH = 32,

    parameter logic [1:0] SPEED_FULL = 2'b00,
    parameter logic [1:0] SPEED_LOW  = 2'b01,
    parameter logic [1:0] SPEED_HIGH = 2'b10,

    parameter logic [1:0] TYPE_CONTROL     = 2'b00,
    parameter logic [1:0] TYPE_BULK        = 2'b01,
    parameter logic [1:0] TYPE_INTERRUPT   = 2'b10,
    parameter logic [1:0] TYPE_ISOCHRONOUS = 2'b11,

    parameter logic [31:0] FS_TURNAROUND_MIN = 32'd0,
    parameter logic [31:0] FS_TURNAROUND_MAX = 32'd0,

    parameter logic [31:0] LS_TURNAROUND_MIN = 32'd0,
    parameter logic [31:0] LS_TURNAROUND_MAX = 32'd0,

    parameter logic [31:0] HS_TURNAROUND_MIN = 32'd0,
    parameter logic [31:0] HS_TURNAROUND_MAX = 32'd0
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [1:0] speed_cfg,
    input  logic [1:0] transaction_type,

    input  logic phy_eop_ref,
    input  logic phy_packet_start,

    input  logic packet_valid,
    input  logic [3:0] packet_pid,
    input  logic packet_error,

    output logic bt_timeout_status,
    output logic bt_timing_valid
);

    localparam logic [3:0] PID_OUT   = 4'b0001;
    localparam logic [3:0] PID_IN    = 4'b1001;
    localparam logic [3:0] PID_SETUP = 4'b1101;

    logic transaction_start;
    logic transaction_qualified;

    logic [COUNTER_WIDTH-1:0] selected_min;
    logic [COUNTER_WIDTH-1:0] selected_max;

    logic [COUNTER_WIDTH-1:0] active_min;
    logic [COUNTER_WIDTH-1:0] active_max;

    logic [COUNTER_WIDTH-1:0] elapsed_count;

    logic timer_clear;
    logic timer_enable;
    logic threshold_reached;

    logic timing_check_en;
    logic time_ok;
    logic time_error;

    always_comb begin
        transaction_qualified = 1'b0;

        if (packet_valid) begin
            case (packet_pid)

                PID_IN: begin
                    transaction_qualified = 1'b1;
                end

                PID_OUT: begin
                    if (transaction_type != TYPE_ISOCHRONOUS)
                        transaction_qualified = 1'b1;
                end

                PID_SETUP: begin
                    transaction_qualified = 1'b1;
                end

                default: begin
                    transaction_qualified = 1'b0;
                end

            endcase
        end
    end

    assign transaction_start = transaction_qualified;

    // Select timing limits based on USB speed.
    always_comb begin
        selected_min = '0;
        selected_max = '0;

        case (speed_cfg)

            SPEED_FULL: begin
                selected_min = COUNTER_WIDTH'(FS_TURNAROUND_MIN);
                selected_max = COUNTER_WIDTH'(FS_TURNAROUND_MAX);
            end

            SPEED_LOW: begin
                selected_min = COUNTER_WIDTH'(LS_TURNAROUND_MIN);
                selected_max = COUNTER_WIDTH'(LS_TURNAROUND_MAX);
            end

            SPEED_HIGH: begin
                selected_min = COUNTER_WIDTH'(HS_TURNAROUND_MIN);
                selected_max = COUNTER_WIDTH'(HS_TURNAROUND_MAX);
            end

            default: begin
                selected_min = '0;
                selected_max = '0;
            end

        endcase
    end

    // Capture timing limits for the active transaction.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_min <= '0;
            active_max <= '0;
        end
        else if (transaction_start) begin
            active_min <= selected_min;
            active_max <= selected_max;
        end
    end

    bt_fsm_controller u_bt_fsm_controller (
        .clk                (clk),
        .rst_n              (rst_n),

        .transaction_start  (transaction_start),

        .phy_eop_ref        (phy_eop_ref),
        .phy_packet_start   (phy_packet_start),

        .packet_valid       (packet_valid),
        .packet_pid         (packet_pid),
        .packet_error       (packet_error),

        .threshold_reached  (threshold_reached),

        .time_ok            (time_ok),
        .time_error         (time_error),

        .timer_clear        (timer_clear),
        .timer_enable       (timer_enable),
        .timing_check_en    (timing_check_en),

        .bt_timeout_status  (bt_timeout_status),
        .bt_timing_valid    (bt_timing_valid)
    );

    bt_timer #(
        .COUNTER_WIDTH (COUNTER_WIDTH)
    ) u_bt_timer (
        .clk                    (clk),
        .rst_n                  (rst_n),

        .timer_clear            (timer_clear),
        .timer_enable           (timer_enable),
        .timing_check_en        (timing_check_en),

        .turnaround_min_cycles  (active_min),
        .turnaround_max_cycles  (active_max),

        .elapsed_count          (elapsed_count),
        .threshold_reached      (threshold_reached),

        .time_ok                (time_ok),
        .time_error             (time_error)
    );

endmodule

