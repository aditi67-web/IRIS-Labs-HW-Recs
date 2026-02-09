# Makefile for dataproc simulation using iverilog and vvp

# Source files and testbench
SOURCES = ../data_prod_proc/data_proc.v ../data_prod_proc/data_prod.v
TESTBENCH = dataproc_tb.v
DESIGN_FILES = $(SOURCES) $(TESTBENCH)

# Output files
SIMULATION_EXEC = dataproc_sim
VCD_FILE = dataproc.vcd

# Compiler flags
IVERILOG_FLAGS = -g2009

# Default target
.PHONY: all
all: $(SIMULATION_EXEC)
	@echo "Running simulation..."
	vvp $(SIMULATION_EXEC) -vcd

# Compile Verilog sources
$(SIMULATION_EXEC): $(DESIGN_FILES)
	@echo "Compiling Verilog sources..."
	iverilog $(IVERILOG_FLAGS) -s dataproc_tb -o $(SIMULATION_EXEC) $(DESIGN_FILES)

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build files..."
	rm -f $(SIMULATION_EXEC) $(VCD_FILE)
	@echo "Clean complete."

# View waveforms (requires GTKWave)
.PHONY: wave
wave: $(VCD_FILE)
	gtkwave $(VCD_FILE) &
