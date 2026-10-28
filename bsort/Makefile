SHELL := /bin/bash
VERILATOR ?= verilator
SBY ?= sby
YOSYS ?= yosys
EBMC ?= ebmc
ARISTOTLE ?= aristotle

# bsort sorts 2**N elements. The default matches bsort.sv.
N ?= 3
SIZES ?= 2 3 4 5 6 7 8
PROPS := sorted permutation
SBY_TIMEOUT ?= 3600
EBMC_TIMEOUT ?= 3600
SRCS := bsort.sv bsort_formal.sv
# Without --project-dir, only the files the filelists name are uploaded.
# build/aristotle_n<N>.f sets N, one file per size so runs can overlap.
ARISTOTLE_ARGS = --top bsort_formal -F bsort_formal.f -F build/aristotle_n$(N).f \
	--prompt-file PROMPT.md

SBY_JOBS := $(foreach n,$(SIZES),$(foreach p,$(PROPS),sby-job-$(n)-$(p)))
EBMC_JOBS := $(foreach n,$(SIZES),$(foreach p,$(PROPS),ebmc-job-$(n)-$(p)))

.PHONY: lint proof sby sby-sorted sby-permutation ebmc ebmc-sorted \
	ebmc-permutation ebmc-netlists sby-all ebmc-all $(SBY_JOBS) $(EBMC_JOBS) \
	aristotle aristotle-dry-run clean

# The ArrayUtils class in bsort.sv doesn't match the file name.
lint:
	$(VERILATOR) --lint-only --Wall -Wno-DECLFILENAME -GN=$(N) \
	  --top-module bsort_formal $(SRCS)

proof: sby ebmc

sby: sby-sorted sby-permutation

# Prove one assertion for size N by k-induction.
sby-sorted sby-permutation: sby-%: bsort.sby.in $(SRCS) | build
	sed -e 's/@N@/$(N)/g' -e 's/@TIMEOUT@/$(SBY_TIMEOUT)/g' \
	  bsort.sby.in > build/bsort_n$(N)_$*.sby
	$(SBY) -f -d build/sby-n$(N)-$* build/bsort_n$(N)_$*.sby $*

# Every size and assertion. The machine has three SBY licences, so run
# make -j3 -k sby-all.
sby-all: $(SBY_JOBS)

$(SBY_JOBS):
	$(MAKE) sby-$(word 4,$(subst -, ,$@)) N=$(word 3,$(subst -, ,$@))

# EBMC 6.1 can't elaborate bsort.sv. It rejects the ArrayUtils class and
# references into generate blocks, and it loops on the genvar that counts
# down past 0. So it reads a netlist of bsort_formal, assertions included,
# that Verific elaborates. One yosys run writes a netlist per assertion.
# The netlist must have no state elements.
EBMC_NETLIST_YS = read -verific; read -formal $(SRCS); \
	hierarchy -top bsort_formal -chparam N $*; flatten; \
	select -assert-none t:$$*ff* t:$$*latch*; design -save full; \
	delete bsort_formal/assert_permutation; \
	write_verilog -noattr build/ebmc_n$*_sorted.v; design -load full; \
	delete bsort_formal/assert_sorted; \
	write_verilog -noattr build/ebmc_n$*_permutation.v

build/ebmc_n%_sorted.v build/ebmc_n%_permutation.v: $(SRCS) | build
	$(YOSYS) -q -p '$(EBMC_NETLIST_YS)'

ebmc: ebmc-sorted ebmc-permutation

# With no state, frame 0 covers every input, so "PROVED up to bound 0" is
# a complete proof.
ebmc-sorted ebmc-permutation: ebmc-%: build/ebmc_n$(N)_%.v
	set -o pipefail; timeout $(EBMC_TIMEOUT) /usr/bin/time -f 'wall %e s, max RSS %M KB' \
	  $(EBMC) $< --top bsort_formal --bound 0 --cadical 2>&1 | tee build/ebmc-n$(N)-$*.log

# Writes the netlists one at a time, since each yosys run takes a licence.
ebmc-netlists:
	for n in $(SIZES); do $(MAKE) build/ebmc_n$${n}_sorted.v || exit 1; done

# Every size and assertion. EBMC needs no licence: make -j -k ebmc-all.
ebmc-all: $(EBMC_JOBS)

$(EBMC_JOBS): ebmc-netlists
	$(MAKE) ebmc-$(word 4,$(subst -, ,$@)) N=$(word 3,$(subst -, ,$@))

build/aristotle_n%.f: | build
	printf -- '-GN=%s\n' $* > $@

# A paid run that takes tens of minutes. Needs `aristotle login` or
# ARISTOTLE_API_KEY. Waits for the result and saves it in build/.
aristotle: build/aristotle_n$(N).f $(SRCS) bsort_formal.f PROMPT.md
	$(ARISTOTLE) submit $(ARISTOTLE_ARGS) --name "bsort N=$(N)" --wait \
	  --destination build/aristotle-n$(N).tar.gz

# Show what would be uploaded. Sends nothing and needs no key.
aristotle-dry-run: build/aristotle_n$(N).f $(SRCS) bsort_formal.f PROMPT.md
	$(ARISTOTLE) submit $(ARISTOTLE_ARGS) --dry-run

build:
	mkdir -p $@

clean:
	rm -rf build

