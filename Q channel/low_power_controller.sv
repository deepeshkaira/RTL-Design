`timescale 1ns / 1ns

module low_power_controller (
    input logic clock,
    input logic reset,
    input logic qacceptn_i,
    input logic qactive_i,
    input logic low_power_req_i,
    input logic qdeny_i,        /// for qdeny block instantiatson
    output logic device_icg_enable,
    output logic qreq_n_o
);
 
 logic qaccept_n;
 logic qactive;

 // for deny module instance
 logic qdeny;
 logic start_retry_timer;
 logic retry_done;

 dff #(
    .RESET_VAL(0)
 ) sync_qdeny (
    .clk(clock),
    .reset(reset),
    .async(qdeny_i),
    .sync(qdeny)
 );

 dff #(
 .RESET_VAL(1))
 sync_qctive (
    .clk(clock),
    .reset(reset),
    .async(qacceptn_i),
    .sync(qaccept_n)
    );
    
 dff #(
 .RESET_VAL(0))
 sync_qaccept (
    .clk(clock),
    .reset(reset),
    .async(qactive_i),
    .sync(qactive)
    );
        
// retry timer module instance
q_retry_timer #(
    .WAIT_CYCLES(16)      // Wait 16 cycles before retrying
) u_retry_timer (
    .clk        (clock),
    .reset      (reset),
    .start_timer(start_retry_timer),
    .timer_done (retry_done)
);

typedef enum {
    Q_RUN,
    Q_REQUEST,
    Q_STOPPED,
    Q_EXIT,
    Q_DENIED,
    Q_COOLDOWN 
} state_t;

state_t present_state, next_state;

logic q_req, q_req_next, q_req_enable;


// state machine logic
always_ff @( posedge clock or posedge reset ) 
begin : CURRENT_STATE_LOGIC
    if(reset)
        present_state <= Q_RUN;
    else
        present_state <= next_state;
end

always_comb
begin
    next_state = present_state;
    start_retry_timer = 1'b0;

    case (present_state)
        Q_RUN: begin
            if(!qreq_n_o) next_state = Q_REQUEST;
        end

        Q_REQUEST: begin
            if (qdeny)     next_state = Q_DENIED;
            else if(!qaccept_n) next_state = Q_STOPPED;
        end 

        Q_DENIED: begin
            // wait for devic to put QDENY 0, then start the tiemer
            if (!qdeny) begin
                start_retry_timer = 1'b1;
                next_state = Q_COOLDOWN;
            end
        end

        Q_COOLDOWN: begin
            if(retry_done) next_state = Q_RUN;
        end

        Q_STOPPED: begin
            if(qreq_n_o) next_state = Q_EXIT;
        end

        Q_EXIT: begin
            if(qaccept_n) next_state = Q_RUN;
        end

        default: next_state = Q_RUN;
    endcase
end


// QREQ_N Generation logic
// q_req_n can from HIGH TO LOW in Q_RUN STATE (q_acceptn is high)
// q_req_n can from LOW TO HIGH in Q_STOPPED or Q_REQUEST STATE 

// Counter Logic to check whether Active is high for more than 5 cycles

//------------------------------------------------------------------------------------------------------------
logic [2:0] count_active;
logic up_active_signal;
logic up_flag;

always_ff @( posedge clock or posedge reset ) 
begin : Active_Counter
    if(reset) begin
        count_active <= 3'd0;
    end
    else begin
        if(count_active == 3'd5) begin 
            count_active <= 3'd0;
        end
        else if(qactive & !up_flag) begin 
            count_active <= count_active + 1'b1;
        end
        else count_active <= 3'd0;
    end
    
end

always_ff @( posedge clock or posedge reset ) 
begin : up_flag_logic
    if(reset)
        up_flag <= 1'b0;
    else begin
        if(count_active == 3'd5) up_flag <= 1'b1;
        else if(!qactive) up_flag <=1'b0;
    end
end

assign up_active_signal = (count_active == 3'd5) ? 1'b1 : 1'b0; // set the qreq_n signal in Q_STOPPED --> Q_EXIT state 

//------------------------------------------------------------------------------------------------------------
logic [2:0] count_active_down;
logic down_active_signal;
logic down_flag;

always_ff @( posedge clock or posedge reset ) 
begin : Active_Counter_down
    if(reset) begin
        count_active_down <= 3'd0;
    end
    else begin
        if(count_active_down == 3'd5) begin 
            count_active_down <= 3'd0;
        end
        else if(!qactive & !up_flag) begin 
            count_active_down <= count_active_down + 1'b1;
        end
        else count_active_down <= 3'd0;
    end
    
end

always_ff @( posedge clock or posedge reset ) 
begin : down_flag_logic
    if(reset)
        down_flag <= 1'b0;
    else begin
        if(count_active == 3'd5) down_flag <= 1'b1;
        else if(qactive) down_flag <=1'b0;
    end
end

assign down_active_signal = (count_active_down == 3'd5) ? 1'b1 : 1'b0; // used to make the qreq_n signal go low in Q_RUN --> Q_REQUEST

//------------------------------------------
// Q_DENIED added as condition here
assign q_req_enable = (present_state == Q_RUN) |
                      (present_state == Q_STOPPED) |
                      (present_state == Q_REQUEST) |
                      (present_state == Q_REQUEST) ;


always_ff @( posedge clock or posedge reset ) 
begin : Q_REQ_LOGIC
    if(reset)
        q_req <= 1'b1;
    else begin
        if(q_req_enable)
            q_req <= q_req_next;
    end 
end


always_comb 
begin : NEXT_QREQ
    q_req_next = q_req;
    case (present_state)
        Q_RUN: begin
            if(((down_active_signal) | low_power_req_i) && !qactive )
            q_req_next = 1'b0;
        end 

        Q_STOPPED: begin
            if(up_active_signal) q_req_next = 1'b1;
        end 

        default: q_req_next = q_req_next;
    endcase
end


assign qreq_n_o = q_req;

//----------------------ICG Enable Signal 

always@(negedge clock or posedge reset) 
begin: DEVICE_EN_ICG
    if(reset) device_icg_enable <= 1'b1;
    else if(present_state == Q_STOPPED) device_icg_enable <= 1'b0;
    else device_icg_enable <= 1'b1;
end

//----------------------------------------------------------

endmodule