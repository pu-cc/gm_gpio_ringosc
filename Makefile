## tools
YOSYS = yosys
PR = p_r
OFL = openFPGALoader

TOP = top
PRFLAGS  = -ccf rtl/$(TOP).ccf -cCP +uCIO
YSFLAGS  = -nomx8 -noclkbuf
OFLFLAGS = --index-chain 0

## target sources
VLOG_SRC = $(shell find ./rtl/ -type f \( -iname \*.v -o -iname \*.sv \))

synth: $(VLOG_SRC)
	$(YOSYS) -ql log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v'

impl:
	$(PR) -i net/$(TOP)_synth.v -o $(TOP) $(PRFLAGS) > log/$@.log

jtag:
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP)_00.cfg

# requires: sudo usermod -a -G uucp $USER
capture:
	python3 tools/capture.py
