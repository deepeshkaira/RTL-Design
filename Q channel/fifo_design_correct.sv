`timescale 1ns / 1ns

module fifo_design #(
    parameter DSIZE = 8,
    parameter ASIZE = 4 
)(
    input  logic             wclk,
    input  logic             wrst_n,
    input  logic             w_valid,
    input  logic [DSIZE-1:0] wdata,
    
    input  logic             rclk,
    input  logic             rrst_n,
    input  logic             r_valid,
    output logic [DSIZE-1:0] rdata,
    
    output logic             rempty,
    output logic             wfull
);

    logic [ASIZE:0] wptr, rptr;           // Registered Gray Pointers
    logic [ASIZE:0] waddr_bin, raddr_bin; // Binary pointers
    logic [ASIZE:0] wptr_sync, rptr_sync; // Sync'd pointers
    
    // Internal wires for NEXT calculations
    logic [ASIZE:0] waddr_next;
    logic [ASIZE:0] wptr_gray_next;
    logic [ASIZE:0] wptr_gray_current;
    logic [ASIZE:0] raddr_next;
    logic [ASIZE:0] rptr_gray_next;

    logic w_en;
    logic r_en;
    logic [DSIZE-1:0] rdata_temp;

    localparam DEPTH = 1 << ASIZE;
    logic [DSIZE-1:0] mem [0:DEPTH-1];

	// write section
    assign w_en = w_valid & !wfull;

    // Lookahead - next address n pointr
    assign waddr_next = waddr_bin + 1'b1;
    assign wptr_gray_next  = (waddr_next >> 1) ^ waddr_next; 
	assign wptr_gray_current = (waddr_bin >> 1) ^ waddr_bin;

    always_ff @(posedge wclk or posedge wrst_n) begin
        if(wrst_n) begin
            foreach(mem[i]) mem[i] <= '0;
            waddr_bin <= '0;
            wptr      <= '0;
            // wfull     <= 0;
        end else if (w_en) begin
            mem[waddr_bin[ASIZE-1:0]] <= wdata;
        
            waddr_bin <= waddr_next;  // Update to the NEXT values
            wptr      <= wptr_gray_next;  // <<<<< now the current binary address and the current gray address, both are same
        end
    end
    
	assign wfull = (wptr_gray_current == {~rptr_sync[ASIZE:ASIZE-1], rptr_sync[ASIZE-2:0]});

	/*
    always_ff @(posedge wclk or posedge wrst_n) begin
        if (wrst_n) wfull <= 0;
        // else        wfull <= (wptr_gray_next == {~rptr_sync[ASIZE:ASIZE-1], rptr_sync[ASIZE-2:0]}); 
        else        wfull <= (wptr_gray_current == {~rptr_sync[ASIZE:ASIZE-1], rptr_sync[ASIZE-2:0]}); 
    end
*/

	// read section 
    assign r_en = r_valid & !rempty;

	// lookahead for read pointr n address
    assign raddr_next = raddr_bin + 1'b1;
    assign rptr_gray_next  = (raddr_next >> 1) ^ raddr_next;

    assign rdata = rdata_temp;

    always_ff @(posedge rclk or posedge rrst_n) begin
        if (rrst_n) begin
            raddr_bin  <= '0;
            rptr       <= '0;
            rdata_temp <= '0;
        end else if (r_en) begin
            
            raddr_bin <= raddr_next;
            rptr      <= rptr_gray_next; 
            rdata_temp <= mem[raddr_bin[ASIZE-1:0]];
        end
    end

    // Empty Flag Generation
 
    always_ff @(posedge rclk or posedge rrst_n) begin
        if(rrst_n) rempty <= 1;
        else begin
            // If we are reading, check the NEXT state. 
            // If not reading, check CURRENT state to catch up with wptr updates.
            logic [ASIZE:0] rptr_to_check;
            rptr_to_check = r_en ? rptr_gray_next : rptr;
            
            rempty <= (rptr_to_check == wptr_sync);
        end
    end

    sync_ptr #(.WIDTH(ASIZE+1)) sync_w2r (
        .clk(rclk), .rst_n(rrst_n), 
        .in_ptr(wptr), 
        .out_ptr(wptr_sync)
    );

    sync_ptr #(.WIDTH(ASIZE+1)) sync_r2w (
        .clk(wclk), .rst_n(wrst_n), 
        .in_ptr(rptr), 
        .out_ptr(rptr_sync)
    );

endmodule


module sync_ptr #(parameter WIDTH=4) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] in_ptr,
    output logic [WIDTH-1:0] out_ptr
);
    logic [WIDTH-1:0] q1;
    always_ff @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            q1      <= '0;
            out_ptr <= '0;
        end else begin
            q1      <= in_ptr;
            out_ptr <= q1;
        end
    end
endmodule