`timescale 1ns/1ps

module data_processing_block (
    input clk,
    input rst_n,

    // Configurable Operation Mode
    input [1:0] mode, 

    // Input Interface (from Producer)
    input [7:0] in_data,
    input       in_valid,
    output      in_ready,

    // Output Interface (to Sink/Next Block)
    output reg [7:0] out_data,
    output reg       out_valid,
    input            out_ready
);

    // --- Internal Logic ---
    
    // We are ready to accept data if:
    // 1. Our output register is currently empty (out_valid is 0)
    // 2. OR the downstream block is ready to take our current data (out_ready is 1)
    assign in_ready = !out_valid || out_ready;

    // --- Processing Logic ---
    reg [7:0] processed_value;
    
    always @(*) begin
        case (mode)
            2'b00: processed_value = in_data;           // Mode 0: Bypass
            2'b01: processed_value = ~in_data;          // Mode 1: Invert (Negative)
            2'b10: begin                                // Mode 2: Brighten (+32 with clipping)
                if (in_data > 8'd223) processed_value = 8'd255;
                else processed_value = in_data + 8'd32;
            end
            2'b11: processed_value = (in_data > 8'd128) ? 8'hFF : 8'h00; // Mode 3: Threshold
            default: processed_value = in_data;
        endcase
    end

    // --- Sequential Handshaking & Data Transfer ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 8'h00;
        end else begin
            // If we are ready and the producer has valid data (Handshake occurs)
            if (in_valid && in_ready) begin
                out_data  <= processed_value;
                out_valid <= 1'b1;
            end 
            // If we have data, but the downstream isn't ready, we hold 'out_valid' high.
            // If the downstream IS ready, and no new data is coming in, we clear 'out_valid'.
            else if (out_ready) begin
                out_valid <= 1'b0;
            end
        end
    end

endmodule