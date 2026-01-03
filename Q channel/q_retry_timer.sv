`timescale 1ns / 1ns

// This parallel module handles the "Cooldown" phase.
// It takes a start signal and tells when the mandatory wait period is over.

module q_retry_timer #(
    parameter int WAIT_CYCLES = 16
)(
    input  logic clk,
    input  logic reset,
    input  logic start_timer,   // start the countin
    output logic timer_done     // this goes high when wait is over
);


    logic [$clog2(WAIT_CYCLES)-1:0] count;
    logic active;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count  <= '0;
            active <= 1'b0;
        end else begin
            if (start_timer) begin
                active <= 1'b1;
                count  <= '0;
            end else if (active) begin
                if (count == WAIT_CYCLES - 1) begin
                    active <= 1'b0; 
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

endmodule
