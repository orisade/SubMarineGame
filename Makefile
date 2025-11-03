# Submarine Game Simulation Makefile

# Default simulator (can be overridden: make SIM=verilator)
SIM ?= iverilog

# Directories
SRC_DIR = src
TB_DIR = testbenches
VCD_DIR = vcd
BUILD_DIR = build

# Source files
SOURCES = $(SRC_DIR)/submarine_top.v $(SRC_DIR)/game_engine.v $(SRC_DIR)/bfs.v $(SRC_DIR)/matrix_mem.v
TESTBENCH = $(TB_DIR)/submarine_tb.r4.sv
TOP_MODULE = submarine_tb

# Verification testbenches
VERIFY_TBS = $(TB_DIR)/tb_matrix_mem.v $(TB_DIR)/tb_bfs.v $(TB_DIR)/tb_game_engine.v $(TB_DIR)/tb_submarine_top.v
VERIFY_MODULES = tb_matrix_mem tb_bfs tb_game_engine tb_submarine_top

# Output files
VCD_FILE = $(VCD_DIR)/submarine_tb.vcd
EXEC_FILE = $(BUILD_DIR)/submarine_sim

# Default target
all: sim

# Icarus Verilog simulation
ifeq ($(SIM),iverilog)
compile:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	iverilog -o $(EXEC_FILE) -s $(TOP_MODULE) $(TESTBENCH) $(SOURCES)

sim: compile
	$(EXEC_FILE)

wave: sim
	gtkwave $(VCD_FILE) &
endif

# Verilator simulation
ifeq ($(SIM),verilator)
compile:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	verilator --cc --exe --build -j 0 -Wall $(TESTBENCH) $(SOURCES) --top-module $(TOP_MODULE)

sim: compile
	./obj_dir/V$(TOP_MODULE)

wave: sim
	gtkwave $(VCD_FILE) &
endif

# ModelSim/QuestaSim simulation
ifeq ($(SIM),modelsim)
compile:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	vlog $(SOURCES) $(TESTBENCH)

sim: compile
	vsim -c -do "run -all; quit" $(TOP_MODULE)

wave: sim
	vsim $(TOP_MODULE) &
endif

# Clean generated files
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(VCD_DIR)/*.vcd
	rm -rf obj_dir/
	rm -f *.vvp *.lxt2 *.ghw
	rm -f transcript vsim.wlf
	rm -f work/_info work/_vmake

# Verification targets
verify-matrix: 
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	iverilog -o $(BUILD_DIR)/tb_matrix_mem $(TB_DIR)/tb_matrix_mem.v $(SRC_DIR)/matrix_mem.v && $(BUILD_DIR)/tb_matrix_mem

verify-matrix-wave: verify-matrix
	gtkwave $(VCD_DIR)/tb_matrix_mem.vcd &

verify-bfs:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	iverilog -o $(BUILD_DIR)/tb_bfs $(TB_DIR)/tb_bfs.v $(SRC_DIR)/bfs.v && $(BUILD_DIR)/tb_bfs

verify-bfs-wave: verify-bfs
	gtkwave $(VCD_DIR)/tb_bfs.vcd &

verify-engine:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	iverilog -o $(BUILD_DIR)/tb_game_engine $(TB_DIR)/tb_game_engine.v $(SRC_DIR)/game_engine.v && $(BUILD_DIR)/tb_game_engine

verify-top:
	mkdir -p $(VCD_DIR) $(BUILD_DIR)
	iverilog -o $(BUILD_DIR)/tb_submarine_top $(TB_DIR)/tb_submarine_top.v $(SOURCES) && $(BUILD_DIR)/tb_submarine_top

verify-top-wave: verify-top
	gtkwave $(VCD_DIR)/tb_submarine_top.vcd &

verify-all: verify-matrix verify-bfs verify-engine verify-top
	@echo "All module verifications completed"

# Help
help:
	@echo "Submarine Game Simulation"
	@echo "Usage:"
	@echo "  make [SIM=simulator]  - Run simulation (default: iverilog)"
	@echo "  make wave            - Open waveform viewer"
	@echo "  make verify-all      - Run all module verifications"
	@echo "  make verify-matrix   - Verify matrix memory module"
	@echo "  make verify-bfs      - Verify BFS module"
	@echo "  make verify-engine   - Verify game engine module"
	@echo "  make verify-top      - Verify top-level module"
	@echo "  make clean           - Clean generated files"
	@echo ""
	@echo "Supported simulators:"
	@echo "  iverilog (default)   - Icarus Verilog"
	@echo "  verilator           - Verilator"
	@echo "  modelsim            - ModelSim/QuestaSim"

.PHONY: all compile sim wave clean help verify-all verify-matrix verify-bfs verify-engine verify-top
