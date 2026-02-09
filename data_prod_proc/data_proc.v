`timescale 1ns/1ps

module data_proc (
    input clk,
    input rstn,
    input [1:0] mode,
    input [7:0] in_data,
    input in_valid,
    output reg in_ready,
    output reg [7:0] out_data,
    output reg out_valid,
    input out_ready
);

/* --------------------------------------------------------------------------
Purpose of this module : This module should perform certain operations
based on the mode register and pixel values streamed out by data_prod module.

mode[1:0]:
00 - Bypass
01 - Invert the pixel
10 - Convolution with a kernel of your choice (kernel is 3x3 2d array)
11 - Not implemented

Memory map of registers:

0x00 - Mode (2 bits)    [R/W]
0x04 - Kernel (9 * 8 = 72 bits)     [R/W]
0x10 - Status reg   [R]
----------------------------------------------------------------------------*/
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            out_valid <= 1'b0;
            out_data <= 8'h00;
        end else begin
            if (in_valid && in_ready) begin
                case (mode)
                    2'b00: out_data <= in_data;           // Bypass
                    2'b01: out_data <= ~in_data;          // Invert
                    2'b10: out_data <= in_data;           // Placeholder for convolution
                    default: out_data <= in_data;
                endcase
                out_valid <= 1'b1;
            end else if (out_ready) begin
                out_valid <= 1'b0;
            end
        end
    end

    assign in_ready = !out_valid || out_ready;

endmodulemodule data_proc (
    input clk,
    input rstn,

    // Configuration from CPU
    input [1:0]  mode, 
    input [71:0] kernel,   // Nine 8-bit signed coefficients

    // Input Interface (from Sensor)
    input [7:0]  in_data,
    input        in_valid,
    output       in_ready,

    // Output Interface (to Sink/Memory)
    output [7:0] out_data,
    output reg   out_valid,
    input        out_ready
);

    // --- 1. Line Buffers & Window ---
    // We need 2 line buffers to store previous rows for 3x3 math
    reg [7:0] line_buf1 [0:1023]; 
    reg [7:0] line_buf2 [0:1023];
    reg [9:0] col_ptr;

    // 3x3 Window Shift Registers
    reg [7:0] w[0:2][0:2]; // w[row][col]

    // --- 2. Handshake Logic ---
    // Ready if output is ready OR if we are currently empty
    assign in_ready = out_ready || !out_valid;

    // --- 3. Shift Logic (The "Conveyor Belt") ---
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            col_ptr <= 0;
        end else if (in_valid && in_ready) begin
            // Shift pixels into our 3x3 window
            w[0][0] <= w[0][1]; w[0][1] <= w[0][2]; w[0][2] <= in_data;
            w[1][0] <= w[1][1]; w[1][1] <= w[1][2]; w[1][2] <= line_buf1[col_ptr];
            w[2][0] <= w[2][1]; w[2][1] <= w[2][2]; w[2][2] <= line_buf2[col_ptr];

            // Update Line Buffers for the next row
            line_buf1[col_ptr] <= in_data;
            line_buf2[col_ptr] <= line_buf1[col_ptr];

            // Increment column pointer (wraps at 1024)
            col_ptr <= col_ptr + 1;
        end
    end

    // --- 4. The 4 Processing Modes ---
    reg [15:0] conv_sum; // Intermediate sum for convolution
    reg [7:0]  processed_pixel;

    always @(*) begin
        case (mode)
            // MODE 00: Bypass (Just pass current pixel)
            2'b00: processed_pixel = in_data;

            // MODE 01: Invert (Photo Negative)
            2'b01: processed_pixel = ~in_data;

            // MODE 10: 3x3 Convolution
            2'b10: begin
                // Simple version: Sum of window (in reality, multiply by kernel here)
                conv_sum = (w[0][0] + w[0][1] + w[0][2] +
                            w[1][0] + w[1][1] + w[1][2] +
                            w[2][0] + w[2][1] + w[2][2]);
                processed_pixel = conv_sum[11:4]; // Scale down to 8 bits
            end

            // MODE 11: Threshold (Black & White)
            2'b11: processed_pixel = (in_data > 8'd128) ? 8'hFF : 8'h00;

            default: processed_pixel = in_data;
        endcase
    end

    // --- 5. Output Control ---
    reg [7:0] out_data_reg;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            out_valid <= 0;
            out_data_reg <= 0;
        end else begin
            if (in_valid && in_ready) begin
                out_data_reg <= processed_pixel;
                out_valid <= 1;
            end else if (out_ready) begin
                out_valid <= 0;
            end
        end
    end

    assign out_data = out_data_reg;

endmodule