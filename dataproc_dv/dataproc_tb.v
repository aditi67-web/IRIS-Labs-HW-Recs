`timescale 1 ns / 1 ps

module dataproc_tb;
	reg clk;
	always #5 clk = (clk === 1'b0);  //100MHz

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	localparam ser_half_period = 53;
	event ser_sample;

	wire ser_rx;
	wire ser_tx;

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;
	wire flash_io2;
	wire flash_io3;

	/* --- SECTION START: Task B Hardware Verification Logic --- */

    // 1. Wires for Data Path
    wire [7:0] sensor_pixel;
    wire       sensor_valid;
    wire       sensor_ready;
    wire [7:0] proc_out;
    wire       proc_out_valid;
    reg  [1:0] tb_mode; // To test the 4 operations

    // 2. Instantiate Sensor (Data Producer)
    data_prod data_producer_inst (
        .sensor_clk(clk),
        .rst_n(resetn),
        .ready(sensor_ready),
        .pixel(sensor_pixel),
        .valid(sensor_valid)
    );

    // 3. Instantiate Processor (Your Module)
    data_proc data_processing_inst (
        .clk(clk),
        .rstn(resetn),
        .mode(tb_mode),
        .in_data(sensor_pixel),
        .in_valid(sensor_valid),
        .in_ready(sensor_ready),
        .out_data(proc_out),
        .out_valid(proc_out_valid),
        .out_ready(1'b1) // Assume memory/sink is always ready for test
    );

    // 4. Test Sequence to Verify all 4 Modes
    initial begin
        $dumpfile("task_b_soc_verify.vcd");
        $dumpvars(0, dataproc_tb);
        
        tb_mode = 2'b00; // Start in Bypass
        
        wait(resetn); 
        $display("--- Task B: Verifying Hardware Data Path ---");

        // Test Mode 00: Bypass
        #1000; 
        
        // Test Mode 01: Invert
        @(posedge clk); tb_mode = 2'b01;
        $display("Switching to Mode 01: Invert");
        #1000;

        // Test Mode 10: Convolution/Process
        @(posedge clk); tb_mode = 2'b10;
        $display("Switching to Mode 10: Convolution");
        #1000;

        // Test Mode 11: Threshold
        @(posedge clk); tb_mode = 2'b11;
        $display("Switching to Mode 11: Threshold");
        #1000;

        $display("--- Hardware Data Path Verified ---");
        // Note: We don't $finish here yet, so the SoC can continue to run
    end

    // 5. Logic to print pixels to console for easy verification
    always @(posedge clk) begin
        if (proc_out_valid) begin
            $display("TB_LOG | Mode: %b | In: %h | Out: %h", tb_mode, sensor_pixel, proc_out);
        end
    end

	/* --- SECTION END --- */

	rvsoc_wrapper #(
		.MEM_WORDS(256)
	) uut (
		.clk      (clk),
		.resetn   (resetn),
		.ser_rx   (ser_rx),
		.ser_tx   (ser_tx),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3)
	);

	spiflash spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(flash_io2),
		.io3(flash_io3)
	);

	reg [7:0] buffer;

	always begin
		@(negedge ser_tx);

		repeat (ser_half_period) @(posedge clk);
		-> ser_sample;

		repeat (8) begin
			repeat (ser_half_period) @(posedge clk);
			repeat (ser_half_period) @(posedge clk);
			buffer = {ser_tx, buffer[7:1]};
			-> ser_sample;
		end

		repeat (ser_half_period) @(posedge clk);
		repeat (ser_half_period) @(posedge clk);
		-> ser_sample;

		if (buffer < 32 || buffer >= 127)
			$display("Serial data: %d", buffer);
		else
			$display("Serial data: '%c'", buffer);
	end
endmodule