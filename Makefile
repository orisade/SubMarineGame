# Submarine Game Simulation Makefile

# Default simulator (can be overridden: make SIM=verilator)
SIM ?= iverilog

# Source files
SOURCES = submarine_top.v game_engine.v bfs.v matrix_mem.v
TESTBENCH = submarine_tb.r4.sv
TOP_MODULE = submarine_tb

# Verification testbenches
VERIFY_TBS = tb_matrix_mem.v tb_bfs.v tb_game_engine.v tb_submarine_top.v
VERIFY_MODULES = tb_matrix_mem tb_bfs tb_game_engine tb_submarine_top

# Output files
VCD_FILE = submarine_tb.vcd
EXEC_FILE = submarine_sim

# Default target
all: sim

# Icarus Verilog simulation
ifeq ($(SIM),iverilog)
compile:
	iverilog -o $(EXEC_FILE) -s $(TOP_MODULE) $(TESTBENCH) $(SOURCES)

sim: compile
	./$(EXEC_FILE)

wave: sim
	gtkwave $(VCD_FILE) &
endif

# Verilator simulation
ifeq ($(SIM),verilator)
compile:
	verilator --cc --exe --build -j 0 -Wall $(TESTBENCH) $(SOURCES) --top-module $(TOP_MODULE)

sim: compile
	./obj_dir/V$(TOP_MODULE)

wave: sim
	gtkwave $(VCD_FILE) &
endif

# ModelSim/QuestaSim simulation
ifeq ($(SIM),modelsim)
compile:
	vlog $(SOURCES) $(TESTBENCH)

sim: compile
	vsim -c -do "run -all; quit" $(TOP_MODULE)

wave: sim
	vsim $(TOP_MODULE) &
endif

# Clean generated files
clean:
	rm -f $(EXEC_FILE) $(VCD_FILE)
	rm -rf obj_dir/
	rm -f *.vvp *.lxt2 *.ghw
	rm -f transcript vsim.wlf
	rm -f work/_info work/_vmake

# Verification targets
verify-matrix: 
	iverilog -o tb_matrix_mem tb_matrix_mem.v matrix_mem.v && ./tb_matrix_mem

verify-matrix-wave: verify-matrix
	gtkwave tb_matrix_mem.vcd &

verify-bfs:
	iverilog -o tb_bfs tb_bfs.v bfs.v && ./tb_bfs

verify-bfs-wave: verify-bfs
	gtkwave tb_bfs.vcd &

verify-engine:
	iverilog -o tb_game_engine tb_game_engine.v game_engine.v && ./tb_game_engine

verify-top:
	iverilog -o tb_submarine_top tb_submarine_top.v $(SOURCES) && ./tb_submarine_top

verify-top-wave: verify-top
	gtkwave tb_submarine_top.vcd &

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
