
module bt_fsm_controller (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       transaction_start,

    input  logic       phy_eop_ref,
    input  logic       phy_packet_start,

    input  logic       packet_valid,
    input  logic [3:0] packet_pid,
    input  logic       packet_error,

    input  logic       threshold_reached,

    input  logic       time_ok,
    input  logic       time_error,

    output logic       timer_clear,
    output logic       timer_enable,
    output logic       timing_check_en,

    output logic       bt_timeout_status,
    output logic       bt_timing_valid
);

    localparam logic [3:0] PID_OUT   = 4'b0001;
    localparam logic [3:0] PID_IN    = 4'b1001;
    localparam logic [3:0] PID_SETUP = 4'b1101;

    localparam logic [3:0] PID_DATA0 = 4'b0011;
    localparam logic [3:0] PID_DATA1 = 4'b1011;
    localparam logic [3:0] PID_DATA2 = 4'b0111;
    localparam logic [3:0] PID_MDATA = 4'b1111;

        typedef enum logic [2:0] {
        IDLE,
        WAIT_EOP_REF,
        MEASURE_TURNAROUND,
        STOP_TIMER,
        CHECK_TURNAROUND
    } state_t;

    state_t state;
    state_t next_state;

    logic [3:0] active_packet_pid;
    logic       data_expected;

    logic [3:0] current_packet_pid;
    logic       relevant_eop;
    logic       is_data_pid;

    assign current_packet_pid = packet_valid ? packet_pid : active_packet_pid;

    assign is_data_pid = (current_packet_pid == PID_DATA0) || (current_packet_pid == PID_DATA1) || (current_packet_pid == PID_DATA2) ||
        (current_packet_pid == PID_MDATA);

    assign relevant_eop = phy_eop_ref && ((current_packet_pid == PID_IN) || (data_expected && is_data_pid)); 

    // FSM state and packet tracking.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            active_packet_pid <= '0;
            data_expected     <= 1'b0;
        end
        else if (packet_error && (state != IDLE)) begin
            state             <= IDLE;
            active_packet_pid <= '0;
            data_expected     <= 1'b0;
        end
        else begin
            state <= next_state;

            if (state == IDLE && transaction_start) begin
                active_packet_pid <= packet_pid;
                data_expected     <= 1'b0;
            end
            else if (state == WAIT_EOP_REF) begin

                if (data_expected && packet_valid && is_data_pid)
                    active_packet_pid <= packet_pid;

                if (phy_eop_ref && ((current_packet_pid == PID_OUT) || (current_packet_pid == PID_SETUP))) begin
                    data_expected <= 1'b1;
                end

                if (relevant_eop)
                    data_expected <= 1'b0;
            end

            if (state == CHECK_TURNAROUND)
                data_expected <= 1'b0;

            if (state == IDLE && !transaction_start) begin
                active_packet_pid <= '0;
                data_expected     <= 1'b0;
            end
        end
    end

    // Next-state logic.
    always_comb begin
        next_state = state;

        if (packet_error && (state != IDLE)) begin
            next_state = IDLE;
        end
        else begin
            case (state)

                IDLE: begin
                    if (transaction_start)
                        next_state = WAIT_EOP_REF;
                end

                WAIT_EOP_REF: begin
                    if (relevant_eop)
                        next_state = MEASURE_TURNAROUND;
                end

                MEASURE_TURNAROUND: begin
                    if (phy_packet_start)
                        next_state = STOP_TIMER;
                    else if (threshold_reached)
                        next_state = IDLE;
                end

                STOP_TIMER: begin
                    next_state = CHECK_TURNAROUND;
                end
              
                CHECK_TURNAROUND: begin
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end

            endcase
        end
    end

    // Timer control.
    always_comb begin
        timer_clear     = 1'b0;
        timer_enable    = 1'b0;
        timing_check_en = 1'b0;

        if (packet_error && (state != IDLE)) begin
            timer_clear = 1'b1;
        end
        else begin
            case (state)

                IDLE: begin
                    if (transaction_start)
                        timer_clear = 1'b1;
                end

                WAIT_EOP_REF: begin
                    if (relevant_eop)
                        timer_clear = 1'b1;
                end

                MEASURE_TURNAROUND: begin
                    if (!threshold_reached)
                        timer_enable = 1'b1;
                end

                STOP_TIMER: begin
                    timer_enable = 1'b0;
                end

                CHECK_TURNAROUND: begin
                    timing_check_en = 1'b1;
                end

              //  default: begin
              //  end

            endcase
        end
    end

    // Result generation.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bt_timeout_status <= 1'b0;
            bt_timing_valid   <= 1'b0;
        end
        else begin
            bt_timeout_status <= 1'b0;
            bt_timing_valid   <= 1'b0;

            if (!(packet_error && (state != IDLE))) begin

                if (state == CHECK_TURNAROUND) begin
                    bt_timing_valid <= 1'b1;

                    if (time_error || !time_ok)
                        bt_timeout_status <= 1'b1;
                end
                else if ((state == MEASURE_TURNAROUND) &&
                         !phy_packet_start &&
                         threshold_reached) begin

                    bt_timing_valid   <= 1'b1;
                    bt_timeout_status <= 1'b1;
                end

            end
        end
    end

endmodule

