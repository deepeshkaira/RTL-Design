`timescale 1ns / 1ns

module design_qc (
  input   logic          clk,
  input   logic          reset,

  // Wakeup interface
  input   logic          if_wakeup_i,

  // Write interface
  input   logic          wr_valid_i,
  input   logic [7:0]    wr_payload_i,

  // Upstream flush interface
  input   logic          wr_done_i,  // all pending writes completed by upstream
  output  logic          wr_flush_o,
  output  logic          fifo_full,

  // Read interface
  input   logic          rd_valid_i,
  output  logic [7:0]    rd_payload_o,
  output  logic          fifo_empty,

  // Q-channel interface
  input   logic          qreqn_i,
  output  logic          qacceptn_o,
  output  logic          qactive_o,

  // output  logic           r_en_o,   // FIFO exclusive signal for Monitor

  // adding here just as a dummy signal, for the sake of testbench use.
  output  logic          qdeny_o

);

assign qdeny_o = 1'b0;   // will not use this. Simply assigning this to 0. will use in controller design

  // register the input signals before use
 logic qreqn_i_sync;
 logic if_wakeup_i_reg;
 logic wr_valid_i_reg;
 logic wr_done_i_reg;
 logic rd_valid_i_reg;

 dff #(
	.RESET_VAL(1)
	) sync_qreq (
    .clk(clk),
    .reset(reset),
    .async(qreqn_i),

    //output data
    .sync(qreqn_i_sync)
    );
  
dff #(
    .RESET_VAL(0)
  ) sync_i_wakeup (
      .clk(clk),
      .reset(reset),
      .async(if_wakeup_i),
  
      //output data
      .sync(if_wakeup_i_reg)
      );

dff #(
    .RESET_VAL(0)
  ) sync_wr_done_i (
      .clk(clk),
      .reset(reset),
      .async(wr_done_i),
  
      //output data
      .sync(wr_done_i_reg)
      );

  typedef enum {Q_RUN, Q_REQUEST, Q_STOPPED, Q_EXIT  } state_t;
  state_t present_state,next_state;
  
  logic qacceptn_temp;
  logic qactive_temp;
  logic qaccept_enable;
  logic wr_flush_temp;
  // logic rd_req_LP;    // read request for going into low power
  // logic r_req_with_valid_read_or_LP_req;    // (rd_valid_i  OR rd_req_LP)

  // assign r_req_with_valid_read_or_LP_req =  (rd_valid_i || rd_req_LP);  (NOT NEEDED - This is destructive read request for FIFO)

  fifo_design  #(
	.DSIZE(8),
	.ASIZE(6)
	) data_fifo (
      .wclk(clk),
      .wrst_n(reset),
      .w_valid(wr_valid_i),   
      // .w_valid(wr_valid_i_reg),
      .wdata(wr_payload_i),   
      .rclk(clk),
      .rrst_n(reset),
      .r_valid(rd_valid_i),   
      // .r_valid(rd_valid_i_reg),
      // .r_valid(r_req_with_valid_read_or_LP_req),   // (NOT NEEDED - This is destructive read request for FIFO) need to start to drain out the FIFO, just incase there is a request to go into low power mode

      //output signals
      .rdata(rd_payload_o),
      .rempty(fifo_empty),
      .wfull(fifo_full),

      // fifo exclusive signal for monitor
      // .r_en_o(r_en_o)

  );


  /// QACTIVE - this is used to tell that there is some process going on while the request for going into "LOW POWER MODE" arrived
  ///////////////// qactive signal generation
  // need following condition for "qactive_temp" generation
  // write_valid HIGH
  // read_valid HIGH
  // fifo not empty (there should be some data)
  // or "if_wakeup_i_reg" signal is high

  assign qactive_o = if_wakeup_i_reg || qactive_temp ;

  always_ff @( posedge clk or posedge reset ) 
    begin
      qactive_temp <= (wr_valid_i || ~fifo_empty || rd_valid_i);
      if(reset) qactive_temp <= 1'b0; 
    end

  ///////////////// flush logic (critical one)
 /* Q-CHANNEL HANDSHAKE & FLUSH SEQUENCE
  -------------------------------------------------------------------------
  1. Request Phase:
  - Trigger: Controller asserts Sleep Request (QREQn = 0).
  - FSM:     Transitions from Q_RUN -> Q_REQUEST.
  - Output:  wr_flush_o is driven HIGH (Active) upon entry to Q_REQUEST 
  to block new upstream transactions.
 
  2. Drain Phase:
  - Upstream: Detects wr_flush_o, completes pending ops, and asserts wr_done_i when done with flushing.
  - Local:    Logic waits for (fifo_empty && wr_done_i).
 
  3. Accept Phase:
  - Action:   Once drained, QACCEPTn is driven LOW (Active) as it says that it has accepted the request to go into low power mode.
  - FSM:      Transitions Q_REQUEST -> Q_STOPPED.
  - Safety:   wr_flush_o REMAINS HIGH to ensure the interface stays blocked during the sleep state.
 
  4. Wakeup Phase:
  - Trigger:  Controller asserts Wakeup (QREQn = 1).
  - FSM:      Transitions Q_STOPPED -> Q_EXIT -> Q_RUN.
  - Release:  Once back in Q_RUN, wr_flush_o is driven LOW, allowing upstream data flow to resume.
  -------------------------------------------------------------------------
 */
  always_ff @( posedge clk or posedge reset ) 
    begin
      if(reset || (present_state == Q_RUN)) wr_flush_o <= 1'b0;
      // else if( !qreqn_i_sync && !wr_flush_o) wr_flush_o <= 1'b1; 
      else if((present_state == Q_REQUEST) && !qreqn_i_sync ) wr_flush_o <= 1'b1; 
    end


  // Low power State Machine logic
  always_ff @( posedge clk or posedge reset ) 
    begin
      present_state <= next_state;
      if(reset) present_state <= Q_RUN;
    end
 
  always_comb begin
    next_state = present_state;
    case(present_state)
      // we would stay in the Q_RUN state until we get a qreqn_i_sync. If ~qreqn_i_sync is there that means there is
      // a request to go to low power state and we move to a Q_REQUEST state
      Q_RUN: begin
        if(!qreqn_i_sync) begin
          // rd_req_LP = !(fifo_empty);   //(NOT NEEDED - This is destructive read request for FIFO) will read only if there is something in FIFO, while going into the low power state
          next_state = Q_REQUEST;
        end
      end
      // in this state we are going to wait for the QACCEPTn signal to go HIGH because until it goes HIGH, it means
      // that there is some transaction going on in like read, write or fifo is not empty yet. Because once we go into
      // low power state the device might shutdown and there can be a probable loss of data.
      //And we will stay in this state until there is a wakeup call or wakeup request to come out of LOW POWER MODE.
      // i.e. qreqn_i_sync will be = 1.
      Q_REQUEST: begin
        if(!qacceptn_o) next_state = Q_STOPPED;
        else if (qreqn_i_sync) next_state = Q_RUN;  // added to address the deadlock because of cancellation of request to go into low power mode before the device accepts it
          // (refer point 1 in created doc)
      end

      Q_STOPPED: begin
        if(qreqn_i_sync) next_state = Q_EXIT;
      end
      // will get out of the low power state once we qaccept_n is 0(active). Then normal operation would start.
      Q_EXIT: begin
        if(qacceptn_o)  next_state = Q_RUN;
      end
    endcase
  end


///////////////////// QACCEPTn Logic -- tells that the request to go into low pwer mode has been granted
// when input arrives in the systm that ** evrything in UPSTREAM has been written to FIFO ** and
// ** request to go into low power mode (sleep) is still active** and
// ** FIFO is not empty ** 

  assign qaccept_enable = (present_state == Q_REQUEST) || (present_state == Q_EXIT);

  // this is to tell that the request to go in low power mode has been granted. But, we need to make FIFO empty here.
  // so, we are going to snd a flag to FIFO to start reading the data out of fifo once we recieve a request to go into LOW POWER MODE.
  // if we do not RECEIVE a "FIFO empty" signal, that means we have denied (Q_DENY - not included in this module) the request to go into LOW POWER STATE. it is must for the FIFO to be empty before going down into the Lowpower mode
  assign qacceptn_temp = ~( fifo_empty && wr_done_i_reg && ~qreqn_i_sync );

  always_ff @( posedge clk or posedge reset ) begin
    if(reset)
      qacceptn_o <= 1'b1;
    else if(qaccept_enable)
      qacceptn_o <= qacceptn_temp;    
  end

endmodule 