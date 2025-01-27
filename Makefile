## tools
YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GMPACK = gmpack
GMUNPACK = gmunpack
OFL = openFPGALoader

TOP = top
YSFLAGS  = -luttree -noaddf -nomx8 -noclkbuf
OFLFLAGS = --index-chain 0

## target sources
VLOG_SRC = $(shell find ./rtl/ -type f \( -iname \*.v -o -iname \*.sv \))

synth: $(VLOG_SRC)
	$(YOSYS) -ql log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) $(YSFLAGS) -json net/$(TOP)_synth.json'

impl:
	$(NEXTPNR) --device CCGM1A1 --json net/$(TOP)_synth.json --vopt ccf=rtl/$(TOP).ccf --vopt out=$(TOP)_impl.txt --router router2
	$(GMPACK) $(TOP)_impl.txt $(TOP).bit

jtag:
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP).bit

# requires: sudo usermod -a -G uucp $USER
capture:
	python3 tools/capture.py
