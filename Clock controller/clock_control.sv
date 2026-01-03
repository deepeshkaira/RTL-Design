`timescale 1ns / 1ns

module clock_control_slice (
    input  logic clk,       
    input  logic rst_n,         

    input  logic        sw_enable, // Async enable signal
    input  logic [1:0]  clk_divider_sel, // clock divider
    
    // Output
    output logic clk_out,       
    output logic is_enabled
    
    );

    logic       sync_enable;
    logic       gated_enable;
    logic       latch_en;
    logic [2:0] counter;
    logic [1:0] current_div;
    logic       clk_internal;
    logic       div_update_ready;

    // Synchronizer - double flopping the enable singal to prevent metastable in the clock domain

    logic sync_stg1;
    always_ff @(posedge clk or negedge rst_n)
    begin
        if (!rst_n) begin
            sync_stg1   <= 1'b0;
            sync_enable <= 1'b0;
        end else begin
            sync_stg1   <= sw_enable;
            sync_enable <= sync_stg1;
        end
    end

// clk divider logic , use a counter. The MSB determines the divided clock.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 3'b0;
        end else if (sync_enable) begin
            counter <= counter + 1'b1;
        end else begin
            counter <= 3'b0; 
        end
    end

    // Glitcch Protection - updae the divider ratio only when the counter wraps around. This prevents the clock efficiently "shorting" if there is a change in speeds mid-cycle.
    // decide when it is safe to update, only when the counter is 0 OR when the block was previously disabled.

    assign div_update_ready = (counter == 0) || (!sync_enable);

    // registering the clock_divider_Sel input

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            current_div <= 2'b00;
        else if (div_update_ready) 
            current_div <= clk_divider_sel;
    end
    
    // Mixing clk and counter bits in one assign is messy for synthesis. refine the output stage for maximum safety
    
    logic pre_driver_clk;
    
    always_comb
    begin
        case(current_div)
            2'b00: pre_driver_clk = clk;
            2'b01: pre_driver_clk = counter[0];
            2'b10: pre_driver_clk = counter[1];
            2'b11: pre_driver_clk = counter[2];
            default: pre_driver_clk = clk;
        endcase
    end 

   // Gate the FINAL selected clock (pre_driver_clk).
    
    // Latch is transparent when the *selected* clock is LOW. This ensures we don't chop the pulse in half.
    always_latch begin
        if (!pre_driver_clk) begin
            gate_control <= sync_enable;
        end
    end

    // Final Output AND Gate
    assign clk_out = pre_driver_clk & gate_control;
    assign is_enabled = sync_enable;

endmodule