# Example for Siemens Questa/ModelSim. Set UVM_HOME to your UVM installation.
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
TEST ?= fifo_base_test

run:
	vlog -sv +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv fifo_if.sv sync_fifo.sv fifo_tb_pkg.sv tb_top.sv
	vsim -c tb_top +UVM_TESTNAME=$(TEST) -do "run -all; quit -f"

random:
	$(MAKE) run TEST=fifo_base_test

write:
	$(MAKE) run TEST=fifo_write_test
