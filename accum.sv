`timescale 1ns / 1ps

module accum #(
    parameter DATA_WIDTH = 4,
    parameter ACC_WIDTH = 8
)(
    input logic clk, // input clk
    input logic rst, // input rst
    input logic en,  //accumulation enable
    input logic [DATA_WIDTH-1:0] data_in, // input data
    output logic [ACC_WIDTH-1:0] data_out,  //output data
    output logic accum_full_ovrflo   // bit to define if accumulator can't handle the incoming data for addition
);

logic [$bits(data_out):0] acc_reg;
logic [$bits(data_out):0] acc_nxt;

always_ff @(posedge clk or posedge rst) begin
    if(en) begin
        acc_reg <= acc_nxt;  // enable controlled accumulation 
        data_out <= accum_full_ovrflo === 1'b1 ? 64'b1 : acc_reg;
        accum_full_ovrflo <= acc_nxt[ACC_WIDTH] == 1'b1;
    end
    if (rst) begin
        acc_reg <= '0;   // active high reset
        data_out <= '0;
        accum_full_ovrflo <= 1'b0;
    end
end

assign acc_nxt = acc_reg + data_in;

endmodule
