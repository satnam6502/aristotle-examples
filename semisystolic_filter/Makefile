VERILATOR ?= verilator

SRCS := semisystolic_filter.sv
SPEC_SRCS := semisystolic_filter_spec.sv
TB_SRCS := $(SRCS) $(SPEC_SRCS) semisystolic_filter_tb.sv
SIM := build/obj/Vsemisystolic_filter_tb

.PHONY: lint sim clean

# pe and filter_check don't match their file names.
lint:
	$(VERILATOR) --lint-only -Wall -Wno-DECLFILENAME \
	  --top-module semisystolic_filter $(SRCS)
	$(VERILATOR) --lint-only -Wall \
	  --top-module semisystolic_filter_spec $(SPEC_SRCS)

# Ends with PASS, or fails on any error. -Wall also lints the testbench and
# every configuration of the filter that it builds.
sim: $(SIM)
	$(SIM)

# --timing because the testbench has delays.
$(SIM): $(TB_SRCS) | build
	$(VERILATOR) --binary -Wall -Wno-DECLFILENAME --timing --Mdir build/obj \
	  --top-module semisystolic_filter_tb $(TB_SRCS)

build:
	mkdir -p $@

clean:
	rm -rf build
