`timescale 1ns / 1ps

module parallel_accumulator #(
  parameter int PAR_FACTOR = 4,
  parameter int DATA_WIDTH = 4,
  parameter int ACC_WIDTH = 8
) (
  input logic rst,
  input logic clk,
  input logic [DATA_WIDTH-1:0] data_in [PAR_FACTOR],
  input logic en,
  output logic [ACC_WIDTH-1:0] data_out,
  output logic accum_full_ovrflo
);
  
  logic [ACC_WIDTH:0] data_nxt = '0;
  logic [ACC_WIDTH-1:0] interim_data [PAR_FACTOR];
  
  // Instantiating accumulators manually instead of generate block
  accum #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_acc0 (
    .clk(clk), 
    .rst(rst), 
    .data_in(data_in[0]), 
    .en(en), 
    .data_out(interim_data[0])
    //.accum_full_ovrflo(accum_full_ovrflo)
  );
  
  accum #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_acc1 (
    .clk(clk), 
    .rst(rst), 
    .data_in(data_in[1]), 
    .en(en), 
    .data_out(interim_data[1])
    //.accum_full_ovrflo(accum_full_ovrflo)
  );
  
  accum #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_acc2 (
    .clk(clk), 
    .rst(rst), 
    .data_in(data_in[2]), 
    .en(en), 
    .data_out(interim_data[2])
//    .accum_full_ovrflo(accum_full_ovrflo)
  );
  
  accum #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_acc3 (
    .clk(clk), 
    .rst(rst), 
    .data_in(data_in[3]), 
    .en(en), 
    .data_out(interim_data[3])
//    .accum_full_ovrflo(accum_full_ovrflo)
  );
  
  assign accum_full_ovrflo = data_nxt[ACC_WIDTH] == 1'b1;

  always_comb begin
        data_nxt = '0;
    for (int i = 0; i < PAR_FACTOR; i++) 
        data_nxt += interim_data[i];
  end
  
  always_ff @(posedge clk or negedge rst) begin
    if (rst)
      data_out <= '0;
    else
      data_out <= accum_full_ovrflo === 1'b1 ? 64'b1 : data_nxt[ACC_WIDTH-1:0];
  end
  
endmodule
