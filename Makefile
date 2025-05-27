## tools
YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
PACK = gmpack
OFL = openFPGALoader
IVL = iverilog
VVP = vvp

TOP = top
YSFLAGS  = -luttree -noclkbuf -nomult -nomx8
OFLFLAGS = --index-chain 0
IVLFLAGS = -g2012

## target sources
VLOG_SRC = $(shell find ./rtl/ -type f \( -iname \*.v -o -iname \*.sv \))

net/$(TOP)_synth.json: $(VLOG_SRC)
	$(YOSYS) -l log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v -json net/$(TOP)_synth.json'

$(TOP).txt: net/$(TOP)_synth.v rtl/$(TOP).ccf
	$(NEXTPNR) --device CCGM1A1 --json net/$(TOP)_synth.json --vopt ccf=rtl/$(TOP).ccf --vopt out=$(TOP).txt --router router2

$(TOP).bit: $(TOP).txt
	$(PACK) $(TOP).txt $(TOP).bit

jtag: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP).bit

vsim.vvp:
	$(IVL) $(IVLFLAGS) -DICARUS -o sim/iverilog/$@ sim/iverilog/$(TOP)_tb.v $(VLOG_SRC)

.PHONY: %sim %sim.vvp
%sim: %sim.vvp
	$(VVP) -l log/vvp.log -N sim/iverilog/$< -fst
	@$(RM) sim/iverilog/$^

# requires: sudo usermod -a -G uucp $USER
capture:
	python3 tools/capture.py
