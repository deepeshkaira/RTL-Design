`timescale 1ns / 1ns

module dff #(parameter RESET_VAL = 1)(
    input logic async,
    input logic clk,
    input logic reset,
    output logic sync
    );
    
    logic meta;
    
    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            // meta <= RESET_VAL;
            sync <= RESET_VAL;
        end
        else begin
            // meta <= async;
            // sync <= meta;
            sync <= async;
        end
    end
endmodule