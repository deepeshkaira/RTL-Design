`timescale 1ns / 1ps

module parallel_accumulator_generate #(
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
  
  
  //generate statements for generating multiple instances of the accumulator 
  genvar i;
  generate
    for (i = 0; i < PAR_FACTOR; i++) begin
     accum #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
     ) u_acc (
    .clk(clk), 
    .rst(rst), 
    .data_in(data_in[i]), 
    .en(en), 
    .data_out(interim_data[i])
  );        
   end
   endgenerate
  
  assign accum_full_ovrflo = data_nxt[ACC_WIDTH];

  always_comb begin
        data_nxt = '0;
    for (int i = 0; i < PAR_FACTOR; i++) 
        data_nxt += interim_data[i];
  end
  
  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      data_out <= '0;
    else if (en)
      data_out <= data_nxt[ACC_WIDTH] ? {ACC_WIDTH{1'b1}} : data_nxt[ACC_WIDTH-1:0];
  end
  
  
endmodule
