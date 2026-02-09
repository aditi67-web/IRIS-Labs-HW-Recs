`timescale 1ns/1ps

module tb_data_prod_proc;

    reg clk = 0;
    reg sensor_clk = 0;

    // 100MHz
    always #5 clk = ~clk;

    // 200MHz
    always #2.5 sensor_clk = ~sensor_clk;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        if (!resetn)
            reset_cnt <= reset_cnt + 1'b1;
    end

    reg [5:0] sensor_reset_cnt = 0;
    wire sensor_resetn = &sensor_reset_cnt;

    always @(posedge sensor_clk) begin
        if (!sensor_resetn)
            sensor_reset_cnt <= sensor_reset_cnt + 1'b1;
    end

    wire [7:0] pixel;
    wire valid;
    wire ready;

	/* Write your tb logic for your combined design here */
    
    // Output signals from the processor
    wire [7:0] processed_pixel;
    wire       processed_valid;
    reg        processed_ready = 1'b1; // Simulate that the sink is always ready

    // Simulation Control Logic
    initial begin
        // 1. Create a waveform file to view in GTKWave
        $dumpfile("data_proc_sim.vcd");
        $dumpvars(0, tb_data_prod_proc);

        // 2. Wait for the system to come out of reset
        wait(resetn && sensor_resetn);
        $display("--- System Reset Released ---");

        // 3. Monitor the data flow
        // We will stop the simulation after 100 pixels are processed
        repeat (100) begin
            @(posedge clk);
            if (processed_valid && processed_ready) begin
                $display("Time: %t | Input: %h | Processed: %h", $time, pixel, processed_pixel);
            end
        end

        $display("--- Simulation Finished ---");
        $finish;
    end

	/*---------------------------------------------------*/

	data_proc data_processing (
        .clk(clk),
        .rstn(resetn),

        // CPU Programming Interface (Driving with constants for testing)
        .mem_addr(32'h0),
        .mem_wdata(32'h0),
        .mem_valid(1'b0),
        .mem_wstrb(4'h0),
        .mem_ready(),
        .mem_rdata(),

        // Streaming Input (Connected to Producer)
        .in_data(pixel),
        .in_valid(valid),
        .in_ready(ready), // This flows back to data_producer to handle CDC

        // Streaming Output
        .out_data(processed_pixel),
        .out_valid(processed_valid),
        .out_ready(processed_ready)
	);

	data_prod data_producer (
        .sensor_clk(sensor_clk),
        .rstn(sensor_resetn),
        .ready(ready),
        .pixel(pixel),
        .valid(valid)
	);

endmodule
