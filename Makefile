.PHONY: all vectors sim sim-sequential verify verify-sequential test clean

IVERILOG ?= iverilog
VVP ?= vvp

all: test

vectors:
	python3 scripts/golden_model.py --write-vectors

sim: vectors
	mkdir -p build results
	$(IVERILOG) -g2012 -Wall -s tb_attention -o build/attention_sim rtl/attention_core.sv tb/tb_attention.sv
	$(VVP) build/attention_sim

sim-sequential: vectors
	mkdir -p build results
	$(IVERILOG) -g2012 -Wall -DSEQUENTIAL_DUT -s tb_attention -o build/attention_sequential_sim rtl/attention_core_sequential.sv tb/tb_attention.sv
	$(VVP) build/attention_sequential_sim

verify: sim
	python3 scripts/golden_model.py --check results/output_pipelined.txt
	test -s results/attention_pipelined.vcd
	test -s results/output_pipelined.txt

verify-sequential: sim-sequential
	python3 scripts/golden_model.py --check results/output_sequential.txt
	test -s results/attention_sequential.vcd
	test -s results/output_sequential.txt

test: verify verify-sequential

clean:
	rm -rf build results
