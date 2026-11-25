
module bt_timer #(
    parameter int COUNTER_WIDTH = 32
)(
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     timer_clear,
    input  logic                     timer_enable,
    input  logic                     timing_check_en,

    input  logic [COUNTER_WIDTH-1:0] turnaround_min_cycles,
    input  logic [COUNTER_WIDTH-1:0] turnaround_max_cycles,

    output logic [COUNTER_WIDTH-1:0] elapsed_count,
    output logic                     threshold_reached,

    output logic                     time_ok,
    output logic                     time_error
);

    // Timer counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            elapsed_count     <= '0;
            threshold_reached <= 1'b0;
        end
        else if (timer_clear) begin
            elapsed_count     <= '0;
            threshold_reached <= 1'b0;
        end
        else if (timer_enable && !threshold_reached) begin
            if (turnaround_max_cycles == '0) begin
                threshold_reached <= 1'b1;
            end
            else if (elapsed_count < turnaround_max_cycles) begin
                elapsed_count <= elapsed_count + 1'b1;

                if ((elapsed_count + 1'b1) >= turnaround_max_cycles)
                    threshold_reached <= 1'b1;
            end
            else begin
                threshold_reached <= 1'b1;
            end
        end
    end

    // Timing checker logic
    always_comb begin
        time_ok    = 1'b0;
        time_error = 1'b0;

        if (timing_check_en) begin
            if ((elapsed_count >= turnaround_min_cycles) &&
                (elapsed_count <= turnaround_max_cycles)) begin
                time_ok = 1'b1;
            end
            else begin
                time_error = 1'b1;
            end
        end
    end

endmodule

