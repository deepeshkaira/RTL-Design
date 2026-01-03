`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.12.2025 11:36:40
// Design Name: 
// Module Name: mux
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mux(
    input logic [3:0] in_data,
    input logic [1:0] sel,
    output logic y_out
    );

//always_comb
//begin
//    y_out = in_data[sel];
//end


//always_comb
//begin
//    case(sel)
//    2'b00: y_out = in_data[0];
//    2'b01: y_out = in_data[1];
//    2'b10: y_out = in_data[2];
//    2'b11: y_out = in_data[3];
//end


always_comb
begin
    if(sel == 2'b00) y_out = in_data[0];
    else if(sel == 2'b01) y_out = in_data[1];
    else if(sel == 2'b10) y_out = in_data[2];
    else if(sel == 2'b11) y_out = in_data[3];
end


endmodule
