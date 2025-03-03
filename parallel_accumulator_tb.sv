`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.03.2025 01:15:58
// Design Name: 
// Module Name: parallel_accumulator_tb
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


module parallel_accumulator_tb;
  
  parameter int PAR_FACTOR = 4;
  parameter int DATA_WIDTH = 4;
  parameter int ACC_WIDTH = 8;
  parameter int NUM_TEST = 10;
  
  logic rst;
  logic clk;
  logic [DATA_WIDTH-1:0] data_in [PAR_FACTOR];
  logic en;
  logic [ACC_WIDTH-1:0] data_out;
  logic accum_full_ovrflo;
  
  parallel_accumulator #(
    .PAR_FACTOR(PAR_FACTOR),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
  ) uut (
    .rst(rst),
    .clk(clk),
    .data_in(data_in),
    .en(en),
    .data_out(data_out),
    .accum_full_ovrflo(accum_full_ovrflo)
  );
  
  // Clock generation
  initial begin : generate_clock
    forever begin
        #5 clk = ~clk;
    end
  end
  
  
  initial begin
    $timeformat(-9, 0, " ns"); 
    
    clk <= 1'b0;
    rst <= 1'b1;
    en <= 1'b0;
    //#10;
    @(posedge clk);
    rst <= 1'b0;
    //#10;
    @(posedge clk);
    en <= 1'b1;
    
    for (int i = 0; i < NUM_TEST; i++) begin
      for (int j = 0; j < PAR_FACTOR; j++) begin
        data_in[j] <= $urandom;
        $display("[%0t] data_value is %0d", $realtime,data_out);
      end
      //#10;
      @(posedge clk);
    end
    
    en <= 1'b0;
    #20;
    $display("Test completed");
    disable generate_clock;
    $stop;
  end
  
//  initial begin
//    $monitor("Time=%0t, data_in=%0d, data_out=%0d, overflow=%b",$realtime, data_in, data_out, accum_full_ovrflo);
//  end
  
endmodule
