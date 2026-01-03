`timescale 1ns / 1ns


module top_mod (
    input clk_a,
    input clk_b,
    input reset,

    // Wakeup interface
    input   logic          if_wakeup_i,

    // Write interface
    input   logic          wr_valid_i,
    input   logic [7:0]    wr_payload_i,

    // Upstream flush interface
    output  logic          wr_flush_o,
    input   logic          wr_done_i,
    output  logic          fifo_full,

    // Read interface
    input   logic          rd_valid_i,
    output  logic [7:0]    rd_payload_o,
    output  logic          fifo_empty, 
    
    // Q-Channel Status signals 
    output logic           qreqn,
    output logic           qacceptn,
    output logic           qactive,
    
    // Clock gate signal 
    output logic           device_icg_enable,
    // Low power Request Input 
    input low_power_req_i

);
    // Q-channel interface
    //logic qreqn;
    //logic qacceptn;
    //logic qactive;

    design_qc DUT(
        .clk(clk_a),
        .reset(reset),
        .if_wakeup_i(if_wakeup_i),
        .wr_valid_i(wr_valid_i),
        .wr_payload_i(wr_payload_i),
        .wr_flush_o(wr_flush_o),
        .wr_done_i(wr_done_i),
        .rd_valid_i(rd_valid_i),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .rd_payload_o(rd_payload_o),
        .qreqn_i(qreqn),
        .qacceptn_o(qacceptn),
        .qactive_o(qactive)
    );

    low_power_controller lpc_instance(
        .clock(clk_b),
        .reset(reset),
        .qacceptn_i(qacceptn),
        .qactive_i(qactive),
        .low_power_req_i(low_power_req_i),
        .device_icg_enable(device_icg_enable),
        .qreq_n_o(qreqn)
    );


endmodule